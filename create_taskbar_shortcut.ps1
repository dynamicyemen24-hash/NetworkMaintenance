Add-Type -AssemblyName "Microsoft.VisualBasic"
$WshShell = New-Object -ComObject Wscript.Shell
$tbPath = [Environment]::GetFolderPath('CommonApplicationData') + '\Microsoft\Internet Explorer\Quick Launch\'
if (-not (Test-Path $tbPath)) { mkdir $tbPath -Force }
$shortcutPath = $tbPath + '\Elias_Performance_Tweak.lnk'
$target = "powershell.exe"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"C:\NetworkMaintenance\optimize_windows.ps1`""
$workingDir = "C:\NetworkMaintenance"

$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = $workingDir
$shortcut.Save()

Write-Host "Taskbar shortcut created at: $shortcutPath" -ForegroundColor Green