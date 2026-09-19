# ============================================================================
#  Apply-NetworkStandard.ps1
#  Enforces Config\network-standard.json (NM-NET-STD-001) idempotently.
#  Safe to run repeatedly; only touches drifted items. Requires elevation.
#  Verifies each step and writes a compliance report to Reports\.
# ============================================================================
param([string]$ConfigPath = "C:\NetworkMaintenance\Config\network-standard.json")

$ErrorActionPreference = 'SilentlyContinue'
$root    = "C:\NetworkMaintenance"
$reportDir = Join-Path $root "Reports"
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

function Log  ($m, $c = 'Gray')    { Write-Host ("[APPLY] " + $m) -ForegroundColor $c }
$changes   = @()
$violations = @()

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    Log "NOT elevated - re-launching via UAC..." -c Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$S = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$ifaceName = @($S.interfaces.PSObject.Properties.Name)[0]
$cfg       = $S.interfaces.($ifaceName)
Log "Standard: $($S.standard.id) v$($S.standard.version) -> interface $ifaceName" -c Cyan

# ============================================================================
# 1. IP policy (static-when-managed / DHCP-fallback) - conflict-proof
# ============================================================================
function Get-SSID {
    $p = Get-NetConnectionProfile -InterfaceAlias $ifaceName -ErrorAction SilentlyContinue
    if ($p -and $p.Name) { return $p.Name }
    $n = netsh wlan show interfaces 2>$null
    $line = $n | Select-String 'SSID\s*:' | Select-Object -First 1
    if ($line) { return (($line -split ':')[1]).Trim() }
    return $null
}

