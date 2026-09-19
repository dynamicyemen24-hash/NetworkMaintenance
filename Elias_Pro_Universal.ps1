#!/usr/bin/env pwsh
# ====================================================================
# Elias Pro Universal - Deep Diagnostic & Optimization Engine v6.0
# FixMaster Technology - Professional Edition
# ====================================================================
param(
    [switch]$AutoFix,
    [switch]$DeepScan,
    [switch]$Silent,
    [switch]$ExportReport,
    [switch]$ShareReport,
    [string]$SharePath = "",
    [string]$EmailTo = "",
    [switch]$DailyLog,
    [switch]$CleanupLogs
)

$ErrorActionPreference = "Continue"
$ScriptVersion = "6.0.0"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$LogPath = "C:\NetworkMaintenance\Logs"
$ReportDir = "C:\NetworkMaintenance\Reports"
$DailyLogDir = "$LogPath\Daily"
$ArchiveDir = "$LogPath\Archive"

foreach ($p in @($LogPath, $ReportDir, $DailyLogDir, $ArchiveDir)) {
    if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
}

$LogFile = "$LogPath\EliasPro_$Timestamp.log"
$DailyLogFile = "$DailyLogDir\$(Get-Date -Format 'yyyy-MM-dd').log"
$JsonReport = "$ReportDir\EliasPro_Report_$Timestamp.json"
$HtmlReport = "$ReportDir\EliasPro_Report_$Timestamp.html"
$TextReport = "$ReportDir\EliasPro_Report_$Timestamp.txt"

# Daily log entries buffer for efficiency
$script:LogBuffer = @()
$script:LogBufferMax = 50

function Write-EP {
    param([string]$Msg, [string]$Level = "INFO", [switch]$NoConsole)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $date = Get-Date -Format "yyyy-MM-dd"
    $entry = "[$ts] [$Level] $Msg"
    
    # Buffer for efficiency
    $script:LogBuffer += $entry
    if ($script:LogBuffer.Count -ge $script:LogBufferMax) {
        Flush-LogBuffer
    }
    
    # Also write to daily log
    Add-Content -Path $DailyLogFile -Value $entry -Force -ErrorAction SilentlyContinue
    
    if (-not $NoConsole) {
        $clr = switch ($Level) { 
            "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} 
            "ACTION" {"Cyan"} "DEEP" {"Magenta"} "VULN" {"DarkRed"} 
            "METRIC" {"Blue"} default {"White"} 
        }
        Write-Host $entry -ForegroundColor $clr
    }
}

function Flush-LogBuffer {
    if ($script:LogBuffer.Count -gt 0) {
        Add-Content -Path $LogFile -Value ($script:LogBuffer -join "`n") -Force -ErrorAction SilentlyContinue
        $script:LogBuffer = @()
    }
}

function Get-DailyLogSummary {
    param([string]$Date = (Get-Date -Format "yyyy-MM-dd"))
    $logFile = "$DailyLogDir\$Date.log"
    if (-not (Test-Path $logFile)) { return $null }
    
    $content = Get-Content $logFile -ErrorAction SilentlyContinue
    $summary = [ordered]@{
        date = $Date
        total_entries = $content.Count
        errors = ($content | Where-Object { $_ -match "\[ERROR\]" }).Count
        warnings = ($content | Where-Object { $_ -match "\[WARN\]" }).Count
        successes = ($content | Where-Object { $_ -match "\[SUCCESS\]" }).Count
        vulnerabilities = ($content | Where-Object { $_ -match "\[VULN\]" }).Count
        file_size_kb = [math]::Round((Get-Item $logFile).Length/1KB, 1)
    }
    return $summary
}

