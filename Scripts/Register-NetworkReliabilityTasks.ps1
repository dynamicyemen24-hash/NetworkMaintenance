# ============================================================================
#  Register-NetworkReliabilityTasks.ps1  (requires elevation)
#  Installs the persistent self-healing scheduling fabric:
#    NMS-NetHealth-Watchdog        : AT LOGON + every 30 minutes (SYSTEM) [light: was 5 min]
#    NMS-NetConflict-Response      : on Tcpip 4199  (IP conflict)
#    NMS-NetLinkRecovery-Response  : on WLAN AutoConfig 4003 (limited connectivity)
#  Self-contained: generates event-trigger XML as UTF-16 (schtasks-compliant).
#  PERF 2026-09-19: 5min -> 30min (6x less CPU/wakeups/internet), cooldowns kept.
# ============================================================================
$ErrorActionPreference = 'SilentlyContinue'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$watchdogArg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Network-Reliability-Watchdog.ps1"'

# --- periodic watcher: logon + every 30 minutes (light) ---------------------------
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $watchdogArg
$triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn),
    (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
        -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 3650))
)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 3)
Register-ScheduledTask -TaskName 'NMS-NetHealth-Watchdog' -Action $action -Trigger $triggers -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Write-Host "[+] NMS-NetHealth-Watchdog registered (logon + every 30 min, SYSTEM)" -ForegroundColor Green

# --- event-driven instant responders ------------------------------------------
# schtasks /Create /XML requires the file in UTF-16(C). Generate in-memory.
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
    <Date>2026-09-18T00:00:00</Date>
    <Author>NMS</Author>
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
      <Arguments>$watchdogArg</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    $tmp = Join-Path $env:TEMP ("$taskName.xml")
    $xml | Set-Content -Path $tmp -Encoding Unicode
    & schtasks /Create /TN $taskName /XML $tmp /F | Out-Null
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Host "[+] $taskName registered (event-triggered)" -ForegroundColor Green
}

# --- fire once immediately for a baseline seed ---------------------------------
& powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Network-Reliability-Watchdog.ps1" | Out-Null
Write-Host "[+] Initial watchdog run completed" -ForegroundColor Green

Get-ScheduledTask -TaskName 'NMS-NetHealth-Watchdog','NMS-NetConflict-Response','NMS-NetLinkRecovery-Response' -ErrorAction SilentlyContinue |
    Select-Object TaskName, State, @{n='RunAs';e={$_.Principal.UserId}} | Format-Table -AutoSize