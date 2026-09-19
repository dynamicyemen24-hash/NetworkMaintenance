Add-Type -AssemblyName "Microsoft.VisualBasic"
$WshShell = New-Object -ComObject Wscript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = "$desktop\Elias_System_Care.lnk"
$target = "powershell.exe"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"C:\NetworkMaintenance\Elias_System_Care_v5.ps1`""
$workingDir = "C:\NetworkMaintenance"
$icon = "C:\Windows\System32\imageres.dll, 57"

$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = $workingDir
$shortcut.IconLocation = $icon
$shortcut.Save()

Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Green
Write-Host "Application: $($config.AppName) v$($config.Version)" -ForegroundColor Cyan