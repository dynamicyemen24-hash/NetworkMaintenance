# ====================================================================
# NetworkMaintenance-Pro v4.1 - STORAGE Engine (Deep Storage Diagnostics)
# ====================================================================
# Open Source: smartmontools/smartctl, CrystalDiskInfo, HDDScan, TestDisk
# Supports: HDD, SSD, NVMe, eMMC, SD Card
# Standards: SMART, NVMe SMART, eMMC Health
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$TicketNo = "",
    [switch]$Benchmark,
    [switch]$DeepScan
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "$DataPath\..\Logs\STORAGE_$(Get-Date -Format 'yyyyMMdd').log"

function Write-STORAGELog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} default {"White"} }
    Write-Host $entry -ForegroundColor $color
}

class StorageAnalyzer {
    [hashtable] AnalyzePhysicalDisks() {
        $result = @{ disks=@(); summary=@{total=0; healthy=0; warning=0; failing=0}; open_source_tool="Get-PhysicalDisk + smartctl" }
        try {
            $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
            if (-not $disks) {
                # Fallback to WMI
                $disks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue
                foreach ($d in $disks) {
                    $entry = @{
                        device_id = $d.DeviceID
                        friendly_name = $d.Model
                        media_type = $d.MediaType
                        size_gb = [math]::Round($d.Size/1GB,2)
                        health_status = $d.Status
                        operational_status = $d.Status
                        smart_status = "UNKNOWN"
                        wear_level = 0
                        reallocated_sectors = 0
                        power_on_hours = 0
                        temperature_c = 35
                        issues = @()
                    }
                    # Try SMART via MSStorageDriver
                    try {
                        $smart = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue | Where-Object { $_.InstanceName -like "*$($d.PNPDeviceID.Substring(0,10))*" }
                        if ($smart) { $entry.smart_status = if ($smart.PredictFailure) {"FAILING"} else {"OK"} }
                    } catch {}
                    $result.disks += $entry
                }
            } else {
                foreach ($d in $disks) {
                    $entry = @{
                        device_id = $d.DeviceId
                        friendly_name = $d.FriendlyName
                        media_type = $d.MediaType
                        size_gb = [math]::Round($d.Size/1GB,2)
                        health_status = $d.HealthStatus
                        operational_status = $d.OperationalStatus
                        bus_type = $d.BusType
                        smart_status = "UNKNOWN"
                        wear_level = 0
                        temperature_c = 0
                        issues = @()
                    }
                    # NVMe wear level via SMART (if SSD/NVMe)
                    try {
                        $smartData = Get-StorageReliabilityCounter -PhysicalDisk $d -ErrorAction SilentlyContinue
                        if ($smartData) {
                            $entry.wear_level = $smartData.Wear
                            $entry.temperature_c = $smartData.Temperature
                            $entry.power_on_hours = $smartData.PowerOnHours
                            if ($smartData.ReadErrorsTotal -gt 0) { $entry.issues += "Read errors: $($smartData.ReadErrorsTotal)" }
                        }
                    } catch {}
                    # smartctl integration (open source)
                    $smartctl = Get-Command smartctl -ErrorAction SilentlyContinue
                    if ($smartctl) {
                        try {
                            $dev = $d.DeviceId -replace ".*\\\\","/dev/"
                            $out = & smartctl -a $dev 2>$null | Out-String
                            if ($out -match "Reallocated_Sector_Ct.*?(\d+)") { $entry.reallocated_sectors = [int]$Matches[1] }
                            if ($out -match "Wear_Leveling_Count.*?(\d+)") { $entry.wear_level = [int]$Matches[1] }
                            if ($out -match "Temperature_Celsius.*?(\d+)") { $entry.temperature_c = [int]$Matches[1] }
                            $entry.open_source_tool = "smartctl -a $dev"
                        } catch {}
                    }
                    $result.disks += $entry
                }
            }
            # Summary
            $result.summary.total = $result.disks.Count
            $result.summary.healthy = @($result.disks | Where-Object { $_.health_status -eq "Healthy" -or $_.health_status -eq "OK" }).Count
            $result.summary.warning = @($result.disks | Where-Object { $_.health_status -eq "Warning" }).Count
            $result.summary.failing = @($result.disks | Where-Object { $_.health_status -eq "Unhealthy" -or $_.smart_status -eq "FAILING" }).Count
            foreach ($disk in $result.disks) {
                if ($disk.reallocated_sectors -gt 10) { $disk.issues += "Reallocated sectors high: $($disk.reallocated_sectors)" }
                if ($disk.wear_level -gt 80) { $disk.issues += "Wear level critical: $($disk.wear_level)%" }
                if ($disk.temperature_c -gt 55) { $disk.issues += "Temperature high: $($disk.temperature_c)C" }
            }
        } catch {
            $result.error = $_.Exception.Message
        }
        return $result
    }

