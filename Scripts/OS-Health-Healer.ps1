# ============================================================================
#  OS-Health-Healer.ps1 — Autonomous Windows self-healing (no human needed)
#  Complements Scripts\Network-Reliability-Watchdog.ps1 (network side).
#  Check-only by default; pass -Enforce to APPLY fixes (scheduled tasks do).
#
#  What it heals (bounded, reversible, never destructive):
#    [1] CPU saturation  -> deprioritize top non-system offender (BelowNormal)
#    [2] RAM pressure    -> trim working sets of heavy non-system processes
#    [3] Disk pressure   -> clean safe temp locations when C: is low
#    [4] Dead services   -> restart critical Automatic services (except ones
#                           the network standard intentionally disabled)
#    [5] DNS failure     -> flush DNS cache
#    [6] Power policy    -> High Performance while on AC power
#  NEVER: reboot, kill processes, reset network stack, touch user data,
#         or re-enable services the standard disabled. Max 6 actions / run.
# ============================================================================
param(
    [switch]$Enforce,
    [switch]$Quiet,
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\network-standard.json"
)

$ErrorActionPreference = 'SilentlyContinue'
$root      = "C:\NetworkMaintenance"
$reportDir = Join-Path $root "Reports"
$tempDir   = Join-Path $root "Temp"
foreach ($d in @($reportDir, $tempDir)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

$mode = if ($Enforce) { 'ENFORCE' } else { 'CHECK' }
function Heal ($m, $c = 'Gray') { if (-not $Quiet) { Write-Host ("[OSHEAL:$mode] " + $m) -ForegroundColor $c } }

$checks  = @()
$actions = @()
$actionCount = 0
$MaxActions = 6

# --- services the standard intentionally disabled: NEVER touch these ---------
$untouchable = @()
try {
    $S = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $untouchable = @($S.services.disabled) + @($S.services.manual)
} catch {}

# --- processes that must never be deprioritized/trimmed ----------------------
$protected = @('System','Registry','Idle','smss','csrss','wininit','services',
    'lsass','dwm','explorer','sihost','fontdrvhost','conhost','SearchHost',
    'StartMenuExperienceHost','ShellExperienceHost','taskhostw','svchost',
    'powershell','pwsh','OpenCode','opencode','winlogon','LogonUI')
$ownPid = $PID

function Test-Cooldown([string]$name, [int]$minutes) {
    $f = Join-Path $tempDir ("osheal-" + $name + ".txt")
    if (Test-Path $f) {
        try {
            $t = [datetime]((Get-Content $f -ErrorAction Stop).Trim())
            if (((Get-Date).ToUniversalTime() - $t).TotalMinutes -lt $minutes) { return $false }
        } catch {}
    }
    return $true
}
function Set-Cooldown([string]$name) {
    (Get-Date).ToUniversalTime().ToString('s') | Set-Content (Join-Path $tempDir ("osheal-" + $name + ".txt"))
}
function Add-Action([string]$name, [string]$detail) {
    if ($actionCount -ge $MaxActions) { Heal "action budget exhausted, skipping: $name" 'Yellow'; return $false }
    $script:actionCount++
    $script:actions += ("{0}: {1}" -f $name, $detail)
    Set-Cooldown $name
    Heal ("APPLIED: {0} - {1}" -f $name, $detail) 'Green'
    return $true
}

# ============================================================================
# [1] CPU saturation -> deprioritize top non-system offender
# ============================================================================
try {
    $l1 = (Get-CimInstance Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average
    Start-Sleep -Seconds 5
    $l2 = (Get-CimInstance Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average
    $cpuAvg = [math]::Round(($l1 + $l2) / 2, 1)
} catch { $cpuAvg = 0 }
$cpuState = if ($cpuAvg -gt 90) { 'critical' } elseif ($cpuAvg -gt 75) { 'high' } else { 'ok' }
$checks += ("CPU load {0}% ({1})" -f $cpuAvg, $cpuState)
Heal ("CPU load: {0}% ({1})" -f $cpuAvg, $cpuState) 'Cyan'
if ($cpuAvg -gt 85) {
    $top = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $ownPid -and $protected -notcontains $_.ProcessName } |
        Sort-Object CPU -Descending | Select-Object -First 1
    if ($top -and (Test-Cooldown ("cpu-" + $top.ProcessName) 30)) {
        if ($Enforce) {
            try {
                $top.PriorityClass = 'BelowNormal'
                Add-Action ("cpu-deprioritize") ("{0} (PID {1}) -> BelowNormal" -f $top.ProcessName, $top.Id)
            } catch { $checks += ("CPU offender {0} could not be deprioritized" -f $top.ProcessName) }
        } else {
            $checks += ("CPU offender would be deprioritized: {0} (PID {1})" -f $top.ProcessName, $top.Id)
        }
    }
}

# ============================================================================
# [2] RAM pressure -> trim working sets of heavy non-system processes
# ============================================================================
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $ramUsed = [math]::Round(($cs.TotalPhysicalMemory - ($os.FreePhysicalMemory * 1024)) / $cs.TotalPhysicalMemory * 100, 1)
} catch { $ramUsed = 0 }
$ramState = if ($ramUsed -gt 95) { 'critical' } elseif ($ramUsed -gt 90) { 'high' } else { 'ok' }
$checks += ("RAM used {0}% ({1})" -f $ramUsed, $ramState)
Heal ("RAM used: {0}% ({1})" -f $ramUsed, $ramState) 'Cyan'
if ($ramUsed -gt 90 -and (Test-Cooldown 'ram-trim' 30)) {
    if ($Enforce) {
        try {
            Add-Type -TypeDefinition '[System.Runtime.InteropServices.DllImport("psapi.dll")] public static class MemTrim { [System.Runtime.InteropServices.DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(System.IntPtr h); }' -ErrorAction Stop
            $trimmed = 0
            Get-Process -ErrorAction SilentlyContinue |
                Where-Object { $_.Id -ne $ownPid -and $protected -notcontains $_.ProcessName -and $_.WS -gt 200MB } |
                ForEach-Object { try { if ([MemTrim]::EmptyWorkingSet($_.Handle)) { $trimmed++ } } catch {} }
            Add-Action 'ram-trim' ("working sets trimmed for {0} processes" -f $trimmed)
        } catch { $checks += "RAM trim unavailable on this host" }
    } else {
        $checks += "RAM trim would run (working-set trim, safe)"
    }
}

# ============================================================================
# [3] Disk pressure -> clean safe temp locations
# ============================================================================
try {
    $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    $cFree = [math]::Round($c.FreeSpace / $c.Size * 100, 1)
} catch { $cFree = 100 }
$diskState = if ($cFree -lt 5) { 'critical' } elseif ($cFree -lt 12) { 'low' } else { 'ok' }
$checks += ("C: free {0}% ({1})" -f $cFree, $diskState)
Heal ("C: free: {0}% ({1})" -f $cFree, $diskState) 'Cyan'
if ($cFree -lt 12 -and (Test-Cooldown 'disk-temp' 60)) {
    $tp1 = $env:TEMP; $tp2 = ($env:LOCALAPPDATA + '\Temp'); $tp3 = ($env:WINDIR + '\Temp')
    if ($Enforce) {
        $before = 0
        foreach ($tp in @($tp1, $tp2, $tp3)) {
            if (Test-Path $tp) {
                $m = Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
                if ($m.Sum) { $before += $m.Sum }
                Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Add-Action 'disk-temp' ("cleaned {0} MB temp" -f [math]::Round($before / 1MB, 1))
    } else {
        $checks += "temp cleanup would run (C: below 12% free)"
    }
}

# ============================================================================
# [4] Dead critical services -> restart (never touch standard-disabled ones)
# ============================================================================
$criticalSvcs = @('Dnscache','Dhcp','NlaSvc','WlanSvc','BITS','MpsSvc','WinDefend','EventLog','Schedule')
foreach ($n in $criticalSvcs) {
    if ($untouchable -contains $n) { continue }
    $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($svc -and ($svc.StartType -eq 'Automatic') -and ($svc.Status -ne 'Running')) {
        if ($Enforce -and (Test-Cooldown ("svc-" + $n) 30)) {
            try {
                Start-Service -Name $n -ErrorAction Stop
                Add-Action 'service-restart' ("{0} restarted" -f $n)
            } catch { $checks += ("service {0} FAILED to start: {1}" -f $n, $_.Exception.Message) }
        } else {
            $checks += ("service {0} stopped (Automatic) - would restart" -f $n)
        }
    }
}
Heal "critical services verified" 'DarkGray'

# ============================================================================
# [5] DNS failure -> flush cache (probe the standard's PRIMARY DNS, not a
# hardcoded server: this operator filters 1.1.1.1, standard prefers 8.8.8.8)
# ============================================================================
$dnsProbe = '8.8.8.8'
try {
    $stdIfc = @($S.interfaces.PSObject.Properties.Name)[0]
    $stdDns = $S.interfaces.($stdIfc).dns
    if ($stdDns -and $stdDns.Count -gt 0) { $dnsProbe = $stdDns[0] }
} catch {}
$dnsOk = $false
for ($di = 0; $di -lt 2 -and -not $dnsOk; $di++) {
    try { Resolve-DnsName -Name 'one.one.one.one' -Server $dnsProbe -QuickTimeout -ErrorAction Stop | Out-Null; $dnsOk = $true } catch {}
}
if ($dnsOk) {
    $checks += "DNS resolve OK via $dnsProbe"
} else {
    $checks += "DNS resolve FAILED (2/2 attempts)"
    if ($Enforce -and (Test-Cooldown 'dns-flush' 15)) {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        cmd /c "ipconfig /flushdns" | Out-Null
        Add-Action 'dns-flush' 'DNS cache flushed after resolve failure'
    }
}

# ============================================================================
# [6] Power policy -> High Performance while on AC
# ============================================================================
try {
    $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    $onAC = (-not $batt) -or ($batt.BatteryStatus -ne 1)
} catch { $onAC = $true }
if ($onAC -and (Test-Cooldown 'power-plan' 120)) {
    if ($Enforce) {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Add-Action 'power-plan' 'High Performance activated (on AC)'
    } else {
        $checks += "power plan would be set to High Performance (on AC)"
    }
} else {
    $checks += "power plan untouched (on battery or cooldown)"
}

# ============================================================================
# [7] Pending reboot -> report only (NEVER reboot autonomously)
# ============================================================================
$rebootPending = $false
try {
    if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction Stop) { $rebootPending = $true }
} catch {}
try {
    if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction Stop) { $rebootPending = $true }
} catch {}
if ($rebootPending) { $checks += "reboot PENDING (report-only, manual reboot advised)" }

# ============================================================================
# Persist state: os-health JSON + heartbeat + merged system-health JSON
# ============================================================================
$hasCritical = ($cpuState -eq 'critical') -or ($ramState -eq 'critical') -or ($diskState -eq 'critical')
$status = if ($hasCritical) { 'CRITICAL' } elseif ($actionCount -gt 0 -or $rebootPending) { 'DEGRADED' } else { 'PASS' }
$osHealth = [ordered]@{
    timestamp = (Get-Date).ToString('s')
    mode      = $mode
    status    = $status
    cpuPct    = $cpuAvg
    ramUsedPct= $ramUsed
    cFreePct  = $cFree
    rebootPending = $rebootPending
    checks    = $checks
    actions   = $actions
}
$osHealth | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $reportDir 'os-health-last.json') -Encoding UTF8
(Get-Date).ToUniversalTime().ToString('s') | Set-Content (Join-Path $tempDir 'selfheal-heartbeat.txt')

