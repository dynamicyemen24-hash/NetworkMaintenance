# ====================================================================
# NetworkMaintenance-Pro v2.0.0 - Initialization Module
# ====================================================================
# Description: Initializes the maintenance system, creates environment
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\Config.json",
    [switch]$ForceInit
)

$ScriptRoot = "C:\NetworkMaintenance"
$LogDir = "$ScriptRoot\Logs"
$ReportDir = "$ScriptRoot\Reports"
$ConfigDir = "$ScriptRoot\Config"
$ScriptDir = "$ScriptRoot\Scripts"

function Initialize-System {
    Write-Host "[INIT] Starting NetworkMaintenance-Pro v2.0.0..." -ForegroundColor Cyan
    
    # Create directory structure
    $dirs = @($ScriptRoot, $LogDir, $ReportDir, $ConfigDir, "$ScriptRoot\Temp", "$ScriptRoot\Backup")
    foreach ($dir in $dirs) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "[INIT] Created directory: $dir" -ForegroundColor Green
        }
    }
    
    # Initialize log file
    $logFile = "$LogDir\Maintenance_$(Get-Date -Format 'yyyyMMdd').log"
    if (!(Test-Path $logFile)) {
        New-Item -ItemType File -Path $logFile -Force | Out-Null
    }
    
    # Initialize system registry
    $sysReg = @{
        SystemName = "NetworkMaintenance-Pro"
        Version = "2.0.0"
        LastRun = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Status = "INITIALIZED"
        TotalRuns = 0
        TotalFixes = 0
    }
    
    $sysReg | ConvertTo-Json | Set-Content "$ScriptRoot\Config\SystemState.json" -Force
    
    Write-Host "[INIT] System initialized successfully!" -ForegroundColor Green
    return $true
}

function Get-SystemState {
    if (Test-Path "$ScriptRoot\Config\SystemState.json") {
        return Get-Content "$ScriptRoot\Config\SystemState.json" | ConvertFrom-Json
    }
    return $null
}

function Update-SystemState {
    param([string]$Status, [string]$Message = "")
    $state = Get-SystemState
    if ($state) {
        $state.Status = $Status
        $state.LastRun = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $state.LastMessage = $Message
        if ($status -eq "FIXED") { $state.TotalFixes++ }
        $state.TotalRuns++
        $state | ConvertTo-Json | Set-Content "$ScriptRoot\Config\SystemState.json" -Force
    }
}

Initialize-System
