# ============================================================================
#  Network-Reliability-Watchdog.ps1
#  Self-healing watchdog enforcing Config\network-standard.json (NM-NET-STD-001).
#  Registered as SYSTEM scheduled tasks (every 5 min + logon + event-triggered).
#  Detects config drift -> re-applies standard.
#  Detects SLA breach -> reactive repair (flush / reset adapter), with alert
#  escalation if it keeps failing (no infinite loop).
# ============================================================================
param([switch]$Quiet)

$ErrorActionPreference = 'SilentlyContinue'
$root    = "C:\NetworkMaintenance"
$cfgPath = Join-Path $root "Config\network-standard.json"
$reportDir = Join-Path $root "Reports"
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

function Dog ($m) { if (-not $Quiet) { Write-Host ("[WATCHDOG] " + $m) -ForegroundColor Cyan } }

function Get-SSID {
    $p = Get-NetConnectionProfile -InterfaceAlias $ifc -ErrorAction SilentlyContinue
    if ($p -and $p.Name) { return $p.Name }
    $n = netsh wlan show interfaces 2>$null
    $line = $n | Select-String 'SSID\s*:' | Select-Object -First 1
    if ($line) { return (($line -split ':')[1]).Trim() }
    return $null
}

function Get-LossPct([string]$target, [int]$count = 2) {
    $ok = 0
    $ping = New-Object System.Net.NetworkInformation.Ping
    for ($i = 0; $i -lt $count; $i++) {
        try { if ($ping.Send($target, 1000).Status -eq 'Success') { $ok++ } } catch {}
    }
    return (100 - [int]($ok * 100 / $count))
}

# ---------- state block (config signature) ----------
$S   = Get-Content $cfgPath -Raw | ConvertFrom-Json
$ifc = @($S.interfaces.PSObject.Properties.Name)[0]
$cfg = $S.interfaces.($ifc)

