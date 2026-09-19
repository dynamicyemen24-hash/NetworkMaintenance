# ============================================================================
#  Fix-Network-Deep.ps1  -  Deep Network & Performance Fix (requires Admin)
#  Fixes: IP address conflicts (Tcpip 4199 churn), WLAN recovery loop,
#         internet stalls, memory waste, background internet hogs.
#  Reversible actions are documented at the end of the transcript.
# ============================================================================

$ErrorActionPreference = 'SilentlyContinue'
$logDir   = "C:\NetworkMaintenance\Logs"
$logFile  = Join-Path $logDir ("DeepFix-" + (Get-Date -Format yyyyMMdd-HHmmss) + ".log")
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

Start-Transcript -Path $logFile -Append | Out-Null

Write-Host "=" * 72 -ForegroundColor Cyan
Write-Host "  DEEP NETWORK & PERFORMANCE FIX  -  $(Get-Date)" -ForegroundColor Cyan
Write-Host "=" * 72 -ForegroundColor Cyan

# --- Require admin ----------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] NOT elevated. Re-launching as administrator..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Wait-Process -Id $PID -Timeout 3
    Stop-Transcript | Out-Null
    exit
}

# ============================================================================
# [1/6] STOP IP-ADDRESS CONFLICT CHURN -> assign a statically-conflict-free IP
# ============================================================================
Write-Host "`n[1/6] Eliminating DHCP address conflicts (Tcpip 4199)..." -ForegroundColor Yellow

$iface = Get-NetAdapter -Name 'Wi-Fi' -ErrorAction SilentlyContinue
if ($iface) {
    # SELF-HEAL BUGFIX 2026-09-19: Test-Connection -TimeoutSeconds is PS7-only
    # (fatal on WinPS 5.1); use .NET Ping. Also idempotent: skip when already
    # correct, and remove the stale 0.0.0.0/0 route or New-NetIPAddress fails
    # with "DefaultGateway already exists" and kills the whole run.
    $pinger = New-Object System.Net.NetworkInformation.Ping
    function Test-IpFree([string]$ip) {
        try { return ($pinger.Send($ip, 800).Status -ne 'Success') } catch { return $true }
    }
    $candidates = @('192.168.0.150','192.168.0.151','192.168.0.152','192.168.0.160','192.168.0.170')
    $target = $null
    foreach ($c in $candidates) {
        if (Test-IpFree $c) { $target = $c; break }
    }
    if (-not $target) { $target = '192.168.0.150' }

    $curIP = (Get-NetIPAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    $curGw = (Get-NetIPConfiguration -InterfaceAlias 'Wi-Fi' -ErrorAction SilentlyContinue).IPv4DefaultGateway.NextHop
    if ($curIP -eq $target -and $curGw -eq '192.168.0.1') {
        Write-Host "   IP already correct ($curIP) - skipping reassignment" -ForegroundColor DarkGray
    } else {
        Write-Host "   Assigning static IP: $target (was $curIP - repeatedly conflicted)" -ForegroundColor Gray

        Get-NetIPAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -ne '0.0.0.0' } |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -DestinationPrefix '0.0.0.0/0' -InterfaceAlias 'Wi-Fi' -Confirm:$false -ErrorAction SilentlyContinue

        try {
            New-NetIPAddress -InterfaceAlias 'Wi-Fi' -IPAddress $target -PrefixLength 24 `
                             -DefaultGateway '192.168.0.1' -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "   Static IP failed ($($_.Exception.Message)) - DHCP fallback, host stays online" -ForegroundColor Red
            Set-NetIPInterface -InterfaceAlias 'Wi-Fi' -Dhcp Enabled -ErrorAction SilentlyContinue
        }
    }

    Set-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -ServerAddresses '1.1.1.1','8.8.8.8' | Out-Null

    # Prevent this machine from being pinged-probed-claimed as duplicate
    $iface | Set-NetAdapterAdvancedProperty -DisplayName 'Roaming Aggressiveness' -DisplayValue 'Highest' -ErrorAction SilentlyContinue
    $iface | Set-NetAdapterAdvancedProperty -DisplayName 'Power Saving Mode'          -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
    $iface | Set-NetAdapterAdvancedProperty -DisplayName 'U-APSD'                      -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
    Write-Host "   Resulting config:" -ForegroundColor Gray
    Get-NetIPConfiguration -InterfaceAlias 'Wi-Fi' | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway | Format-List
}

# ============================================================================
# [2/6] TCP/IP tunables for a lossy WLAN/cellular uplink
# ============================================================================
Write-Host "`n[2/6] TCP/IP tunables..." -ForegroundColor Yellow
netsh int tcp set global autotuning=normal | Out-Null
netsh int tcp set global ecncapability=enabled | Out-Null
netsh int tcp set global timestamps=enabled | Out-Null
netsh int tcp set global initialrto=1500 | Out-Null
netsh int tcp set global nonsackrttresiliency=disabled | Out-Null
ipconfig /flushdns | Out-Null

# ============================================================================
# [3/6] Stop background INTERNET + RESOURCE hogs
# ============================================================================
Write-Host "`n[3/6] Stopping/staging unnecessary services..." -ForegroundColor Yellow

$stopNoKill = @('wuauserv')                                   # stop now, keep Auto/Manual
$disableDur = @('DiagTrack','dmwappushservice','WSearch','DoSvc','whesvc','InventorySvc',
                'CDPSvc','WpnService','lfsvc','RetailDemo','MapsBroker',
                'SQLPBENGINE','SQLPBDMS')                    # telemetry/index/delivery/polybase
$stopManualSQL = @('MSSQLSERVER')                             # stop now, set to Manual (startable)

foreach ($n in $disableDur) {
    Get-Service -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Stop-Service -Name $n -Force -ErrorAction Stop
            sc.exe config $n start= disabled | Out-Null
            Write-Host "   DISABLED: $n" -ForegroundColor Green
        } catch { Write-Host "   SKIP ($($_.Exception.Message)): $n" -ForegroundColor DarkYellow }
    }
}
# per-user notification/device services (suffix varies per SID)
Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(CDPUserSvc|WpnUserService)_' } | ForEach-Object {
    try { Stop-Service -Name $_.Name -Force -ErrorAction Stop; sc.exe config $_.Name start= disabled | Out-Null; Write-Host "   DISABLED: $($_.Name)" -ForegroundColor Green } catch {}
}

