Add-Type -AssemblyName "Microsoft.VisualBasic"
$WshShell = New-Object -ComObject Wscript.Shell
$pinPath = [Environment]::GetFolderPath('CommonStartMenu') + '\Programs\Startup\'
if (-not (Test-Path $pinPath)) { mkdir $pinPath -Force }
$lnkPath = $pinPath + '\Elias_PC_Care.lnk'
$shortcut = $WshShell.CreateShortcut($lnkPath)
$shortcut.TargetPath = 'powershell.exe'
$shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\elias_pc_care.ps1"'
$shortcut.Save()
Write-Host 'Taskbar pin shortcut created successfully' -ForegroundColor Green