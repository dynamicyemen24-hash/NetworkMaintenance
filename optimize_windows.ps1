$ErrorActionPreference = 'SilentlyContinue'

# Performance optimization functions
function Optimize-Performance {
    # Disable unnecessary visual effects
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DisableAnimations' -Value 1 -Force
    
    # Reduce startup apps
    Get-AppxPackage -AllUsers | Where-Object { $_.StartupLocation -ne $null } | ForEach-Object { 
        Remove-AppxPackage -Package $_.PackageName -ErrorAction SilentlyContinue 
    }
    
    # Clean temporary files
    Remove-Item -Path $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $env:USERPROFILE\\AppData\Local\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
    
    # Disk cleanup
    cleanmgr /drivetype C /sageset:1 /compute > $null
    
    # Network optimization
    Get-NetAdapter | ForEach-Object {
        Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Jumbo Frames' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
    }
    
    # Reset TCP settings
    netsh int tcp set global autotuning=normal
    
    # Disk optimization
    Optimize-Volume -DriveLetter C -Verbose > $null 2>&1
    
    # Disk cleanup
    cleanmgr /drivetype C /sagerun:1 > $null
    
    Write-Host "Optimization complete!" -ForegroundColor Green
}

# Run optimization
Optimize-Performance