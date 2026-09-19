# ====================================================================
# Device-DeepDiagnostics.ps1 — تشغيل التشخيص العميق وتسجيل لقطة
# PC (WMI/SMART/batteryreport) + Mobile (ADB)
# الناتج: Reports/device-snapshot.json + Data/device-history.json
# اختياري: -Schedule لجدولة لقطة كل N دقيقة كـ SYSTEM
# ====================================================================
param(
    [switch]$Schedule,
    [int]$IntervalMin = 30,
    [switch]$Quiet
)
$ErrorActionPreference = "Continue"
$Root = "C:\NetworkMaintenance"
$module = "$Root\API\Modules\Device-Diagnostics.ps1"

if (-not (Test-Path -LiteralPath $module)) {
    Write-Host "[ERROR] Module missing: $module" -ForegroundColor Red
    exit 1
}

. $module

$snap = Get-DeviceSnapshot
$out = "$Root\Reports\device-snapshot.json"
$json = ConvertTo-Json -InputObject $snap -Depth 8
[System.IO.File]::WriteAllText($out, $json, (New-Object System.Text.UTF8Encoding($false)))
Save-DevicePoint -Snapshot $snap

if (-not $Quiet) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  عمق التشخيص — لقطة $([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("  CPU : {0}%  ({1})  {2} نوى / {3} خيوط" -f $snap.summary.cpu_load, $snap.device.cpu, $snap.device.cores, $snap.device.threads)
    Write-Host ("  RAM : {0}% مستخدمة  ({1}GB محتلة / {2}GB)" -f $snap.summary.ram_pct, $snap.device.used_ram_gb, $snap.device.total_ram_gb)
    Write-Host ("  BATT: مستوى {0}% — صحة {1}%  ({2}mWh من {3}mWh تصميمية)" -f $snap.summary.battery_level_pct, $snap.summary.battery_health_pct, $snap.battery.full_mwh, $snap.battery.design_mwh)
    if ($snap.summary.max_disk_wear -ne $null) {
        Write-Host ("  DISK: عدّاد صحيح={0}  أقصى اهتراء {1}%  عدد الأقراص {2}" -f $snap.summary.disk_healthy, $snap.summary.max_disk_wear, @($snap.storage).Count)
    } else {
        Write-Host ("  DISK: عدّاد صحيح={0}  (عداد SMART يتطلب صلاحيات إدارية)  عدد الأقراص {1}" -f $snap.summary.disk_healthy, @($snap.storage).Count)
    }
    Write-Host ("  ADB : متوفر={0}  أجهزة متصلة={1}" -f $snap.summary.adb_available, $snap.summary.devices_count)
    Write-Host ("  NET : الحالة={0}  DNS={1}ms  فقدان WAN={2}%" -f $snap.summary.network_status, $snap.summary.dns_ms, $snap.network.wan_loss)
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "  Saved -> $out"
    Write-Host "  Hist  -> $Root\Data\device-history.json"
    Write-Host "========================================" -ForegroundColor Cyan
}

if ($Schedule) {
    $name = "NMS-DeviceSnapshot"
    $scriptPath = $MyInvocation.MyCommand.Path
    $taskArgs = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Quiet"
    $null = schtasks /Create /F /TN $name /SC MINUTE /MO $IntervalMin /RU SYSTEM /RL HIGHEST /TR $taskArgs 2>$null
    if ($LASTEXITCODE -eq 0) {
        if (-not $Quiet) { Write-Host "جدول زمني مسجّل: $name كل $IntervalMin دقيقة (صلاحية SYSTEM)" -ForegroundColor Green }
    } else {
        if (-not $Quiet) { Write-Host "[WARN] تعذر تسجيل الجدول — نفّذ بصلاحية إدارية أو أضف المهمة يدويًا" -ForegroundColor Yellow }
    }
}