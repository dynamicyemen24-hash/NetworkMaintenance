# Housekeeping (elevated): (re)register NMS tasks, prove persistence, dump evidence.
Start-Transcript -Path "C:\NetworkMaintenance\Logs\Housekeeping-$(Get-Date -Format yyyyMMdd-HHmmss).log" -Append | Out-Null
$proof = "C:\NetworkMaintenance\Reports\task-persistence-proof.txt"

& "C:\NetworkMaintenance\Scripts\Register-NetworkReliabilityTasks.ps1" | Out-Null

"=== IMMEDIATE LIST ===" | Set-Content $proof
Get-ScheduledTask -TaskName 'NMS-NetHealth-Watchdog','NMS-NetConflict-Response','NMS-NetLinkRecovery-Response' -ErrorAction SilentlyContinue | Format-Table -AutoSize | Out-String -Width 200 | Add-Content $proof
"=== schtasks exit code: $LASTEXITCODE ===" | Add-Content $proof
& schtasks /query /fo csv | Select-String 'NMS-' | ForEach-Object { $_.Line } | Add-Content $proof
Start-Sleep -Seconds 20
"=== AFTER 20s ===" | Add-Content $proof
Get-ScheduledTask -TaskName 'NMS-NetHealth-Watchdog','NMS-NetConflict-Response','NMS-NetLinkRecovery-Response' -ErrorAction SilentlyContinue | Format-Table -AutoSize | Out-String -Width 200 | Add-Content $proof
"=== TaskScheduler events mentioning NMS ===" | Add-Content $proof
Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 500 -ErrorAction SilentlyContinue | Where-Object { $_.Message -match 'NMS-' } | Select-Object -First 20 TimeCreated, Id, @{n='Msg';e={$_.Message.Substring(0,[Math]::Min(120,$_.Message.Length))}} | Format-List | Out-String -Width 200 | Add-Content $proof
Stop-Transcript | Out-Null