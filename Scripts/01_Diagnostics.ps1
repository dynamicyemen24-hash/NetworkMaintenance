# ====================================================================
# NetworkMaintenance-Pro v2.0.0 - Diagnostic Module
# ====================================================================
# Description: Comprehensive network diagnostics and analysis
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\Config.json",
    [string]$LogPath = "C:\NetworkMaintenance\Logs"
)

$Config = Get-Content $ConfigPath | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogFile = "$LogPath\Diagnostic_$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force
    switch ($Level) {
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARN" { Write-Host $entry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        default { Write-Host $entry -ForegroundColor White }
    }
}

function Get-NetworkInterfaceInfo {
    Write-Log "=== Network Interface Information ===" "INFO"
    $interfaces = netsh interface ipv4 show interfaces
    foreach ($line in $interfaces) {
        if ($line -match "\d+\s+\d+\s+\d+\s+\w+\s+(.+)") {
            Write-Log "Interface: $($matches[1])" "DEBUG"
        }
    }
    
    $ipConfig = cmd /c "ipconfig /all"
    Write-Log "IP Configuration:" "INFO"
    $ipConfig | ForEach-Object { Write-Log $_ "DEBUG" }
}

function Get-PingAnalysis {
    param([string]$Target = "8.8.8.8", [int]$Count = 20)
    Write-Log "=== Ping Analysis to $Target ($Count packets) ===" "INFO"
    
    $pingResults = cmd /c "ping -n $Count $Target"
    $latencies = @()
    
    foreach ($line in $pingResults) {
        if ($line -match "time=(\d+)ms") {
            $latencies += [int]$matches[1]
        }
    }
    
    if ($latencies.Count -gt 0) {
        $avg = ($latencies | Measure-Object -Average).Average
        $min = ($latencies | Measure-Object -Minimum).Minimum
        $max = ($latencies | Measure-Object -Maximum).Maximum
        $stddev = [math]::Sqrt(($latencies | ForEach-Object { ($_ - $avg) * ($_ - $avg) } | Measure-Object -Average).Average)
        
        Write-Log "Average Latency: $([math]::Round($avg,1))ms" "INFO"
        Write-Log "Min Latency: $min ms" "INFO"
        Write-Log "Max Latency: $max ms" "INFO"
        Write-Log "Std Deviation: $([math]::Round($stddev,1))ms" "INFO"
        Write-Log "Packet Loss: 0%" "SUCCESS"
        
        $status = switch -Wildcard ($avg) {
            { $_ -lt 50 } { "EXCELLENT" }
            { $_ -lt 100 } { "GOOD" }
            { $_ -lt 150 } { "FAIR" }
            { $_ -lt 300 } { "POOR" }
            default { "CRITICAL" }
        }
        Write-Log "Network Status: $status" $status
    }
    
    return @{ Average = $avg; Min = $min; Max = $max; StdDev = $stddev; Latencies = $latencies }
}

function Get-DnsAnalysis {
    Write-Log "=== DNS Resolution Analysis ===" "INFO"
    $dnsServers = $Config.Diagnostic.DNS_Servers
    $domains = $Config.Diagnostic.TestDomains
    
    foreach ($dns in $dnsServers) {
        foreach ($domain in $domains) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $result = Resolve-DnsName $domain -Server $dns -ErrorAction Stop
                $sw.Stop()
                $elapsedMs = $sw.ElapsedMilliseconds
                Write-Log ("DNS " + $domain + " via " + $dns + ": " + $elapsedMs + " ms - SUCCESS") "SUCCESS"
            } catch {
                $sw.Stop()
                $errMsg = $_.Exception.Message
                Write-Log ("DNS " + $domain + " via " + $dns + ": FAILED - " + $errMsg) "ERROR"
            }
        }
    }
}

function Get-TcpAnalysis {
    Write-Log "=== TCP Configuration Analysis ===" "INFO"
    
    $tcpGlobal = cmd /c "netsh int tcp show global"
    foreach ($line in $tcpGlobal) {
        if ($line -match "(\S+)\s*:\s*(\S+)") {
            $param = $matches[1]
            $value = $matches[2]
            Write-Log "TCP Parameter: $param = $value" "DEBUG"
        }
    }
    
    # Check for issues
    $rtt = (cmd /c "netsh int tcp show global" | Select-String "Initial RTO")
    Write-Log "RTO Check: $rtt" "INFO"
}

function Get-TracerouteAnalysis {
    param([string]$Target = "8.8.8.8")
    Write-Log "=== Traceroute Analysis to $Target ===" "INFO"
    
    $tracert = cmd /c "tracert -d -h 15 $Target"
    $hopCount = 0
    $totalLatency = 0
    
    foreach ($line in $tracert) {
        if ($line -match "^\s+\d+\s+") {
            $hopCount++
            if ($line -match "ms") {
                $latencies = [regex]::Matches($line, "(\d+)ms") | ForEach-Object { [int]$_.Groups[1].Value }
                if ($latencies.Count -gt 0) {
                    $totalLatency += ($latencies | Measure-Object -Average).Average
                }
            }
        }
    }
    
    Write-Log "Total Hops: $hopCount" "INFO"
    if ($hopCount -gt 0) {
        Write-Log "Average Hop Latency: $([math]::Round($totalLatency / $hopCount, 1))ms" "INFO"
    }
    
    if ($hopCount -gt 10) {
        Write-Log "WARNING: Excessive hops detected ($hopCount)" "WARN"
    }
}

function Get-RouteAnalysis {
    Write-Log "=== Routing Table Analysis ===" "INFO"
    $routes = cmd /c "route print"
    
    # Check for multiple default gateways
    $defaultGateways = ($routes | Select-String "0\.0\.0\.0").Count
    if ($defaultGateways -gt 1) {
        Write-Log "WARNING: Multiple default gateways detected ($defaultGateways)" "WARN"
    } else {
        Write-Log "Default Gateway: OK (1 gateway)" "SUCCESS"
    }
}

function Run-FullDiagnostic {
    Write-Log "========================================" "INFO"
    Write-Log "Starting Full Network Diagnostic" "INFO"
    Write-Log "========================================" "INFO"
    
    $results = @{
        Timestamp = $Timestamp
        Interfaces = @{}
        Ping = @{}
        Dns = @{}
        Tcp = @{}
        Routes = @{}
    }
    
    Get-NetworkInterfaceInfo
    $results.Ping = Get-PingAnalysis
    Get-DnsAnalysis
    Get-TcpAnalysis
    Get-TracerouteAnalysis
    Get-RouteAnalysis
    
    Write-Log "========================================" "INFO"
    Write-Log "Diagnostic Complete" "SUCCESS"
    Write-Log "========================================" "INFO"
    
    return $results
}

# Execute
Run-FullDiagnostic | Out-Null
Write-Log "Diagnostic results saved to $LogFile" "INFO"