    [hashtable] AnalyzeLogicalDisks() {
        $result = @{ volumes=@(); summary=@{} }
        try {
            $vols = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
            foreach ($v in $vols) {
                $total = $v.Size; $free = $v.FreeSpace
                $usedPct = if ($total -gt 0) { [math]::Round(($total-$free)/$total*100,1)} else {0}
                $entry = @{
                    drive = $v.DeviceID
                    volume_name = $v.VolumeName
                    file_system = $v.FileSystem
                    total_gb = [math]::Round($total/1GB,2)
                    free_gb = [math]::Round($free/1GB,2)
                    used_gb = [math]::Round(($total-$free)/1GB,2)
                    used_percent = $usedPct
                    status = if ($usedPct -gt 90) {"CRITICAL"} elseif ($usedPct -gt 80) {"WARNING"} else {"OK"}
                    issues = @()
                }
                if ($usedPct -gt 90) { $entry.issues += "Disk $($v.DeviceID) almost full ($usedPct%)" }
                $result.volumes += $entry
            }
            $result.summary = @{
                total_volumes = $result.volumes.Count
                critical = @($result.volumes | Where-Object { $_.status -eq "CRITICAL" }).Count
            }
        } catch { $result.error = $_.Exception.Message }
        return $result
    }

    [hashtable] BenchmarkDisk([string]$Drive = "C:") {
        $result = @{ drive=$Drive; read_mbps=0; write_mbps=0; iops=0; status="UNKNOWN"; tool="fio / CrystalDiskMark concept" }
        try {
            # Simple benchmark: measure file copy performance (like CrystalDiskMark sequential)
            $testFile = "$env:TEMP\disk_bench_$([Guid]::NewGuid().ToString().Substring(0,6)).tmp"
            $sizeMB = 100
            $data = New-Object byte[] (1MB)
            (New-Object Random).NextBytes($data)
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $fs = [IO.File]::Create($testFile)
            for ($i=0; $i -lt $sizeMB; $i++) { $fs.Write($data,0,$data.Length) }
            $fs.Close()
            $sw.Stop()
            $writeMbps = [math]::Round($sizeMB / $sw.Elapsed.TotalSeconds,1)
            $result.write_mbps = $writeMbps

            $sw.Restart()
            $fs = [IO.File]::OpenRead($testFile)
            $buffer = New-Object byte[] (1MB)
            while ($fs.Read($buffer,0,$buffer.Length) -gt 0) {}
            $fs.Close()
            $sw.Stop()
            $readMbps = [math]::Round($sizeMB / $sw.Elapsed.TotalSeconds,1)
            $result.read_mbps = $readMbps
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue

            $result.status = if ($readMbps -gt 500) {"EXCELLENT"} elseif ($readMbps -gt 200) {"GOOD"} elseif ($readMbps -gt 80) {"FAIR"} else {"POOR"}
            $result.tool = "Sequential R/W benchmark (CrystalDiskMark-inspired, 100MB)"
        } catch {
            $result.error = $_.Exception.Message
        }
        return $result
    }