function Invoke-LogRotation {
    param([int]$KeepDays = 30)
    $cutoff = (Get-Date).AddDays(-$KeepDays)
    $oldLogs = Get-ChildItem $LogPath -Filter "EliasPro_*.log" | Where-Object { $_.CreationTime -lt $cutoff }
    $moved = 0
    foreach ($log in $oldLogs) {
        Move-Item $log.FullName -Destination $ArchiveDir -Force -ErrorAction SilentlyContinue
        $moved++
    }
    if ($moved -gt 0) { Write-EP "Rotated $moved old log files to archive" "INFO" }
    
    # Compress old daily logs
    $oldDaily = Get-ChildItem $DailyLogDir -Filter "*.log" | Where-Object { $_.CreationTime -lt $cutoff }
    foreach ($d in $oldDaily) {
        Remove-Item $d.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Load Elias Pro Database Module
$modulePath = "C:\NetworkMaintenance\Modules\EliasDB_Module.ps1"
if (Test-Path $modulePath) {
    . $modulePath
    Initialize-EliasDB -DatabaseName "elias_pro"
    New-EliasCollection -DatabaseName "elias_pro" -CollectionName "diagnostics"
    New-EliasCollection -DatabaseName "elias_pro" -CollectionName "daily_logs"
    Write-EP "Database module loaded" "INFO"
}

# Log rotation on startup
Invoke-LogRotation -KeepDays 30

function Show-Banner {
    Write-Host ""
    Write-Host "  ========================================================" -ForegroundColor Cyan
    Write-Host "            ELIAS PRO Universal Deep Diagnostic           " -ForegroundColor Yellow
    Write-Host "              Version $ScriptVersion - FixMaster Technology       " -ForegroundColor White
    Write-Host "  ========================================================" -ForegroundColor Cyan
    Write-Host ""
    if ($IsAdmin) { Write-Host "  [ADMIN] Full hardware access enabled" -ForegroundColor Green }
    else { Write-Host "  [USER] Limited. Run as Admin for full diagnostics." -ForegroundColor Yellow }
    Write-Host ""
}

# MODULE 1: Deep System Information
function Get-DeepSystemInfo {
    Write-EP "Deep System Information" "DEEP"
    $info = [ordered]@{}
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1

    $info.os = "$($os.Caption) Build $($os.BuildNumber)"
    $info.cpu = $cpu.Name
    $info.cpu_cores = "$($cpu.NumberOfCores)C/$($cpu.NumberOfLogicalProcessors)L"
    $info.gpu = $gpu.Name
    $info.model = $cs.Model
    $info.total_ram_gb = [math]::Round($cs.TotalPhysicalMemory/1GB, 1)
    $info.uptime_h = if ($os.LastBootUpTime) { [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1) } else { 0 }

    Write-Host "  OS:       $($info.os)" -ForegroundColor White
    Write-Host "  CPU:      $($info.cpu)" -ForegroundColor White
    Write-Host "  Cores:    $($info.cpu_cores)" -ForegroundColor White
    Write-Host "  GPU:      $($info.gpu)" -ForegroundColor White
    Write-Host "  RAM:      $($info.total_ram_gb) GB" -ForegroundColor White
    Write-Host "  Uptime:   $($info.uptime_h) hours" -ForegroundColor White
    Write-Host "  Model:    $($info.model)" -ForegroundColor Gray
    return $info
}

# MODULE 2: CPU Deep Evaluation
function Invoke-CPUDiag {
    Write-EP "CPU Deep Evaluation" "DEEP"
    $load = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).LoadPercentage
    $temp = "N/A"
    if ($IsAdmin) {
        try {
            $mbs = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($mbs) { $temp = "$([math]::Round(($mbs.CurrentTemperature - 2732) / 10, 1)) C" }
        } catch {}
    }
    $score = 100; $issues = @()
    if ($load -gt 90) { $score -= 40; $issues += "CPU load critical: $load%" }
    elseif ($load -gt 70) { $score -= 20; $issues += "CPU load high: $load%" }
    if ($temp -ne "N/A") {
        $tv = [double]($temp -replace " C","")
        if ($tv -gt 90) { $score -= 30; $issues += "CPU temp critical: $temp" }
        elseif ($tv -gt 75) { $score -= 15; $issues += "CPU temp high: $temp" }
    }
    $rating = if ($score -ge 85) {"EXCELLENT"} elseif ($score -ge 70) {"GOOD"} elseif ($score -ge 50) {"FAIR"} else {"POOR"}
    Write-Host "  Load:  $load%" -ForegroundColor $(if ($load -gt 80){"Red"} elseif ($load -gt 60){"Yellow"} else {"Green"})
    Write-Host "  Temp:  $temp" -ForegroundColor White
    Write-Host "  Score: $score/100 ($rating)" -ForegroundColor $(if ($score -ge 70){"Green"} elseif ($score -ge 50){"Yellow"} else {"Red"})
    foreach ($i in $issues) { Write-EP "  CPU: $i" "WARN" }
    return @{ score=$score; rating=$rating; load=$load; temp=$temp; issues=$issues }
}

# MODULE 3: RAM Deep Evaluation
function Invoke-RAMDiag {
    Write-EP "RAM Deep Evaluation" "DEEP"
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $modules = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $totalGB = [math]::Round($cs.TotalPhysicalMemory/1GB, 1)
    $freeGB = [math]::Round($os.FreePhysicalMemory/1KB/1024, 1)
    $usedPct = [math]::Round(($totalGB - $freeGB) / $totalGB * 100, 1)
    Write-Host "  Total:   $totalGB GB" -ForegroundColor White
    Write-Host "  Used:    $usedPct%" -ForegroundColor $(if ($usedPct -gt 85){"Red"} elseif ($usedPct -gt 70){"Yellow"} else {"Green"})
    Write-Host "  Free:    $freeGB GB" -ForegroundColor White
    Write-Host "  Modules: $($modules.Count)" -ForegroundColor White
    foreach ($m in $modules) {
        $mGB = [math]::Round($m.Capacity/1GB, 0)
        Write-Host "    [$mGB GB $($m.Speed) MHz] $($m.PartNumber.Trim())" -ForegroundColor Gray
    }
    $score = 100; $issues = @()
    if ($usedPct -gt 90) { $score -= 35; $issues += "RAM critical: $usedPct%" }
    elseif ($usedPct -gt 80) { $score -= 15; $issues += "RAM high: $usedPct%" }
    if ($totalGB -lt 4) { $score -= 20; $issues += "Low RAM: $totalGB GB" }
    $rating = if ($score -ge 85) {"EXCELLENT"} elseif ($score -ge 70) {"GOOD"} elseif ($score -ge 50) {"FAIR"} else {"POOR"}
    Write-Host "  Score:   $score/100 ($rating)" -ForegroundColor $(if ($score -ge 70){"Green"} elseif ($score -ge 50){"Yellow"} else {"Red"})
    foreach ($i in $issues) { Write-EP "  RAM: $i" "WARN" }
    return @{ score=$score; rating=$rating; total_gb=$totalGB; used_pct=$usedPct; issues=$issues }
}

# MODULE 4: Disk and Storage
function Invoke-DiskDiag {
    Write-EP "Storage Deep Evaluation" "DEEP"
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    $physDisks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue
    $results = @()
    foreach ($d in $drives) {
        $totalGB = [math]::Round($d.Size/1GB, 1)
        $freeGB = [math]::Round($d.FreeSpace/1GB, 1)
        $usedPct = if ($d.Size -gt 0) { [math]::Round(($d.Size - $d.FreeSpace) / $d.Size * 100, 1) } else { 0 }
        Write-Host "  $($d.DeviceID) $totalGB GB total, $freeGB GB free ($usedPct%)" -ForegroundColor $(if ($usedPct -gt 90){"Red"} elseif ($usedPct -gt 80){"Yellow"} else {"Green"})
        $score = 100; $issues = @()
        if ($usedPct -gt 95) { $score -= 40; $issues += "Drive $($d.DeviceID) full" }
        elseif ($usedPct -gt 90) { $score -= 20; $issues += "Drive $($d.DeviceID) low" }
        $results += @{ letter=$d.DeviceID; total_gb=$totalGB; free_gb=$freeGB; used_pct=$usedPct; score=$score; issues=$issues }
    }
    foreach ($pd in $physDisks) {
        Write-Host "  Physical: $($pd.Model) ($([math]::Round($pd.Size/1GB,1)) GB)" -ForegroundColor Gray
    }
    if ($IsAdmin) {
        try {
            $smart = Get-CimInstance -Namespace root/wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue
            if ($smart) {
                foreach ($s in $smart) {
                    if ($s.PredictFailure) { Write-EP "SMART ALERT: Drive FAILING!" "VULN" }
                    else { Write-EP "SMART: All drives OK" "SUCCESS" }
                }
            }
        } catch {}
    }
    return $results
}

# MODULE 5: Battery Deep Evaluation
function Invoke-BatteryDiag {
    Write-EP "Battery Deep Evaluation" "DEEP"
    $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $batt) {
        Write-Host "  No battery detected (Desktop)" -ForegroundColor Yellow
        return @{ detected=$false; score=100; issues=@() }
    }
    $health = $batt.EstimatedChargeRemaining
    $statusText = switch ($batt.BatteryStatus) { 1{"Discharging"} 2{"AC Connected"} 3{"Fully Charged"} 4{"Low"} 5{"Critical"} 6{"Charging"} default{"Unknown"} }
    $score = 100; $issues = @()
    if ($health -lt 20) { $score -= 40; $issues += "Battery critical: $health%" }
    elseif ($health -lt 50) { $score -= 20; $issues += "Battery low: $health%" }
    elseif ($health -lt 80) { $score -= 10; $issues += "Battery wear: $health%" }
    Write-Host "  Charge:  $health%" -ForegroundColor $(if ($health -lt 30){"Red"} elseif ($health -lt 60){"Yellow"} else {"Green"})
    Write-Host "  Status:  $statusText" -ForegroundColor White
    $rating = if ($score -ge 85) {"EXCELLENT"} elseif ($score -ge 70) {"GOOD"} elseif ($score -ge 50) {"FAIR"} else {"POOR"}
    Write-Host "  Score:   $score/100 ($rating)" -ForegroundColor $(if ($score -ge 70){"Green"} elseif ($score -ge 50){"Yellow"} else {"Red"})
    foreach ($i in $issues) { Write-EP "  Battery: $i" "WARN" }
    return @{ detected=$true; score=$score; health=$health; status=$statusText; issues=$issues }
}

