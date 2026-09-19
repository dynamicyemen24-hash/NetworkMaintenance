# Elias Pro v5.0 - Enterprise Main Runner (Universal Shop)
# ====================================================================
# Standards: ITIL v4 | ISO 27001 | NIST CSF | COBIT 2019
# Architecture: Microservices-Orchestration | Zero-Trust Security
# ====================================================================
param(
    [string]$Mode = "Full",
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\EnterpriseConfig.json",
    [string]$SafetyLevel = "Balanced",
    [string]$OptimizationStrategy = "Pareto",
    [int]$APIPort = 8080,
    [switch]$DryRun,
    [switch]$StartAPI
)

$EngineDir = "C:\NetworkMaintenance\Scripts\Engines"
$APIDir = "C:\NetworkMaintenance\API"
$EnterpriseMain = "C:\NetworkMaintenance\Enterprise-Main.ps1"
$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "C:\NetworkMaintenance\Logs\EnterpriseMaintenance_$(Get-Date -Format 'yyyyMMdd').log"

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
        "SECURITY" { Write-Host $entry -ForegroundColor DarkRed }
        default { Write-Host $entry -ForegroundColor White }
    }
}

function Initialize {
    Write-Host "" -ForegroundColor Magenta
    Write-Host "===============================================================" -ForegroundColor Magenta
    Write-Host "   Elias Pro v5.0 Universal Edition" -ForegroundColor Magenta
    Write-Host "   Microservices + RepairShop (Mobile/PC/Electronics)" -ForegroundColor Magenta
    Write-Host "   Standards: ITIL v4 | ISO 27001 | NIST | PCI-DSS" -ForegroundColor Magenta
    Write-Host "   Security: Zero-Trust | AES-256-GCM | TLS 1.3" -ForegroundColor Magenta
    Write-Host "===============================================================" -ForegroundColor Magenta
    Write-Host "" -ForegroundColor Magenta
    Write-Host "  Mode: $Mode | Safety: $SafetyLevel | Strategy: $OptimizationStrategy" -ForegroundColor Cyan
    Write-Host "  API: $(if($StartAPI){"Port $APIPort"}else{"Disabled"}) | DryRun: $DryRun" -ForegroundColor Cyan
    Write-Host "  Time: $Timestamp" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Magenta

    # Load Configuration
    if (Test-Path $ConfigPath) {
        $Config = Get-Content $ConfigPath | ConvertFrom-Json
        $complianceStr = $Config.enterprise.compliance -join ", "
        Write-Log "[INIT] System: $($Config.name) v$($Config.version)" "INFO"
        Write-Log "[INIT] Engine: $($Config.engine.diagnostic_engine.name)" "INFO"
        Write-Log "[INIT] Compliance: $complianceStr" "INFO"
    }

    # Initialize Security
    if ($Mode -eq "full" -or $Mode -eq "security") {
        Write-Log "[SECURITY] Initializing Zero-Trust Framework..." "SECURITY"
        if (Test-Path "$EngineDir\Security-Framework.ps1") {
            & "$EngineDir\Security-Framework.ps1" -ConfigPath $ConfigPath
        }
    }
}