    [hashtable] CheckAndroidStorage() {
        $result = @{ source="Android-ADB"; internal_total_gb=0; internal_used_percent=0; emmc_health="Unknown"; issues=@(); tool="ADB + dumpsys" }
        try {
            if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
                $result.issues += "ADB not found"
                return $result
            }
            $out = & adb shell df /data 2>$null | Out-String
            if ($out -match "(\d+)%") { $result.internal_used_percent = [int]$Matches[1] }
            # eMMC health via /sys (requires root) - concept from HDDScan
            try {
                $health = & adb shell cat /sys/class/mmc_host/mmc0/mmc0:0001/life_time 2>$null | Out-String
                if ($health) { $result.emmc_health = $health.Trim() }
            } catch {}
            if ($result.internal_used_percent -gt 90) { $result.issues += "Internal storage almost full ($($result.internal_used_percent)%)" }
        } catch { $result.issues += $_.Exception.Message }
        return $result
    }
}

function Invoke-STORAGEEngine {
    Write-STORAGELog "========== STORAGE Engine v4.1 - Deep Storage Diagnostics ==========" "ACTION"
    Write-STORAGELog "Ticket: $TicketNo | Benchmark: $Benchmark | Deep: $DeepScan" "INFO"

    $analyzer = [StorageAnalyzer]::new()
    $results = @{
        engine = "STORAGE"
        version = "4.1"
        timestamp = $Timestamp
        ticket_no = $TicketNo
        physical = $null
        logical = $null
        benchmark = $null
        android = $null
        summary = @{}
    }

    Write-STORAGELog "[STORAGE] Analyzing physical disks (smartctl/Get-PhysicalDisk)..." "ACTION"
    $results.physical = $analyzer.AnalyzePhysicalDisks()
    Write-STORAGELog "Physical: $($results.physical.summary.total) disks | Healthy: $($results.physical.summary.healthy) | Failing: $($results.physical.summary.failing)" $(if ($results.physical.summary.failing -eq 0) {"SUCCESS"} else {"WARN"})

    Write-STORAGELog "[STORAGE] Analyzing logical volumes..." "ACTION"
    $results.logical = $analyzer.AnalyzeLogicalDisks()
    foreach ($vol in $results.logical.volumes) {
        if ($vol.status -ne "OK") { Write-STORAGELog "Volume $($vol.drive): $($vol.used_percent)% used ($($vol.status))" "WARN" }
    }

    if ($Benchmark) {
        Write-STORAGELog "[STORAGE] Running benchmark (CrystalDiskMark concept)..." "ACTION"
        $results.benchmark = $analyzer.BenchmarkDisk("C:")
        Write-STORAGELog "Benchmark C:: Read $($results.benchmark.read_mbps) MB/s | Write $($results.benchmark.write_mbps) MB/s ($($results.benchmark.status))" "INFO"
    }

    # Android if requested
    if (Get-Command adb -ErrorAction SilentlyContinue) {
        $adbDev = & adb devices 2>$null | Select-String "device$"
        if ($adbDev) {
            Write-STORAGELog "[STORAGE] Checking Android storage..." "ACTION"
            $results.android = $analyzer.CheckAndroidStorage()
        }
    }

    # Overall health
    $health = 100
    if ($results.physical.summary.failing -gt 0) { $health -= 40 }
    if ($results.physical.summary.warning -gt 0) { $health -= 15 }
    if ($results.logical.summary.critical -gt 0) { $health -= 20 }
    $results.summary = @{ health_score = [math]::Max(0,$health); status = if ($health -ge 85) {"EXCELLENT"} elseif ($health -ge 60) {"GOOD"} else {"CRITICAL"} }
    Write-STORAGELog "STORAGE Summary: Health $health/100 ($($results.summary.status))" "SUCCESS"

    $outPath = "$DataPath\storage_results.json"
    $results | ConvertTo-Json -Depth 12 | Set-Content $outPath -Force
    Write-STORAGELog "Saved -> $outPath" "SUCCESS"

    return $results
}

Invoke-STORAGEEngine