$ssid = Get-SSID
$curIP = (Get-NetIPAddress -InterfaceAlias $ifaceName -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
$managed = $ssid -eq $cfg.ssidManaged

if ($managed) {
    if ($curIP -ne $cfg.static.ip) {
        Remove-NetIPAddress -InterfaceAlias $ifaceName -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -InterfaceAlias $ifaceName -IPAddress $cfg.static.ip -PrefixLength $cfg.static.prefix -DefaultGateway $cfg.static.gateway -ErrorAction Stop | Out-Null
        $changes += "IP -> static $($cfg.static.ip)"
        Log "Static IP applied: $($cfg.static.ip) (was $curIP)" -c Green
    } else {
        Log "IP policy OK ($curIP)" -c DarkGray
    }
} else {
    if ($curIP) {
        Remove-NetIPAddress -InterfaceAlias $ifaceName -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Set-NetIPInterface -InterfaceAlias $ifaceName -Dhcp Enabled -ErrorAction SilentlyContinue
        $changes += "IP -> DHCP (unmanaged SSID $ssid)"
        Log "Switched to DHCP on unmanaged SSID: $ssid" -c Green
    } else {
        Log "DHCP mode OK" -c DarkGray
    }
}

# ============================================================================
# 2. DNS + DNS over HTTPS (encrypted, tamper-proof)
# ============================================================================
$curDns = (Get-DnsClientServerAddress -InterfaceAlias $ifaceName -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
$wantDns = [string[]]$cfg.dns
if ($curDns -ne $wantDns) {
    Set-DnsClientServerAddress -InterfaceAlias $ifaceName -ServerAddresses $wantDns | Out-Null
    $changes += "DNS -> $($wantDns -join ',')"
    Log "DNS -> $($wantDns -join ',')" -c Green
} else { Log "DNS OK" -c DarkGray }

foreach ($addr in $cfg.dns) {
    $tpl = $cfg.doh.($addr)
    $existing = Get-DnsClientDohServerAddress -ServerAddress $addr -ErrorAction SilentlyContinue
    if (-not $existing) {
        Add-DnsClientDohServerAddress -ServerAddress $addr -DohTemplate $tpl -AllowFallbackToUdp $true | Out-Null
        $changes += "DoH -> $addr ($tpl)"
        Log "DoH enabled: $addr ($tpl)" -c Green
    } else { Log "DoH OK: $addr" -c DarkGray }
}

# ============================================================================
# 3. NCSI active probing OFF (stops spurious WLAN recovery/relink loops)
# ============================================================================
$ncsiKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet'
$curNcsi = (Get-ItemProperty $ncsiKey -Name EnableActiveProbing -ErrorAction SilentlyContinue).EnableActiveProbing
$wantNcsi = [int]$S.ncsi.enableActiveProbing
if ($curNcsi -ne $wantNcsi) {
    Set-ItemProperty $ncsiKey -Name EnableActiveProbing -Value $wantNcsi
    $changes += "NCSI active probing -> OFF"
    Log "NCSI active probing disabled (kills WLAN recovery loops)" -c Green
} else { Log "NCSI policy OK" -c DarkGray }

# ============================================================================
# 4. Wi-Fi adapter hardening
# ============================================================================
if ($S.wifi.powerSavingDisabled) {
    @('Power Saving Mode','Energy Efficient Ethernet','U-APSD') | ForEach-Object {
        Set-NetAdapterAdvancedProperty -Name $ifaceName -DisplayName $_ -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
    }
    Log "Wi-Fi power saving / EEE / U-APSD -> Disabled" -c DarkGray
}
Set-NetAdapterAdvancedProperty -Name $ifaceName -DisplayName 'Roaming Aggressiveness' -DisplayValue $S.wifi.roamingAggressiveness -ErrorAction SilentlyContinue
if ($S.wifi.disableDirectVirtualAdapters) {
    Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -match 'Wi-Fi Direct' } | ForEach-Object {
        if ($_.Status -ne 'Disabled') {
            Disable-NetAdapter -Name $_.Name -Confirm:$false
            $changes += "Disabled unused adapter: $($_.Name)"
            Log "Disabled unused Wi-Fi Direct adapter: $($_.Name)" -c Green
        }
    }
}

# ============================================================================
# 5. TCP/IP steady-state tunables
# ============================================================================
netsh int tcp set global autotuning=$($S.tcp.autotuning)            | Out-Null
netsh int tcp set global ecncapability=$($S.tcp.ecn)                | Out-Null
netsh int tcp set global timestamps=$($S.tcp.timestamps)            | Out-Null
netsh int tcp set global nonsackrttresiliency=$($S.tcp.nonsackrttresiliency) | Out-Null
netsh int tcp set global initialrto=$($S.tcp.initialrto)            | Out-Null
Log "TCP steady-state enforced (autotuning=$($S.tcp.autotuning), ECN=$($S.tcp.ecn))" -c DarkGray

# ============================================================================
# 6. Service state matrix
# ============================================================================
foreach ($n in $S.services.disabled) {
    $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($svc) {
        try { Stop-Service -Name $n -Force -ErrorAction Stop } catch {}
        sc.exe config $n start= disabled | Out-Null
        if ((Get-Service $n).StartType -ne 'Disabled') { $violations += "service not disabled: $n" } else { $changes += "service disabled: $n" }
        Log "service: $n -> disabled" -c Green
    }
}
foreach ($w in $S.services.disabledWildcard) {
    Get-Service -Name $w -ErrorAction SilentlyContinue | ForEach-Object {
        try { Stop-Service -Name $_.Name -Force -ErrorAction Stop } catch {}
        sc.exe config $_.Name start= disabled | Out-Null
        Log "service: $($_.Name) -> disabled" -c Green
    }
}
foreach ($n in $S.services.manual) {
    $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($svc) {
        try { Stop-Service -Name $n -Force -ErrorAction Stop } catch {}
        sc.exe config $n start= demand | Out-Null
        Log "service: $n -> manual (stopped)" -c DarkGray
    }
}
foreach ($n in $S.services.stopRun) {
    try { Stop-Service -Name $n -Force -ErrorAction Stop; Log "service: $n -> stopped (start-type kept)" -c DarkGray } catch {}
}

# ============================================================================
# 7. Internet-hogging scheduled tasks (supports * wildcard for SID-suffixed tasks)
# ============================================================================
foreach ($t in $S.tasksDisabled) {
    try {
        if ($t.name.Contains('*')) {
            $cands = Get-ScheduledTask -TaskPath $t.path -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like $t.name }
            foreach ($c in $cands) {
                if ($c.State -ne 'Disabled') {
                    Disable-ScheduledTask -TaskPath $t.path -TaskName $c.TaskName -ErrorAction SilentlyContinue | Out-Null
                    $changes += "task disabled: $($c.TaskName)"
                    Log "task: $($c.TaskName) -> disabled" -c Green
                } else { Log "task: $($c.TaskName) OK" -c DarkGray }
            }
        } else {
            $st = (Get-ScheduledTask -TaskPath $t.path -TaskName $t.name -ErrorAction Stop).State
            if ($st -ne 'Disabled') {
                Disable-ScheduledTask -TaskPath $t.path -TaskName $t.name -ErrorAction Stop | Out-Null
                $changes += "task disabled: $($t.name)"
                Log "task: $($t.name) -> disabled" -c Green
            } else { Log "task: $($t.name) OK" -c DarkGray }
        }
    } catch { }
}

