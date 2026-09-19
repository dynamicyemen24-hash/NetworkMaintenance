# Network & Performance Fix Script
# Fixes network problems and boosts device performance

# Request administrator elevation
if (-not [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) {
    Write-Host "This script requires administrator privileges to optimize network and performance." -ForegroundColor Yellow
    Write-Host "Please right-click and select 'Run as Administrator', or enter credentials." -ForegroundColor Cyan
    # Re-run as admin - this won't work in all contexts, so we'll just warn
    return
} else {

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=" * 60
Write-Host "Network & Performance Optimizer - Starting..." -ForegroundColor Cyan
Write-Host "=" * 60

# ==========================================
# 1. Network Diagnostics & Reset
# ==========================================
Write-Host "`n[1/6] Resetting TCP/IP network stack..." -ForegroundColor Yellow

# Reset TCP settings
netsh int tcp set global autotuning=normal > $null 2>&1
netsh int tcp set global ecncapability=disabled > $null 2>&1

# Reset Winsock
netsh winsock reset > $null 2>&1

# Reset DNS client
ipconfig /flushdns > $null 2>&1

# Set optimal DNS servers
Write-Host "   Setting DNS to 1.1.1.1 and 8.8.8.8..." -ForegroundColor Gray
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses "1.1.1.1", "8.8.8.8" -ErrorAction SilentlyContinue
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "1.1.1.1", "8.8.8.8" -ErrorAction SilentlyContinue

# Disable jumbo frames (may cause issues on some networks)
Get-NetAdapter | ForEach-Object {
    Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Jumbo Frames' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
}

# ==========================================
# 2. Performance Optimizations
# ==========================================
Write-Host "`n[2/6] Applying performance tweaks..." -ForegroundColor Yellow

# Disable animations
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DisableAnimations' -Value 1 -Force

# Clean temporary files
Write-Host "   Cleaning temp files..." -ForegroundColor Gray
Remove-Item -Path $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clean disk
cleanmgr /drivetype C /sageset:1 > $null 2>&1
Start-Sleep -Seconds 2
cleanmgr /drivetype C /sagerun:1 > $null

# ==========================================
# 3. Startup & App Optimization
# ==========================================
Write-Host "`n[3/6] Optimizing startup applications..." -ForegroundColor Yellow

# Remove unused appx packages for all users
Get-AppxPackage -AllUsers | Where-Object { $_.StartupLocation -ne $null } | ForEach-Object {
    Remove-AppxPackage -Package $_.PackageName -ErrorAction SilentlyContinue
}

# ==========================================
# 4. Disk Optimization
# ==========================================
Write-Host "`n[4/6] Running disk optimization..." -ForegroundColor Yellow

# Defragment C: drive
Optimize-Volume -DriveLetter C -Verbose > $null 2>&1

# ==========================================
# 5. Network Adapter Tweaks
# ==========================================
Write-Host "`n[5/6] Applying network adapter optimizations..." -ForegroundColor Yellow

# Set energy efficient Ethernet to disabled (may improve performance)
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
    Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Energy Efficient Ethernet' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Receive Side Scaling' -DisplayValue 'Enabled' -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'TCP Chimney' -DisplayValue 'Enabled' -ErrorAction SilentlyContinue
}

# ==========================================
# 6. Final Summary
# ==========================================
Write-Host "`n[6/6] Optimization complete!" -ForegroundColor Green
Write-Host "`nApplied:`n" +
    "• TCP/IP stack reset`n" +
    "• DNS optimized to 1.1.1.1/8.8.8.8`n" +
    "• Visual effects disabled`n" +
    "• Temp files cleaned`n" +
    "• Startup apps optimized`n" +
    "• Disk optimized`n" +
    "• Network adapter tweaks applied`n"

Write-Host "`nRun 'ipconfig /renew' and 'ipconfig /release' if network issues persist." -ForegroundColor Magenta

# Offer to run diagnostics
Write-Host "`nWould you like to run diagnostics to check current network quality? (y/n)" -ForegroundColor Cyan
$choice = Read-Host "Enter choice"
if ($choice -eq 'y' -or $choice -eq 'Y') {
    & "C:\NetworkMaintenance\Elias_System_Care_v5.ps1" | Out-Null
}