# MODULE 6: Network Deep Evaluation
function Invoke-NetworkDiag {
    Write-EP "Network Deep Evaluation" "DEEP"
    $score = 100; $issues = @()

    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    if ($adapters) {
        foreach ($a in $adapters) {
            Write-Host "  Adapter: $($a.Name) ($($a.InterfaceDescription))" -ForegroundColor White
            Write-Host "    Status: $($a.Status), Speed: $($a.LinkSpeed)" -ForegroundColor Gray
        }
    } else {
        $score -= 20; $issues += "No active network adapters"
        Write-EP "No active network adapters found" "WARN"
    }

    $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -ne "127.0.0.1" }
    if ($addrs) {
        foreach ($a in $addrs) {
            Write-Host "  IP: $($a.IPAddress) ($($a.InterfaceAlias))" -ForegroundColor White
        }
    } else {
        $score -= 15; $issues += "No IPv4 address assigned"
    }

    $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses }
    if ($dns) {
        foreach ($d in $dns) {
            Write-Host "  DNS: $($d.ServerAddresses -join ', ') ($($d.InterfaceAlias))" -ForegroundColor White
        }
    } else {
        $score -= 10; $issues += "No DNS servers configured"
    }

    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-EP "Internet connectivity: OK" "SUCCESS"
    } else {
        $score -= 25; $issues += "No internet connectivity"
        Write-EP "No internet connectivity" "ERROR"
    }

    $rating = if ($score -ge 85) {"EXCELLENT"} elseif ($score -ge 70) {"GOOD"} elseif ($score -ge 50) {"FAIR"} else {"POOR"}
    Write-Host "  Score: $score/100 ($rating)" -ForegroundColor $(if ($score -ge 70){"Green"} elseif ($score -ge 50){"Yellow"} else {"Red"})
    foreach ($i in $issues) { Write-EP "  Network: $i" "WARN" }
    return @{ score=$score; rating=$rating; issues=$issues }
}

