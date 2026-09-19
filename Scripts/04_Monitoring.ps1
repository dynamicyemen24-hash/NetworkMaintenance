# ====================================================================
# NetworkMaintenance-Pro v2.0.0 - Monitoring Module
# ====================================================================
# Description: Real-time and scheduled network monitoring
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\Config.json",
    [string]$LogPath = "C:\NetworkMaintenance\Logs",
    [int]$IntervalSeconds = 300,
    [switch]$Continuous = $false,
    [int]$MaxChecks = 10
)

$Config = Get-Content $ConfigPath | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogFile = "$LogPath\Monitor_$(Get-Date -Format 'yyyyMMdd').log"
$AlertLog = "$LogPath\Alerts_$(Get-Date -Format 'yyyyMMdd').log"
$CheckCount = 0

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force
    switch ($Level) {
        "ALERT" { Add-Content -Path $AlertLog -Value $entry -Force; Write-Host $entry -ForegroundColor Red }
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARN" { Write-Host $entry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        default { Write-Host $entry -ForegroundColor White }
    }
}

function Get-NetworkMetrics {
    $metrics = @{}
    
    # Latency
    $pingOutput = cmd /c "ping -n 4 $($Config.Diagnostic.PingTarget)"
    $latencies = @()
    foreach ($line in $pingOutput) {
        if ($line -match "time=(\d+)ms") {
            $latencies += [int]$matches[1]
        }
    }
    if ($latencies.Count -gt 0) {
        $metrics.LatencyAvg = [math]::Round(($latencies | Measure-Object -Average).Average, 1)
        $metrics.LatencyMin = ($latencies | Measure-Object -Minimum).Minimum
        $metrics.LatencyMax = ($latencies | Measure-Object -Maximum).Maximum
    }
    
    # Packet Loss
    $packetLoss = ($pingOutput | Select-String "lost").Count
    $metrics.PacketLoss = if ($packetLoss -gt 0) { 0 } else { 100 }
    
    # Throughput estimation
    $netBytes = Get-Counter "\Network Interface($($Config.Network.PrimaryInterface))\Bytes Total/sec" -ErrorAction SilentlyContinue
    if ($netBytes) {
        $metrics.BytesPerSec = [math]::Round($netBytes.CounterSamples[0].CookedValue / 1MB, 2)
    }
    
    # DNS resolution time
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Resolve-DnsName "google.com" -Server 1.1.1.1 -QuickTimeout -ErrorAction Stop | Out-Null
        $sw.Stop()
        $metrics.DnsLatency = $sw.ElapsedMilliseconds
    } catch {
        $sw.Stop()
        $metrics.DnsLatency = -1
    }
    
    # Active connections
    $netstat = cmd /c "netstat -an"
    $metrics.EstablishedConnections = ($netstat | Select-String "ESTABLISHED").Count
    $metrics.TCPConnections = ($netstat | Select-String "TCP").Count
    
    # Interface status
    $interfaces = cmd /c "netsh interface ipv4 show interfaces"
    $metrics.WiFiStatus = "Connected"
    
    return $metrics
}

function Check-AlertThresholds {
    param([hashtable]$Metrics)
    $alerts = @()
    
    # Latency check
    if ($Metrics.LatencyAvg -gt $Config.Network.CriticalLatencyMs) {
        $alerts += "CRITICAL: Latency at $($Metrics.LatencyAvg)ms"
        Write-Log "CRITICAL LATENCY: $($Metrics.LatencyAvg)ms" "ALERT"
    } elseif ($Metrics.LatencyAvg -gt $Config.Network.WarningLatencyMs) {
        $alerts += "WARNING: Latency at $($Metrics.LatencyAvg)ms"
        Write-Log "High Latency Warning: $($Metrics.LatencyAvg)ms" "WARN"
    }
    
    # DNS check
    if ($Metrics.DnsLatency -lt 0) {
        $alerts += "CRITICAL: DNS Resolution FAILED"
        Write-Log "DNS Resolution FAILED!" "ALERT"
    } elseif ($Metrics.DnsLatency -gt 200) {
        $alerts += "WARNING: DNS Latency at $($Metrics.DnsLatency)ms"
        Write-Log "High DNS Latency: $($Metrics.DnsLatency)ms" "WARN"
    }
    
    # Packet loss check
    if ($Metrics.PacketLoss -eq 0 -or $Metrics.PacketLoss -eq 100) {
        $alerts += "WARNING: Possible packet loss detected"
        Write-Log "Possible packet loss" "WARN"
    }
    
    return $alerts
}

function Run-MonitoringCycle {
    $CheckCount++
    $metrics = Get-NetworkMetrics
    
    Write-Log "=== Check #$CheckCount ===" "INFO"
    Write-Log "Latency: $($metrics.LatencyAvg)ms | DNS: $($metrics.DnsLatency)ms | Connections: $($metrics.EstablishedConnections)" "INFO"
    
    $alerts = Check-AlertThresholds -Metrics $metrics
    
    # Save metrics to history
    $metricEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        CheckNumber = $CheckCount
        Metrics = $metrics
        Alerts = $alerts
    }
    
    $historyFile = "$LogPath\Metrics_History.json"
    if (Test-Path $historyFile) {
        $history = Get-Content $historyFile | ConvertFrom-Json
    } else {
        $history = @()
    }
    
    $history += $metricEntry
    if ($history.Count -gt 1000) { $history = $history[-1000..($history.Count-1)] }
    
    $history | ConvertTo-Json -Depth 3 | Set-Content $historyFile -Force
    
    return $metrics
}

function Start-ContinuousMonitoring {
    Write-Log "Starting Continuous Monitoring (interval: $IntervalSeconds sec)..." "INFO"
    
    $c = 0
    while ($Continuous -or $c -lt $MaxChecks) {
        $c++
        Run-MonitoringCycle
        
        if ($c -ge $MaxChecks -and -not $Continuous) { break }
        Start-Sleep -Seconds $IntervalSeconds
    }
    
    Write-Log "Monitoring session ended. Total checks: $c" "SUCCESS"
}

# Execute
if ($Continuous) {
    Start-ContinuousMonitoring
} else {
    Start-ContinuousMonitoring
}
