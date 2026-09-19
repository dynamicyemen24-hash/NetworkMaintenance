# ====================================================================
# NetworkMaintenance-Pro v4.1 - BATT Engine (Deep Battery Diagnostics)
# ====================================================================
# Open Source: Battery Historian, BatteryInfoView, powercfg, ADB dumpsys
# Supports: Windows Laptop, Android, iOS (via libimobiledevice)
# Standards: IEEE 1625 | NIST 800-124
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$DeviceType = "Auto",
    [string]$TicketNo = "",
    [switch]$GenerateReport,
    [switch]$DeepBatteryReport
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "$DataPath\..\Logs\BATT_$(Get-Date -Format 'yyyyMMdd').log"

function Write-BATTLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} default {"White"} }
    Write-Host $entry -ForegroundColor $color
}

class BatteryAnalyzer {
    [hashtable] AnalyzeWindowsBattery() {
        $result = @{
            source = "Windows"
            design_capacity_mwh = 0
            full_charge_capacity_mwh = 0
            current_capacity_mwh = 0
            health_percent = 100
            cycle_count = 0
            voltage_mv = 0
            temperature_c = 25
            chemistry = "Unknown"
            status = "UNKNOWN"
            wear_level = 0
            issues = @()
            recommendations = @()
            open_source_tool = "powercfg /batteryreport + WMI"
        }
        try {
            # Method 1: WMI Win32_Battery
            $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($batt) {
                $result.chemistry = $batt.Chemistry
                $result.status = "DETECTED"
            }

            # Method 2: powercfg /batteryreport (open source concept: BatteryInfoView)
            $reportPath = "$env:TEMP\battery_report.html"
            try {
                $null = powercfg /batteryreport /output $reportPath 2>$null
                if (Test-Path $reportPath) {
                    $html = Get-Content $reportPath -Raw -ErrorAction SilentlyContinue
                    if ($html -match "Design Capacity.*?([0-9,]+)\s*mWh") { $result.design_capacity_mwh = [int]($Matches[1] -replace ",","") }
                    if ($html -match "Full Charge Capacity.*?([0-9,]+)\s*mWh") { $result.full_charge_capacity_mwh = [int]($Matches[1] -replace ",","") }
                    if ($result.design_capacity_mwh -gt 0) {
                        $result.health_percent = [math]::Round($result.full_charge_capacity_mwh / $result.design_capacity_mwh * 100, 1)
                        $result.wear_level = [math]::Round(100 - $result.health_percent, 1)
                    }
                    # Cycle count from report if available
                    if ($html -match "Cycle Count.*?([0-9]+)") { $result.cycle_count = [int]$Matches[1] }
                    Remove-Item $reportPath -Force -ErrorAction SilentlyContinue
                }
            } catch {}

            # Method 3: Get-CimInstance BatteryStaticData (if available - like OpenHardwareMonitor)
            try {
                $static = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($static -and $static.DesignedCapacity) {
                    $result.design_capacity_mwh = $static.DesignedCapacity
                    $result.full_charge_capacity_mwh = $static.FullChargedCapacity
                    if ($static.DesignedCapacity -gt 0) {
                        $result.health_percent = [math]::Round($static.FullChargedCapacity / $static.DesignedCapacity * 100, 1)
                    }
                }
                $full = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($full) { $result.full_charge_capacity_mwh = $full.FullChargedCapacity }
            } catch {}

            # Health classification (like CrystalDiskInfo for battery)
            if ($result.health_percent -ge 90) { $result.status = "EXCELLENT" }
            elseif ($result.health_percent -ge 80) { $result.status = "GOOD" }
            elseif ($result.health_percent -ge 60) { $result.status = "FAIR" }
            elseif ($result.health_percent -ge 40) { $result.status = "POOR" }
            else { $result.status = "CRITICAL" }

            if ($result.wear_level -gt 20) { $result.issues += "Battery wear high: $($result.wear_level)% (health $($result.health_percent)%)" }
            if ($result.cycle_count -gt 500) { $result.issues += "High cycle count: $($result.cycle_count) (rated 500)" }
            if ($result.health_percent -lt 80) { $result.recommendations += "Consider battery replacement - health below 80%" }
            if ($result.wear_level -gt 30) { $result.recommendations += "Battery significantly degraded - replacement recommended" }

            $result.open_source_tool = "powercfg + WMI BatteryStaticData (inspired by BatteryInfoView/Battery Historian)"
        } catch {
            $result.issues += $_.Exception.Message
        }
        return $result
    }