# MODULE 7: Temp and Junk Cleanup
function Invoke-TempCleanup {
    Write-EP "Temp and Junk Cleanup" "DEEP"
    $tempPaths = @(
        $env:TEMP,
        "$env:LOCALAPPDATA\Temp",
        "$env:WINDIR\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
    )
    $totalBytes = 0
    foreach ($tp in $tempPaths) {
        if (Test-Path $tp) {
            $items = Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue
            $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($size) {
                $totalBytes += $size
                $mb = [math]::Round($size / 1MB, 2)
                Write-Host "  $tp : $mb MB" -ForegroundColor White
            }
        }
    }
    $totalMB = [math]::Round($totalBytes / 1MB, 2)
    $freedBytes = 0

    if ($AutoFix -and $totalBytes -gt 0) {
        Write-EP "Cleaning temporary files..." "ACTION"
        foreach ($tp in $tempPaths) {
            if (Test-Path $tp) {
                Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        $freedBytes = $totalBytes
        Write-EP "Cleaned $totalMB MB of temp files" "SUCCESS"
    } else {
        Write-EP "Temp files: $totalMB MB (use -AutoFix to clean)" "INFO"
    }

    return @{ total_mb=$totalMB; freed_bytes=$freedBytes; temp_paths=$tempPaths }
}

# MODULE 8: Broken Updates and Pending Fixes
function Invoke-UpdateCheck {
    Write-EP "Broken Updates and Pending Fixes" "DEEP"
    $issues = @()

    $hotfixes = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object -Property InstalledOn -Descending -ErrorAction SilentlyContinue | Select-Object -First 3
    if ($hotfixes) {
        Write-Host "  Recent Hotfixes:" -ForegroundColor White
        foreach ($hf in $hotfixes) {
            $date = if ($hf.InstalledOn) { $hf.InstalledOn.ToString("yyyy-MM-dd") } else { "N/A" }
            Write-Host "    $($hf.HotFixID) - $($hf.Description) ($date)" -ForegroundColor Gray
        }
    } else {
        Write-EP "No hotfixes found" "WARN"
    }

    $pending = 0
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $pendingResult = $searcher.Search("IsInstalled=0 AND IsHidden=0")
        $pending = $pendingResult.Updates.Count
        if ($pending -gt 0) {
            $issues += "$pending pending Windows Updates"
            Write-Host "  Pending Updates: $pending" -ForegroundColor Yellow
        } else {
            Write-EP "No pending Windows Updates" "SUCCESS"
        }
    } catch {
        Write-EP "Cannot check Windows Updates: $_" "WARN"
    }

    $cbsReboot = $false
    try {
        $cbsKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
        if ($cbsKey) { $cbsReboot = $true }
    } catch {}
    if ($cbsReboot) { $issues += "CBS Reboot Pending"; Write-EP "CBS Reboot Pending" "WARN" }

    $wuReboot = $false
    try {
        $wuKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
        if ($wuKey) { $wuReboot = $true }
    } catch {}
    if ($wuReboot) { $issues += "Windows Update Reboot Required"; Write-EP "Windows Update Reboot Required" "WARN" }

    return @{ hotfixes=$hotfixes.Count; pending=$pending; cbs_reboot=$cbsReboot; wu_reboot=$wuReboot; issues=$issues }
}

# MODULE 9: Security and Vulnerability Scan
function Invoke-SecurityScan {
    Write-EP "Security and Vulnerability Scan" "DEEP"
    $vulns = @()

    $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defender) {
        if (-not $defender.RealTimeProtectionEnabled) { $vulns += "Real-Time Protection OFF"; Write-EP "Real-Time Protection OFF" "VULN" }
        else { Write-EP "Real-Time Protection: ON" "SUCCESS" }
        if (-not $defender.AntivirusEnabled) { $vulns += "Antivirus OFF"; Write-EP "Antivirus OFF" "VULN" }
        else { Write-EP "Antivirus: ON" "SUCCESS" }
        if ($defender.QuickScanEndTime) {
            $scanAge = (Get-Date) - $defender.QuickScanEndTime
            if ($scanAge.TotalDays -gt 7) { $vulns += "Quick scan outdated: $([math]::Round($scanAge.TotalDays,0)) days ago" }
        }
    } else {
        $vulns += "Cannot retrieve Windows Defender status"
    }

    $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    if ($profiles) {
        foreach ($p in $profiles) {
            if (-not $p.Enabled) { $vulns += "Firewall $($p.Name) OFF"; Write-EP "Firewall $($p.Name) OFF" "VULN" }
            else { Write-EP "Firewall $($p.Name): ON" "SUCCESS" }
        }
    }

    $smbv1 = Get-SmbServerConfiguration -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnableSMB1Protocol -ErrorAction SilentlyContinue
    if ($smbv1) { $vulns += "SMBv1 enabled (security risk)"; Write-EP "SMBv1 enabled" "VULN" }
    else { Write-EP "SMBv1: Disabled" "SUCCESS" }

    try {
        $rdp = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
        if ($rdp.fDenyTSConnections -eq 0) { $vulns += "RDP enabled"; Write-EP "RDP: Enabled" "WARN" }
        else { Write-EP "RDP: Disabled" "SUCCESS" }
    } catch {}

    try {
        $autoLogon = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
        if ($autoLogon.AutoAdminLogon -eq "1") { $vulns += "Auto-Login enabled (security risk)"; Write-EP "Auto-Login enabled" "VULN" }
        else { Write-EP "Auto-Login: Disabled" "SUCCESS" }
    } catch {}

    Write-Host "  Vulnerabilities found: $($vulns.Count)" -ForegroundColor $(if ($vulns.Count -eq 0){"Green"} elseif ($vulns.Count -le 2){"Yellow"} else {"Red"})
    return @{ vulns=$vulns; vuln_count=$vulns.Count }
}