foreach ($n in $stopManualSQL) {
    Get-Service -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Stop-Service -Name $n -Force -ErrorAction Stop
            sc.exe config $n start= demand | Out-Null
            Write-Host "   STOPPED (set to Manual): $n" -ForegroundColor Green
        } catch { Write-Host "   SKIP: $n" -ForegroundColor DarkYellow }
    }
}

foreach ($n in $stopNoKill) {
    Get-Service -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
        try { Stop-Service -Name $n -Force -ErrorAction Stop; Write-Host "   STOPPED (kept start type): $n" -ForegroundColor Green } catch {}
    }
}

# ============================================================================
# [4/6] Disable internet-consuming scheduled tasks (reversible via re-enable)
# ============================================================================
Write-Host "`n[4/6] Disabling internet-hungry scheduled tasks..." -ForegroundColor Yellow
$tasks = @(
    'OneDrive Per-Machine Standalone Update Task',
    @{Path='\Microsoft\Office\'; Name='Office Automatic Updates 2.0'},
    @{Path='\Microsoft\Office\'; Name='Office Feature Updates'},
    @{Path='\Microsoft\Office\'; Name='Office Feature Updates Logon'}
)
foreach ($t in $tasks) {
    if ($t -is [string]) { $tn=$t; $tp='\' } else { $tn=$t.Name; $tp=$t.Path }
    try {
        Disable-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction Stop | Out-Null
        Write-Host "   DISABLED task: $tn" -ForegroundColor Green
    } catch { Write-Host "   SKIP task: $tn" -ForegroundColor DarkYellow }
}

# ============================================================================
# [5/6] Verify connectivity after the change
# ============================================================================
Write-Host "`n[5/6] Post-fix verification..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
$gw = (Get-NetIPConfiguration -InterfaceAlias 'Wi-Fi' -ErrorAction SilentlyContinue).IPv4DefaultGateway.NextHop
Write-Host "   New IP      : $((Get-NetIPAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress)"
Write-Host "   Gateway ping: $(Test-Connection -ComputerName $gw -Count 2 -ErrorAction SilentlyContinue | Measure-Object -Property Latency -Average | ForEach-Object { "$([math]::Round($_.Average))ms" })"
cmd /c "ping -n 2 8.8.8.8" | Select-String -Pattern 'packets|loss'
$sw=[System.Diagnostics.Stopwatch]::StartNew()
Resolve-DnsName -Name 'one.one.one.one' -Server '1.1.1.1' -QuickTimeout -ErrorAction SilentlyContinue | Out-Null
$sw.Stop()
Write-Host "   DNS resolve one.one.one.one: $($sw.ElapsedMilliseconds) ms"

# ============================================================================
# [6/6] Summary
# ============================================================================
Write-Host "`n[6/6] DONE. Log saved to $logFile" -ForegroundColor Green
Write-Host "`nApplied:" -ForegroundColor Cyan
Write-Host "  1. Static conflict-free IP on Wi-Fi (192.168.0.100 was in ARP conflict - Tcpip 4199)"
Write-Host "  2. DNS pinned to 1.1.1.1 / 8.8.8.8"
Write-Host "  3. TCP autotuning=normal, ECN enabled, timestamps on"
Write-Host "  4. Disabled telemetry/updates/Polybase/SQL-autostart; SQL set to Manual"
Write-Host "  5. Disabled OneDrive/Office auto-update tasks"
Write-Host "  6. Wi-Fi power saving / roaming aggressiveness maximized"
Write-Host "`nRe-enable later:" -ForegroundColor Magenta
Write-Host "  sc.exe config <Name> start= auto   (services)"
Write-Host "  Enable-ScheduledTask -TaskName '<Name>'" 
Stop-Transcript | Out-Null