    [hashtable] AnalyzeAndroidBattery() {
        $result = @{
            source = "Android-ADB"
            level_percent = 0
            health = "Unknown"
            temperature_c = 0
            voltage_mv = 0
            cycle_count = 0
            technology = "Unknown"
            status = "UNKNOWN"
            health_percent = 100
            issues = @()
            recommendations = @()
            open_source_tool = "ADB dumpsys battery (like scrcpy/libimobiledevice)"
        }
        try {
            if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
                $result.issues += "ADB not found - install platform-tools (open source: https://developer.android.com/studio/releases/platform-tools)"
                return $result
            }
            $out = & adb shell dumpsys battery 2>$null | Out-String
            if (-not $out -or $out.Length -lt 50) {
                $result.issues += "No Android device connected or ADB unauthorized"
                return $result
            }
            if ($out -match "level:\s*(\d+)") { $result.level_percent = [int]$Matches[1] }
            if ($out -match "health:\s*(\d+)") {
                $h = [int]$Matches[1]
                $result.health = switch ($h) { 1 {"Unknown"} 2 {"Good"} 3 {"Overheat"} 4 {"Dead"} 5 {"Over voltage"} 6 {"Cold"} 7 {"Unspecified failure"} default {"Unknown"} }
            }
            if ($out -match "temperature:\s*(\d+)") { $result.temperature_c = [int]$Matches[1] / 10 }
            if ($out -match "voltage:\s*(\d+)") { $result.voltage_mv = [int]$Matches[1] }
            if ($out -match "technology:\s*(.+)") { $result.technology = $Matches[1].Trim() }
            # Cycle count via alternative method (requires root or dumpsys batterystats)
            try {
                $stats = & adb shell dumpsys batterystats 2>$null | Select-String "cycle" | Out-String
                if ($stats -match "(\d+)\s*cycle") { $result.cycle_count = [int]$Matches[1] }
            } catch {}
            # Estimate health from level vs voltage (simplified)
            if ($result.technology -eq "Li-ion" -and $result.voltage_mv -gt 0) {
                # Healthy Li-ion: 4.2V full, 3.7V nominal, 3.2V empty
                if ($result.voltage_mv -lt 3600 -and $result.level_percent -gt 30) {
                    $result.issues += "Voltage low for level ($($result.voltage_mv)mV at $($result.level_percent)%) - possible cell degradation"
                }
            }
            if ($result.temperature_c -gt 45) { $result.issues += "Battery temperature high: $($result.temperature_c)C" }
            if ($result.health -ne "Good" -and $result.health -ne "Unknown") { $result.issues += "Battery health: $($result.health)" }
            $result.status = if ($result.health -eq "Good" -and $result.temperature_c -lt 40) {"GOOD"} else {"FAIR"}
            $result.open_source_tool = "ADB dumpsys battery + batterystats (Battery Historian compatible)"
        } catch {
            $result.issues += $_.Exception.Message
        }
        return $result
    }

    [hashtable] EstimateIOSBattery() {
        # iOS via libimobiledevice concepts (ideviceinfo, idevicediagnostics)
        $result = @{
            source = "iOS-libimobiledevice"
            health_percent = 100
            cycle_count = 0
            status = "UNKNOWN"
            issues = @()
            recommendations = @()
            open_source_tool = "libimobiledevice (ideviceinfo/idevicediagnostics)"
            note = "Requires libimobiledevice + usbmuxd. Run: ideviceinfo -q com.apple.mobile.battery"
        }
        try {
            if (Get-Command ideviceinfo -ErrorAction SilentlyContinue) {
                $out = & ideviceinfo -q com.apple.mobile.battery 2>$null | Out-String
                if ($out -match "BatteryCurrentCapacity:\s*(\d+)") { $result.health_percent = [int]$Matches[1] }
                if ($out -match "BatteryIsCharging:\s*(\w+)") { $result.status = $Matches[1] }
            } else {
                $result.issues += "libimobiledevice not installed - iOS diagnostics requires: https://libimobiledevice.org/"
            }
        } catch {
            $result.issues += $_.Exception.Message
        }
        return $result
    }
}