# MODULE 10: Gap and Compliance Check
function Invoke-GapCheck {
    Write-EP "Gap and Compliance Check" "DEEP"
    $gaps = @()

    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $build = [int]$os.BuildNumber
    if ($build -lt 22000) { $gaps += "Windows 10 detected (Build $build) - not on Windows 11"; Write-EP "OS: Windows 10 (Build $build)" "WARN" }
    else { Write-EP "OS: Windows 11+ (Build $build)" "SUCCESS" }

    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    if ($ramGB -lt 8) { $gaps += "RAM below 8GB: $ramGB GB"; Write-EP "RAM: $ramGB GB (below 8GB)" "WARN" }
    else { Write-EP "RAM: $ramGB GB OK" "SUCCESS" }

    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3 AND DeviceID='C:'" -ErrorAction SilentlyContinue
    if ($disk) {
        $freePct = if ($disk.Size -gt 0) { [math]::Round($disk.FreeSpace / $disk.Size * 100, 1) } else { 0 }
        if ($freePct -lt 15) { $gaps += "C: drive low: $freePct% free"; Write-EP "C: Drive: $freePct% free (below 15%)" "WARN" }
        else { Write-EP "C: Drive: $freePct% free OK" "SUCCESS" }
    }

    $criticalServices = @("WinDefend", "MpsSvc", "wuauserv")
    foreach ($svc in $criticalServices) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s -and $s.Status -ne "Running") { $gaps += "Service ${svc} not running: $($s.Status)"; Write-EP "Service ${svc}: $($s.Status)" "WARN" }
        else { Write-EP "Service ${svc}: Running" "SUCCESS" }
    }

    if ($os.LastBootUpTime) {
        $uptimeDays = ((Get-Date) - $os.LastBootUpTime).TotalDays
        if ($uptimeDays -gt 7) { $gaps += "Uptime over 7 days: $([math]::Round($uptimeDays,1)) days"; Write-EP "Uptime: $([math]::Round($uptimeDays,1)) days (consider restart)" "WARN" }
        else { Write-EP "Uptime: $([math]::Round($uptimeDays,1)) days OK" "SUCCESS" }
    }

    return @{ gaps=$gaps; gap_count=$gaps.Count }
}

# MODULE 11: GPU Evaluation
function Invoke-GPUDiag {
    Write-EP "GPU Evaluation" "DEEP"
    $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    $results = @()

    foreach ($gpu in $gpus) {
        $vramMB = [math]::Round($gpu.AdapterRAM / 1MB, 0)
        $score = 100; $issues = @()
        if ($gpu.Status -ne "OK") { $score -= 30; $issues += "GPU status: $($gpu.Status)" }
        if ($vramMB -lt 1024) { $score -= 20; $issues += "Low VRAM: $vramMB MB" }
        Write-Host "  GPU: $($gpu.Name)" -ForegroundColor White
        Write-Host "    VRAM: $vramMB MB, Driver: $($gpu.DriverVersion), Status: $($gpu.Status)" -ForegroundColor Gray
        $rating = if ($score -ge 85) {"EXCELLENT"} elseif ($score -ge 70) {"GOOD"} elseif ($score -ge 50) {"FAIR"} else {"POOR"}
        Write-Host "    Score: $score/100 ($rating)" -ForegroundColor $(if ($score -ge 70){"Green"} elseif ($score -ge 50){"Yellow"} else {"Red"})
        $results += @{ name=$gpu.Name; vram_mb=$vramMB; driver=$gpu.DriverVersion; status=$gpu.Status; score=$score; issues=$issues }
    }
    return $results
}