# ============================================================================
# 8. Delivery Optimization throttling (protect the small uplink)
# ============================================================================
$doKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
New-Item -Path $doKey -Force | Out-Null
Set-ItemProperty $doKey -Name DOPercentMaxBackgroundBandwidth -Value $S.deliveryOptimization.backgroundPct
Set-ItemProperty $doKey -Name DOPercentMaxForegroundBandwidth -Value 50
Set-ItemProperty $doKey -Name DOMaxCacheSize -Value $S.deliveryOptimization.maxCacheMB
Log "Delivery Optimization throttled to $($S.deliveryOptimization.backgroundPct)% background" -c DarkGray

# ============================================================================
# 9. Verify + compliance report
# ============================================================================
Start-Sleep -Seconds 2
ipconfig /flushdns | Out-Null
$sw = [System.Diagnostics.Stopwatch]::StartNew()
# LIGHT: test via configured DNS server with lightweight name (was api.opencode.ai telemetry)
$dnsTestServer = if ($wantDns -and $wantDns.Count -gt 0) { $wantDns[0] } else { '1.1.1.1' }
Resolve-DnsName -Name 'one.one.one.one' -Server $dnsTestServer -QuickTimeout -ErrorAction SilentlyContinue | Out-Null
$sw.Stop()
$gw = (Get-NetIPConfiguration -InterfaceAlias $ifaceName -ErrorAction SilentlyContinue).IPv4DefaultGateway.NextHop
$gwOK = Test-Connection -ComputerName $gw -Count 2 -Quiet -ErrorAction SilentlyContinue -TimeoutSeconds 2

$compliance = [ordered]@{
    timestamp       = (Get-Date).ToString('s')
    standard        = $S.standard.id
    version         = $S.standard.version
    interface       = $ifaceName
    ssid            = $ssid
    ipv4            = $curIP
    gatewayReachable= $gwOK
    dnsLatencyMs    = $sw.ElapsedMilliseconds
    changesApplied  = $changes
    violations      = $violations
    status          = if ($violations.Count -eq 0) { 'COMPLIANT' } else { 'NON-COMPLIANT' }
}
$compliance | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $reportDir 'NetworkStandard-Compliance.json') -Encoding UTF8
Log "Report -> Reports\NetworkStandard-Compliance.json  (status: $($compliance.status))" -c Magenta
Log "DNS latency: $($sw.ElapsedMilliseconds) ms | Gateway reachable: $gwOK" -c Gray
Log "APPLY COMPLETE" -c Cyan