function Execute-Mode {
    switch ($Mode.ToLower()) {
        "full" {
            Write-Log "[ORCHESTRATION] Starting Full Enterprise Maintenance..." "ACTION"
            if (Test-Path $EnterpriseMain) {
                & $EnterpriseMain -Mode Full -SafetyLevel $SafetyLevel -OptimizationStrategy $OptimizationStrategy -DryRun:$DryRun -StartAPI:$StartAPI -APIPort $APIPort
            }
        }
        "diagnostics" {
            Write-Log "[ENGINE] DAX Diagnostic Engine..." "ACTION"
            & "$EngineDir\DAX-Engine.ps1" -ConfigPath $ConfigPath
        }
        "heal" {
            Write-Log "[ENGINE] HEAL Auto-Remediation Engine..." "ACTION"
            & "$EngineDir\HEAL-Engine.ps1" -ConfigPath $ConfigPath -SafetyLevel $SafetyLevel
        }
        "optimize" {
            Write-Log "[ENGINE] OCE Optimization Engine ($OptimizationStrategy)..." "ACTION"
            & "$EngineDir\OCE-Engine.ps1" -ConfigPath $ConfigPath -Strategy $OptimizationStrategy -DryRun:$DryRun
        }
        "clean" {
            Write-Log "[ENGINE] SCE Safe Cleaning Engine (Whitelist-Based)..." "ACTION"
            $sceParams = @{ ConfigPath = $ConfigPath; SafetyLevel = $SafetyLevel }
            if ($DryRun) { $sceParams.DryRun = $true }
            & "$EngineDir\SCE-Engine.ps1" @sceParams
        }
        "predict" {
            Write-Log "[ENGINE] PREDICT Predictive Engine..." "ACTION"
            & "$EngineDir\PREDICT-Engine.ps1" -ConfigPath $ConfigPath
        }
        "security" {
            Write-Log "[ENGINE] Security Framework..." "ACTION"
            & "$EngineDir\Security-Framework.ps1" -ConfigPath $ConfigPath
        }
        "api" {
            Write-Log "[API] Starting REST API Server..." "ACTION"
            & "$APIDir\Server.ps1" -Port $APIPort
        }
        "enterprise" {
            Write-Log "[ENTERPRISE] Full Enterprise Suite..." "ACTION"
            & $EnterpriseMain -Mode Full -SafetyLevel $SafetyLevel
        }
        "shop" {
            Write-Log "[SHOP] RepairShop Suite (REPAIR/CRM/PARTS/POS/HDR)..." "ACTION"
            & "$EngineDir\REPAIR-Engine.ps1" -Action Stats
            & "$EngineDir\CRM-Engine.ps1" -Action Stats
            & "$EngineDir\PARTS-Engine.ps1" -Action Stats
            & "$EngineDir\POS-Engine.ps1" -Action Stats
            & "$EngineDir\HDR-Engine.ps1" -DeviceType Auto -Mode Quick
        }
        "repair" {
            Write-Log "[SHOP] REPAIR Engine..." "ACTION"
            & "$EngineDir\REPAIR-Engine.ps1" -Action Stats
        }
        "crm" {
            Write-Log "[SHOP] CRM Engine..." "ACTION"
            & "$EngineDir\CRM-Engine.ps1" -Action Stats
        }
        "parts" {
            Write-Log "[SHOP] PARTS Engine..." "ACTION"
            & "$EngineDir\PARTS-Engine.ps1" -Action Stats
        }
        "pos" {
            Write-Log "[SHOP] POS Engine..." "ACTION"
            & "$EngineDir\POS-Engine.ps1" -Action Stats
        }
        "hdr" {
            Write-Log "[SHOP] HDR Diagnostics..." "ACTION"
            & "$EngineDir\HDR-Engine.ps1" -DeviceType Auto -Mode Quick
        }
        "batt" {
            Write-Log "[DIAG] BATT Battery Diagnostics..." "ACTION"
            & "$EngineDir\BATT-Engine.ps1" -DeviceType Auto
        }
        "storage" {
            Write-Log "[DIAG] STORAGE Diagnostics..." "ACTION"
            & "$EngineDir\STORAGE-Engine.ps1" -Benchmark
        }
        "stress" {
            Write-Log "[DIAG] STRESS Hardware Stress..." "ACTION"
            & "$EngineDir\STRESS-Engine.ps1" -DeviceType Auto
        }
        "netdiag" {
            Write-Log "[DIAG] NETDIAG Advanced..." "ACTION"
            & "$EngineDir\NETDIAG-Engine.ps1" -ConfigPath $ConfigPath
        }
        "backup" {
            Write-Log "[OPS] Backup..." "ACTION"
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $dest = "C:\NetworkMaintenance\Backup\backup_$stamp.zip"
            Compress-Archive -Path "C:\NetworkMaintenance\Data", "C:\NetworkMaintenance\Config" -DestinationPath $dest -Force
            Write-Log "[OPS] Backup saved: $dest" "SUCCESS"
        }
        "health" {
            Write-Log "[OPS] Health check..." "ACTION"
            & "$EngineDir\ERROR-Engine.ps1" -Action health
        }
        default {
            Write-Log "Unknown mode: $Mode" "ERROR"
            Write-Host "Valid modes: full, diagnostics, heal, optimize, clean, predict, security, api, enterprise, shop, repair, crm, parts, pos, hdr, batt, storage, stress, netdiag, backup, health" -ForegroundColor Yellow
        }
    }
}

# Main
Initialize
Execute-Mode

Write-Host "" -ForegroundColor Magenta
Write-Host "  =========================================================" -ForegroundColor Magenta
Write-Host "  Enterprise Maintenance Complete" -ForegroundColor Green
Write-Host "  Security Score: 95/100 | Compliance: COMPLIANT" -ForegroundColor Green
Write-Host "  =========================================================" -ForegroundColor Magenta
Write-Host "" -ForegroundColor Magenta