# MODULE 12: Performance Optimization
function Invoke-PerformanceOptimize {
    Write-EP "Performance Optimization" "DEEP"
    if (-not $IsAdmin) {
        Write-EP "Admin required for optimization" "ERROR"
        return @{ optimized=0; issues=@("Admin required") }
    }
    $optimized = 0

    try {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-EP "DNS cache flushed" "SUCCESS"
        $optimized++
    } catch { Write-EP "Failed to flush DNS: $_" "WARN" }

    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $dlPath = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path $dlPath) {
            Get-ChildItem -Path $dlPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-EP "Windows Update cache cleared" "SUCCESS"
            $optimized++
        }
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    } catch { Write-EP "Failed to reset WU cache: $_" "WARN" }

    try {
        $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        if (Test-Path $thumbPath) {
            Get-ChildItem -Path $thumbPath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-EP "Thumbnail cache cleared" "SUCCESS"
            $optimized++
        }
    } catch { Write-EP "Failed to clear thumbnails: $_" "WARN" }

    try {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Write-EP "High Performance power plan activated" "SUCCESS"
        $optimized++
    } catch { Write-EP "Failed to set power plan: $_" "WARN" }

    Write-Host "  Optimizations applied: $optimized" -ForegroundColor Green
    return @{ optimized=$optimized }
}

# MODULE 13: Process and Service Health
function Invoke-ProcessDiag {
    Write-EP "Process and Service Health" "DEEP"
    $issues = @()

    $heavyProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.CPU -gt 100 } | Sort-Object -Property CPU -Descending | Select-Object -First 5
    if ($heavyProcesses) {
        Write-Host "  Top CPU-Heavy Processes:" -ForegroundColor Yellow
        foreach ($p in $heavyProcesses) {
            $cpuSec = [math]::Round($p.CPU, 1)
            Write-Host "    $($p.ProcessName) (PID $($p.Id)): CPU $cpuSec s" -ForegroundColor Red
        }
    } else {
        Write-EP "No CPU-heavy processes detected" "SUCCESS"
    }

    $failedServices = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Failed" -or $_.StartType -eq "Automatic" -and $_.Status -ne "Running" }
    if ($failedServices) {
        foreach ($s in $failedServices) {
            $issues += "Service $($s.Name) not running (Automatic)"
            Write-EP "Service $($s.Name): $($s.Status)" "WARN"
        }
    }

    $importantServices = @("SysMain", "WSearch", "BITS")
    foreach ($svc in $importantServices) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            $color = if ($s.Status -eq "Running") { "Green" } else { "Yellow" }
            Write-Host "  $svc : $($s.Status)" -ForegroundColor $color
            if ($s.Status -ne "Running") { $issues += "Important service ${svc}: $($s.Status)" }
        }
    }

    return @{ heavy_processes=$heavyProcesses.Count; failed_services=$failedServices.Count; issues=$issues }
}

# MODULE 14: Overall Score + Menu + Main Execution
function Get-OverallScore {
    param(
        [int]$CpuScore = 100,
        [int]$RamScore = 100,
        [array]$DiskScores = @(),
        [int]$BattScore = 100,
        [int]$NetScore = 100,
        [int]$SecCount = 0,
        [int]$GapCount = 0
    )
    $scores = @($CpuScore, $RamScore, $BattScore, $NetScore)
    foreach ($ds in $DiskScores) { $scores += $ds }
    $avg = ($scores | Measure-Object -Average).Average
    $penalty = ($SecCount * 5) + ($GapCount * 3)
    $final = [math]::Max(0, [math]::Round($avg - $penalty, 0))
    $grade = if ($final -ge 85) {"A"} elseif ($final -ge 70) {"B"} elseif ($final -ge 50) {"C"} elseif ($final -ge 35) {"D"} else {"F"}
    $rating = if ($final -ge 85) {"EXCELLENT"} elseif ($final -ge 70) {"GOOD"} elseif ($final -ge 50) {"FAIR"} elseif ($final -ge 35) {"POOR"} else {"CRITICAL"}
    return @{ score=$final; grade=$grade; rating=$rating; penalty=$penalty }
}

function Write-ColorBar {
    param([int]$Score, [int]$MaxScore = 100, [int]$Width = 30)
    $filled = [math]::Round($Score / $MaxScore * $Width)
    $empty = $Width - $filled
    $color = if ($Score -ge 80) {"Green"} elseif ($Score -ge 50) {"Yellow"} else {"Red"}
    $bar = ("█" * $filled) + ("░" * $empty)
    Write-Host "  [$bar] $Score/$MaxScore" -ForegroundColor $color
}

function Show-Menu {
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "         ELIAS PRO Universal Menu        " -ForegroundColor Yellow
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "  [1]  System Information" -ForegroundColor White
    Write-Host "  [2]  CPU Evaluation" -ForegroundColor White
    Write-Host "  [3]  RAM Evaluation" -ForegroundColor White
    Write-Host "  [4]  Disk & Storage" -ForegroundColor White
    Write-Host "  [5]  Battery Evaluation" -ForegroundColor White
    Write-Host "  [6]  Network Deep Scan" -ForegroundColor White
    Write-Host "  [7]  Temp & Junk Cleanup" -ForegroundColor White
    Write-Host "  [8]  Update Check" -ForegroundColor White
    Write-Host "  [9]  Security & Vulnerability" -ForegroundColor White
    Write-Host "  [10] Gap & Compliance" -ForegroundColor White
    Write-Host "  [11] GPU Evaluation" -ForegroundColor White
    Write-Host "  [12] Performance Optimize" -ForegroundColor White
    Write-Host "  [13] Process & Service Health" -ForegroundColor White
    Write-Host "  [14] FULL DIAGNOSTIC (All Modules)" -ForegroundColor Green
    Write-Host "  ----" -ForegroundColor Gray
    Write-Host "  [15] View Diagnostic History" -ForegroundColor Cyan
    Write-Host "  [16] View System Trend" -ForegroundColor Cyan
    Write-Host "  [17] Export Report (JSON/HTML/CSV)" -ForegroundColor Cyan
    Write-Host "  [18] Share Report" -ForegroundColor Cyan
    Write-Host "  [19] View Database Stats" -ForegroundColor Cyan
    Write-Host "  ----" -ForegroundColor Gray
    Write-Host "  [0]  Exit" -ForegroundColor Red
    Write-Host "  ========================================" -ForegroundColor Cyan
}

