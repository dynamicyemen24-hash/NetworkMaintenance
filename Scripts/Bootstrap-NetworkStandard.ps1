# ============================================================================
#  Bootstrap-NetworkStandard.ps1  (run elevated)
#  One-shot: Apply standard -> Register watchdog/responder tasks -> verify.
# ============================================================================
Start-Transcript -Path "C:\NetworkMaintenance\Logs\Bootstrap-$(Get-Date -Format yyyyMMdd-HHmmss).log" -Append | Out-Null
Write-Host "================ NETWORK STANDARD BOOTSTRAP ================" -ForegroundColor Cyan
& "C:\NetworkMaintenance\Scripts\Apply-NetworkStandard.ps1"
& "C:\NetworkMaintenance\Scripts\Register-NetworkReliabilityTasks.ps1"
Stop-Transcript | Out-Null
Write-Host "Bootstrap finished." -ForegroundColor Green