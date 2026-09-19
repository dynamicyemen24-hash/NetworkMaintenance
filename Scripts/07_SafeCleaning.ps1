# ====================================================================
# NetworkMaintenance-Pro v2.0.0 - Safe Cleaning Module (v2 Compat)
# ====================================================================
# Description: Whitelist-based safe cleaning for dev environment
# Standards: ITIL v4 | ISO 27001 | Zero-Trust
# Safety: Conservative/Balanced/Aggressive + DryRun + No Re-Download
# Wrapper: Calls SCE-Engine v3.0 internally for unified logic
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\Config.json",
    [string]$LogPath = "C:\NetworkMaintenance\Logs",
    [string]$SafetyLevel = "Balanced",
    [switch]$DryRun,
    [switch]$DeepScan,
    [int]$TempAgeDays = 7
)

$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogFile = "$LogPath\SafeCleaning_$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force
    switch ($Level) {
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARN" { Write-Host $entry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        "ACTION" { Write-Host $entry -ForegroundColor Cyan }
        "HEADER" { Write-Host $entry -ForegroundColor Magenta }
        "DRYRUN" { Write-Host $entry -ForegroundColor DarkYellow }
        default { Write-Host $entry -ForegroundColor White }
    }
}

function Show-Banner {
    Write-Log "============================================" "HEADER"
    Write-Log "  Safe Cleaning Module v2 (SCE-Engine v3.0)" "HEADER"
    Write-Log "  Whitelist-Based | Zero-Trust | No Re-Download" "HEADER"
    Write-Log "============================================" "HEADER"
    Write-Log "Safety: $SafetyLevel | DryRun: $DryRun | TempAge: ${TempAgeDays}d" "HEADER"
    Write-Log ""
}

# Delegate to v3 engine for unified behavior
Show-Banner

$enterpriseConfig = "C:\NetworkMaintenance\Config\EnterpriseConfig.json"
if (Test-Path "C:\NetworkMaintenance\Scripts\Engines\SCE-Engine.ps1") {
    Write-Log "[DELEGATE] Calling SCE-Engine v3.0..." "ACTION"
    $params = @{
        ConfigPath = $enterpriseConfig
        SafetyLevel = $SafetyLevel
        TempAgeDays = $TempAgeDays
    }
    if ($DryRun) { $params.DryRun = $true }
    if ($DeepScan) { $params.DeepScan = $true }

    & "C:\NetworkMaintenance\Scripts\Engines\SCE-Engine.ps1" @params

    # Also copy results to v2 log location for compatibility
    $v3Results = "C:\NetworkMaintenance\Data\sce_results.json"
    if (Test-Path $v3Results) {
        Copy-Item $v3Results "C:\NetworkMaintenance\Data\safe_cleaning_results.json" -Force -ErrorAction SilentlyContinue
        Write-Log "[COMPAT] Results mirrored to safe_cleaning_results.json" "SUCCESS"
    }
} else {
    Write-Log "SCE-Engine not found at Engines/SCE-Engine.ps1" "ERROR"
    exit 1
}

Write-Log "" "HEADER"
Write-Log "  Safe Cleaning Complete" "HEADER"
Write-Log "============================================" "HEADER"