function Invoke-BATTEngine {
    Write-BATTLog "========== BATT Engine v4.1 - Deep Battery Diagnostics ==========" "ACTION"
    Write-BATTLog "DeviceType: $DeviceType | Ticket: $TicketNo | Deep: $DeepBatteryReport" "INFO"

    $analyzer = [BatteryAnalyzer]::new()
    $results = @{
        engine = "BATT"
        version = "4.1"
        timestamp = $Timestamp
        device_type = $DeviceType
        analyses = @{}
        summary = @{}
    }

    if ($DeviceType -eq "Auto" -or $DeviceType -eq "Computer" -or $DeviceType -eq "Laptop") {
        Write-BATTLog "[BATT] Analyzing Windows battery (powercfg/WMI)..." "ACTION"
        $results.analyses.windows = $analyzer.AnalyzeWindowsBattery()
        $w = $results.analyses.windows
        Write-BATTLog "Windows Battery: $($w.health_percent)% health | Wear $($w.wear_level)% | Cycles $($w.cycle_count) | Status $($w.status)" $(if ($w.health_percent -ge 80) {"SUCCESS"} else {"WARN"})
    }

    if ($DeviceType -eq "Auto" -or $DeviceType -eq "Mobile") {
        Write-BATTLog "[BATT] Analyzing Android battery (ADB)..." "ACTION"
        $results.analyses.android = $analyzer.AnalyzeAndroidBattery()
        $a = $results.analyses.android
        if ($a.level_percent -gt 0) {
            Write-BATTLog "Android Battery: $($a.level_percent)% | Temp $($a.temperature_c)C | $($a.voltage_mv)mV | Health $($a.health)" "INFO"
        } else {
            Write-BATTLog "Android: $($a.issues -join ' | ')" "WARN"
        }

        Write-BATTLog "[BATT] Checking iOS battery (libimobiledevice)..." "ACTION"
        $results.analyses.ios = $analyzer.EstimateIOSBattery()
    }

    # Summary
    $allHealth = @()
    foreach ($k in $results.analyses.Keys) { if ($results.analyses[$k].health_percent -gt 0) { $allHealth += $results.analyses[$k].health_percent } }
    $avgHealth = if ($allHealth.Count -gt 0) { [math]::Round(($allHealth | Measure-Object -Average).Average, 1) } else { 100 }
    $results.summary = @{
        avg_health_percent = $avgHealth
        overall_status = if ($avgHealth -ge 85) {"EXCELLENT"} elseif ($avgHealth -ge 70) {"GOOD"} else {"NEEDS_REPLACEMENT"}
        recommendation = if ($avgHealth -lt 80) {"Battery replacement recommended"} else {"Battery OK"}
    }

    Write-BATTLog "BATT Summary: Avg Health $avgHealth% | $($results.summary.overall_status)" "SUCCESS"

    # Save
    $outPath = "$DataPath\batt_results.json"
    $results | ConvertTo-Json -Depth 10 | Set-Content $outPath -Force
    Write-BATTLog "Saved -> $outPath" "SUCCESS"

    # Also append to diagnostics_history
    $histPath = "$DataPath\diagnostics_history.json"
    $all = @(); if (Test-Path $histPath) { $all = Get-Content $histPath | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($all -isnot [Array]) { $all=@($all) } }
    $all += @{ diag_id=[Guid]::NewGuid().ToString(); ticket_no=$TicketNo; type="BATT"; health=$avgHealth; at=$Timestamp }
    $all | ConvertTo-Json -Depth 10 | Set-Content $histPath -Force

    return $results
}

Invoke-BATTEngine