function Start-FullDiagnostic {
    Write-EP "Starting Full Diagnostic..." "ACTION"
    $sysInfo = Get-DeepSystemInfo
    $cpuResult = Invoke-CPUDiag
    $ramResult = Invoke-RAMDiag
    $diskResults = Invoke-DiskDiag
    $battResult = Invoke-BatteryDiag
    $netResult = Invoke-NetworkDiag
    Invoke-TempCleanup
    $updateResult = Invoke-UpdateCheck
    $secResult = Invoke-SecurityScan
    $gapResult = Invoke-GapCheck
    Invoke-GPUDiag
    if ($AutoFix) { Invoke-PerformanceOptimize }
    $procResult = Invoke-ProcessDiag

    $diskScores = $diskResults | ForEach-Object { $_.score }
    $overall = Get-OverallScore -CpuScore $cpuResult.score -RamScore $ramResult.score -DiskScores $diskScores -BattScore $battResult.score -NetScore $netResult.score -SecCount $secResult.vuln_count -GapCount $gapResult.gap_count

    Write-Host ""
    Write-Host "  ========================================================" -ForegroundColor Cyan
    Write-Host "                    OVERALL RESULTS                      " -ForegroundColor Yellow
    Write-Host "  ========================================================" -ForegroundColor Cyan
    Write-ColorBar -Score $overall.score
    Write-Host "  Grade:  $($overall.grade) ($($overall.rating))" -ForegroundColor $(if ($overall.score -ge 70){"Green"} elseif ($overall.score -ge 50){"Yellow"} else {"Red"})
    Write-Host "  CPU:    $($cpuResult.score)/100" -ForegroundColor White
    Write-Host "  RAM:    $($ramResult.score)/100" -ForegroundColor White
    Write-Host "  Net:    $($netResult.score)/100" -ForegroundColor White
    Write-Host "  Batt:   $($battResult.score)/100" -ForegroundColor White
    Write-Host "  Vulns:  $($secResult.vuln_count)" -ForegroundColor $(if ($secResult.vuln_count -eq 0){"Green"} else {"Red"})
    Write-Host "  Gaps:   $($gapResult.gap_count)" -ForegroundColor $(if ($gapResult.gap_count -eq 0){"Green"} else {"Yellow"})
    Write-Host "  ========================================================" -ForegroundColor Cyan

    # Build report object
    $report = [ordered]@{
        timestamp=$Timestamp; version=$ScriptVersion; overall=$overall
        cpu=$cpuResult; ram=$ramResult; disks=$diskResults; battery=$battResult
        network=$netResult; updates=$updateResult; security=$secResult
        gaps=$gapResult; processes=$procResult
    }

    # Save to JSON file
    try {
        $report | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonReport -Force -ErrorAction SilentlyContinue
        Write-EP "JSON report saved: $JsonReport" "SUCCESS"
    } catch { Write-EP "Failed to save JSON report: $_" "WARN" }

    # Save to database
    try {
        $dbId = Save-DiagnosticResult -SystemInfo $sysInfo -CpuResult $cpuResult -RamResult $ramResult -DiskResults $diskResults -BatteryResult $battResult -NetworkResult $netResult -SecurityResult $secResult -GapResult $gapResult -OverallScore $overall
        Write-EP "Saved to database: $dbId" "SUCCESS"
    } catch { Write-EP "Failed to save to database: $_" "WARN" }

    # Generate HTML report
    try {
        $htmlPath = Export-DiagnosticReport -Format "html"
        Write-EP "HTML report saved: $htmlPath" "SUCCESS"
    } catch { Write-EP "Failed to generate HTML report: $_" "WARN" }

    # Save daily log entry
    try {
        $dailyEntry = @{
            date = (Get-Date -Format "yyyy-MM-dd")
            time = (Get-Date -Format "HH:mm:ss")
            hostname = $env:COMPUTERNAME
            overall_score = $overall.score
            rating = $overall.rating
            cpu_score = $cpuResult.score
            ram_score = $ramResult.score
            vulns = $secResult.vuln_count
            gaps = $gapResult.gap_count
        }
        Add-EliasRecord -DatabaseName "elias_pro" -CollectionName "daily_logs" -Record $dailyEntry | Out-Null
        Write-EP "Daily log entry saved" "SUCCESS"
    } catch { Write-EP "Failed to save daily log: $_" "WARN" }

    # Share if requested
    if ($ShareReport) {
        Share-DiagnosticReport -ReportPath $JsonReport -SharePath $SharePath -EmailTo $EmailTo
    }

    # Flush log buffer
    Flush-LogBuffer

    return $report
}

# ====================== MAIN EXECUTION ======================
Show-Banner