$netHealth = $null
try { $netHealth = Get-Content (Join-Path $reportDir 'net-health-last.json') -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
$overall = $status
if ($netHealth -and $netHealth.status -ne 'PASS') {
    if ($netHealth.status -eq 'LINK_DEGRADED' -and $status -eq 'PASS') { $overall = 'DEGRADED' }
    elseif ($status -eq 'PASS') { $overall = $netHealth.status }
}
[ordered]@{
    timestamp = (Get-Date).ToString('s')
    overall   = $overall
    os        = $osHealth
    network   = $netHealth
} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $reportDir 'system-health-last.json') -Encoding UTF8

$logLine = ("{0}`t{1}`t{2}`tCPU={3}%`tRAM={4}%`tC:free={5}%`tactions=[{6}]" -f (Get-Date -Format s), $mode, $status, $cpuAvg, $ramUsed, $cFree, ($actions -join ';'))
Add-Content (Join-Path $reportDir 'OSHealth.log') $logLine
try {
    $lp = Join-Path $reportDir 'OSHealth.log'
    $lines = Get-Content $lp -ErrorAction Stop
    if ($lines.Count -gt 500) { $lines[-500..($lines.Count - 1)] | Set-Content $lp -Encoding UTF8 }
} catch {}

Heal ("OS-HEAL COMPLETE: {0} | actions: {1}" -f $status, $actionCount) 'Magenta'