$ssid  = Get-SSID
$curIP = (Get-NetIPAddress -InterfaceAlias $ifc -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
$curDns= [string[]](Get-DnsClientServerAddress -InterfaceAlias $ifc -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
$wantDns = [string[]]$cfg.dns
$ncsi  = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet' -Name EnableActiveProbing -ErrorAction SilentlyContinue).EnableActiveProbing

$drift = @()
if ($ssid -eq $cfg.ssidManaged -and $curIP -ne $cfg.static.ip) { $drift += "IP drift (got $curIP)" }
if ((Compare-Object $curDns $wantDns | Measure-Object).Count -gt 0) { $drift += "DNS drift ($($curDns -join ','))" }
if ($ncsi -ne 0)                                               { $drift += "NCSI probing re-enabled (value $ncsi)" }
foreach ($a in $cfg.dns) { if (-not (Get-DnsClientDohServerAddress -ServerAddress $a -ErrorAction SilentlyContinue)) { $drift += "DoH missing: $a" } }
foreach ($n in $S.services.disabled)     { if ((Get-Service $n -ErrorAction SilentlyContinue).StartType -ne 'Disabled') { $drift += "service re-enabled: $n" } }
foreach ($n in $S.services.manual)       { if ((Get-Service $n -ErrorAction SilentlyContinue).StartType -eq 'Auto') { $drift += "service auto again: $n" } }
foreach ($t in $S.tasksDisabled) {
    if ($t.name.Contains('*')) {
        $cands = Get-ScheduledTask -TaskPath $t.path -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like $t.name }
        foreach ($c in $cands) { if ($c.State -ne 'Disabled') { $drift += "task re-enabled: $($c.TaskName)"; break } }
    } elseif ((Get-ScheduledTask -TaskPath $t.path -TaskName $t.name -ErrorAction SilentlyContinue).State -ne 'Disabled') { $drift += "task re-enabled: $($t.name)" }
}

# ---------- SLA block (bounded: DNS quick + .NET ping + TCP 443, LIGHT) --------
# PERF: counts reduced (3->2, 4->2), TCP timeout 3000->2000ms,
# DNS target = configured DNS via lightweight name (was api.opencode.ai telemetry).
$gw  = (Get-NetIPConfiguration -InterfaceAlias $ifc -ErrorAction SilentlyContinue).IPv4DefaultGateway.NextHop
$gLossPct  = if ($gw) { Get-LossPct $gw 2 } else { 100 }
# ICMP to 1.1.1.1 is filtered by this operator; probe 8.8.8.8 (ICMP works) + TCP 443/1.1.1.1
$wLossPct  = Get-LossPct '8.8.8.8' 2
$tcpOK = $false
try { $tc = New-Object Net.Sockets.TcpClient; $ar = $tc.BeginConnect('1.1.1.1', 443, $null, $null); $tcpOK = $ar.AsyncWaitHandle.WaitOne(2000) -and $tc.Connected; $tc.Close() } catch { }
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$dnsServer = if ($wantDns -and $wantDns.Count -gt 0) { $wantDns[0] } else { '1.1.1.1' }
$dn = Resolve-DnsName -Name 'one.one.one.one' -Server $dnsServer -QuickTimeout -ErrorAction SilentlyContinue
$sw.Stop()
$dnsMs = $sw.ElapsedMilliseconds

$since = (Get-Date).AddHours(-24)
$conflicts = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Tcpip'; Id=4199; StartTime=$since} -ErrorAction SilentlyContinue).Count
$bounces   = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WLAN-AutoConfig'; Id=4001,4003; StartTime=$since} -ErrorAction SilentlyContinue).Count

$slaFail = @()
if ($wLossPct -gt $S.slas.wanLossPctMax)      { $slaFail += "WAN(8.8.8.8) loss $wLossPct% > $($S.slas.wanLossPctMax)%" }
if (-not $tcpOK)                              { $slaFail += "WAN TCP 1.1.1.1:443 unreachable" }
if ($dnsMs -gt $S.slas.dnsMsMax)              { $slaFail += "DNS ${dnsMs}ms > $($S.slas.dnsMsMax)ms" }
if ($conflicts -gt $S.slas.conflicts24hMax)   { $slaFail += "$conflicts IP conflicts in 24h" }
if ($bounces   -gt $S.slas.wlanBounce24hMax)  { $slaFail += "$bounces WLAN bounces in 24h" }

# ---------- repair / heal ----------
# Policy: LOCAL link failures (gateway) -> adapter restart once, with 10-min cooldown.
#         WAN/cellular instability (gateway OK) -> alert only, NO adapter restart
#         (restarting for cellular loss causes a 4003 ping-pong loop).
$lockFile  = 'C:\NetworkMaintenance\Temp\last-adapter-reset.txt'
$wanAlert  = 'C:\NetworkMaintenance\Reports\NETWORK_WAN_ALERT.txt'
$doRepair  = $false
$restartAllowed = $true
if (Test-Path $lockFile) {
    try { $re = [datetime]((Get-Content $lockFile).Trim()); if (((Get-Date) - $re).TotalMinutes -lt 10) { $restartAllowed = $false } } catch { }
}

if ($drift.Count -gt 0) {
    Dog "Config drift detected: $($drift -join '; ')"
    & (Join-Path $root "Scripts\Apply-NetworkStandard.ps1") -ConfigPath $cfgPath | Out-Null
    $doRepair = $true
}

if ($gLossPct -gt 50) {
    Dog "LOCAL link failure (gateway loss $gLossPct%) - hard repair path"
    if ($restartAllowed) {
        Restart-NetAdapter -Name $ifc -Confirm:$false
        Start-Sleep -Seconds 4
        ipconfig /flushdns | Out-Null
        (Get-Date).ToUniversalTime().ToString('s') | Set-Content $lockFile
        $doRepair = $true
        Dog "Adapter restarted (cooldown 10 min armed)"
    }
} elseif ($slaFail.Count -gt 0) {
    "count=$($slaFail.Count)`nalert=WAN/OPERATOR instability (host config OK): $($slaFail -join ';') at $(Get-Date -Format s)" | Set-Content $wanAlert
    Dog "WAN/operator instability noted (no host action): $($slaFail -join '; ')"
} else {
    if (Test-Path $wanAlert) { Remove-Item $wanAlert -Force }
}

if ($drift.Count -eq 0 -and $slaFail.Count -eq 0) { Dog "All checks compliant. Loss=$wLossPct% DNS=${dnsMs}ms Conflicts=$conflicts Bounces=$bounces" }

# ---------- alert escalation (no infinite repair loop) ----------
$alert = Join-Path $reportDir 'NETWORK_ALERT.txt'
if ($drift.Count -gt 0 -or $slaFail.Count -gt 0) {
    $prev = Get-Content $alert -ErrorAction SilentlyContinue
    $count = 0
    foreach ($l in $prev) { if ($l -match '^count=') { $count = [int]($l -replace '^count=',''); break } }
    $count++
    if ($count -ge 12) {
        "count=$count" + "`nalert=SUSTAINED ISSUE - manual intervention required (see Reports\NetworkHealth.log)" | Set-Content $alert
    } else {
        "count=$count" + "`nalert=auto-heal attempted at $(Get-Date -Format s) : drift=$($drift -join ',') sla=$($slaFail -join ',')" | Set-Content $alert
    }
} elseif (Test-Path $alert) { Remove-Item $alert -Force }

# ---------- persist health state ----------
$snapshot = [ordered]@{
    timestamp   = (Get-Date).ToString('s')
    ssid        = $ssid
    ipv4        = $curIP
    gatewayLossPct = $gLossPct
    wanLossPct  = $wLossPct
    dnsMs       = $dnsMs
    conflicts24h= $conflicts
    wlanBounce24h = $bounces
    drift       = $drift
    slaFailures = $slaFail
    status      = if ($drift.Count -eq 0 -and $slaFail.Count -eq 0) { 'PASS' } elseif ($drift.Count -gt 0) { 'CONFIG_DRIFT' } else { 'LINK_DEGRADED' }
}
$snapshot | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $reportDir 'net-health-last.json') -Encoding UTF8
Add-Content (Join-Path $reportDir 'NetworkHealth.log') ("{0}`t{1}`t{2}`t{3}`t{4}ms`t{5}`t{6}" -f (Get-Date -Format s), $ssid, $snapshot.status, $snapshot.wanLossPct, $dnsMs, $conflicts, ($drift -join ';'))
# ---------- log rotation (prevent disk/server bloat: keep last 500 lines) ----------
try {
    $logPath = Join-Path $reportDir 'NetworkHealth.log'
    $lines = Get-Content $logPath -ErrorAction Stop
    if ($lines.Count -gt 500) { $lines[-500..($lines.Count-1)] | Set-Content $logPath -Encoding UTF8 }
} catch {}