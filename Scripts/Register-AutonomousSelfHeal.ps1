# ============================================================================
#  Register-AutonomousSelfHeal.ps1  (requires elevation - self-elevates once)
#  Installs the FULL autonomous self-healing fabric (no human needed after):
#    NMS-NetHealth-Watchdog        : logon + every 30 min (SYSTEM) - network
#    NMS-NetConflict-Response      : on Tcpip 4199 (IP conflict) - event
#    NMS-NetLinkRecovery-Response  : on WLAN AutoConfig 4003 - event
#    NMS-OSHealth-Healer           : logon + every 30 min offset 15 min (SYSTEM)
#  Then fires one baseline enforcement run of each healer.
#  Idempotent: safe to re-run any time.
# ============================================================================
$ErrorActionPreference = 'SilentlyContinue'
$root = "C:\NetworkMaintenance"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] NOT elevated - re-launching once via UAC..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$netArg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Network-Reliability-Watchdog.ps1" -Quiet'
$osArg  = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\OS-Health-Healer.ps1" -Enforce -Quiet'

function Register-Periodic([string]$name, [string]$taskArgs, [int]$offsetMin) {
    $action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs
    $triggers = @(
        (New-ScheduledTaskTrigger -AtLogOn),
        (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($offsetMin) `
            -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 3650))
    )
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 3)
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $triggers -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Write-Host ("[+] {0} registered (logon + every 30 min, SYSTEM)" -f $name) -ForegroundColor Green
}

Register-Periodic 'NMS-NetHealth-Watchdog' $netArg 1
Register-Periodic 'NMS-OSHealth-Healer'    $osArg  15

# Fallback: cmdlet registration silently fails for some names under SYSTEM.
# Re-register the OS healer via schtasks/XML (proven path, same as event tasks).
$osXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2026-09-19T00:00:00</Date>
    <Author>NMS-SelfHeal</Author>
    <Description>Autonomous OS self-healing (CPU/RAM/disk/services/DNS/power).</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <TimeTrigger>
      <Repetition>
        <Interval>PT30M</Interval>
        <Duration>P3650D</Duration>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>2026-09-19T23:00:00</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <LogonType>ServiceAccount</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <ExecutionTimeLimit>PT3M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>$osArg</Arguments>
    </Exec>
  </Actions>
</Task>
"@
$osTmp = Join-Path $env:TEMP "NMS-OSHealth-Healer.xml"
$osXml | Set-Content -Path $osTmp -Encoding Unicode
& schtasks /Create /TN 'NMS-OSHealth-Healer' /XML $osTmp /F | Out-Null
Remove-Item $osTmp -Force -ErrorAction SilentlyContinue
Write-Host "[+] NMS-OSHealth-Healer registered via XML (logon + every 30 min, SYSTEM)" -ForegroundColor Green

$events = @{
    'NMS-NetConflict-Response'     = "*[System[Provider[@Name='Tcpip'] and EventID=4199]]"
    'NMS-NetLinkRecovery-Response' = "*[System[Provider[@Name='Microsoft-Windows-WLAN-AutoConfig'] and EventID=4003]]"
}
foreach ($taskName in $events.Keys) {
    $query = $events[$taskName]
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2026-09-19T00:00:00</Date>
    <Author>NMS-SelfHeal</Author>
    <Description>Event-driven self-heal runner for $taskName.</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;$query&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <ExecutionTimeLimit>PT3M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>$netArg</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    $tmp = Join-Path $env:TEMP ("$taskName.xml")
    $xml | Set-Content -Path $tmp -Encoding Unicode
    & schtasks /Create /TN $taskName /XML $tmp /F | Out-Null
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Host ("[+] {0} registered (event-triggered)" -f $taskName) -ForegroundColor Green
}

# --- baseline: enforce standard + heal OS once, right now --------------------
Write-Host "[*] Baseline enforcement run..." -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\Scripts\Apply-NetworkStandard.ps1" | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\Scripts\OS-Health-Healer.ps1" -Enforce | Out-Null
Write-Host "[+] Baseline runs completed" -ForegroundColor Green

Get-ScheduledTask -TaskName 'NMS-NetHealth-Watchdog','NMS-OSHealth-Healer','NMS-NetConflict-Response','NMS-NetLinkRecovery-Response' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State, @{n='RunAs';e={$_.Principal.UserId}} | Format-Table -AutoSize