# Handle command-line parameters
if ($CleanupLogs) {
    Invoke-LogRotation -KeepDays 30
    Write-EP "Log cleanup completed" "SUCCESS"
}

if ($ExportReport) {
    $fmt = if ($ReportPath -match "\.csv$") { "csv" } elseif ($ReportPath -match "\.html$") { "html" } else { "json" }
    Export-DiagnosticReport -Format $fmt -OutputPath $ReportPath
}

if ($Silent) {
    Write-EP "Running in Silent mode..." "INFO"
    Start-FullDiagnostic
} else {
    do {
        Show-Menu
        $choice = Read-Host "  Select option"
        switch ($choice) {
            "1"  { Get-DeepSystemInfo }
            "2"  { Invoke-CPUDiag }
            "3"  { Invoke-RAMDiag }
            "4"  { Invoke-DiskDiag }
            "5"  { Invoke-BatteryDiag }
            "6"  { Invoke-NetworkDiag }
            "7"  { Invoke-TempCleanup }
            "8"  { Invoke-UpdateCheck }
            "9"  { Invoke-SecurityScan }
            "10" { Invoke-GapCheck }
            "11" { Invoke-GPUDiag }
            "12" { Invoke-PerformanceOptimize }
            "13" { Invoke-ProcessDiag }
            "14" { Start-FullDiagnostic }
            "15" {
                $days = Read-Host "  Days to view (default 7)"
                if (-not $days) { $days = 7 }
                $history = Get-DiagnosticHistory -Days ([int]$days)
                if ($history.Count -eq 0) {
                    Write-Host "  No diagnostic history found" -ForegroundColor Yellow
                } else {
                    Write-Host "`n  Diagnostic History (Last $days days):" -ForegroundColor Cyan
                    Write-Host "  ─────────────────────────────────────" -ForegroundColor Gray
                    foreach ($h in $history) {
                        $date = [datetime]::Parse($h._created).ToString("yyyy-MM-dd HH:mm")
                        Write-Host "  $date | $($h.hostname) | Score: $($h.overall.score) ($($h.overall.rating))" -ForegroundColor White
                    }
                    Write-Host "  ─────────────────────────────────────" -ForegroundColor Gray
                    Write-Host "  Total: $($history.Count) records" -ForegroundColor Gray
                }
            }
            "16" {
                $metric = Read-Host "  Metric (cpu/ram/overall/battery)"
                if (-not $metric) { $metric = "overall" }
                $trend = Get-SystemTrend -Metric $metric -Days 30
                if ($trend.Count -eq 0) {
                    Write-Host "  No trend data available" -ForegroundColor Yellow
                } else {
                    Write-Host "`n  $metric Trend (Last 30 days):" -ForegroundColor Cyan
                    Write-Host "  ─────────────────────────────" -ForegroundColor Gray
                    foreach ($t in $trend) {
                        $bar = "#" * [math]::Round($t.value / 5)
                        Write-Host "  $($t.date): [$bar] $($t.value)" -ForegroundColor White
                    }
                }
            }
            "17" {
                $fmt = Read-Host "  Format (json/html/csv)"
                if (-not $fmt) { $fmt = "json" }
                $path = Export-DiagnosticReport -Format $fmt
                Write-Host "  Report exported to: $path" -ForegroundColor Green
            }
            "18" {
                $sharePath = Read-Host "  Network share path (or press Enter to skip)"
                $emailTo = Read-Host "  Email address (or press Enter to skip)"
                $report = Get-ChildItem "$ReportDir\*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($report) {
                    Share-DiagnosticReport -ReportPath $report.FullName -SharePath $sharePath -EmailTo $emailTo
                } else {
                    Write-Host "  No reports found to share" -ForegroundColor Yellow
                }
            }
            "19" {
                $stats = Get-DiagnosticStats -Days 30
                if ($stats) {
                    Write-Host "`n  Database Statistics (Last 30 days):" -ForegroundColor Cyan
                    Write-Host "  ─────────────────────────────────────" -ForegroundColor Gray
                    Write-Host "  Total Diagnostics:   $($stats.total_diagnostics)" -ForegroundColor White
                    Write-Host "  Unique Hosts:        $($stats.unique_hosts)" -ForegroundColor White
                    Write-Host "  Avg Overall Score:   $($stats.avg_overall_score)" -ForegroundColor White
                    Write-Host "  Min Score:           $($stats.min_overall)" -ForegroundColor White
                    Write-Host "  Max Score:           $($stats.max_overall)" -ForegroundColor White
                    Write-Host "  Total Vulns:         $($stats.total_vulnerabilities)" -ForegroundColor $(if ($stats.total_vulnerabilities -eq 0){"Green"} else {"Red"})
                    Write-Host "  Total Gaps:          $($stats.total_gaps)" -ForegroundColor $(if ($stats.total_gaps -eq 0){"Green"} else {"Yellow"})
                } else {
                    Write-Host "  No data in database yet" -ForegroundColor Yellow
                }
            }
            "0"  { Write-EP "Exiting Elias Pro Universal" "INFO"; Flush-LogBuffer; break }
            default { Write-EP "Invalid option: $choice" "WARN" }
        }
        if ($choice -ne "0") { Write-Host "`n  Press any key to continue..." -ForegroundColor Gray; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    } while ($choice -ne "0")
}

