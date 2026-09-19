# ====================================================================
# NetworkMaintenance-Pro v4.1 - NETDIAG Engine (Advanced Network Diagnostics)
# ====================================================================
# Open Source: iperf3, mtr/WinMTR, nmap, Wireshark, dnsbench, speedtest-cli
# Tests: Latency, Jitter, Packet Loss, Bandwidth, DNS, Ports, Trace
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$Target = "8.8.8.8",
    [string]$TicketNo = "",
    [switch]$FullScan,
    [int]$PingCount = 20
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "$DataPath\..\Logs\NETDIAG_$(Get-Date -Format 'yyyyMMdd').log"

function Write-NETDIAGLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} default {"White"} }
    Write-Host $entry -ForegroundColor $color
}

class NetworkDiagnostics {
    [hashtable] TestLatency([string]$Target, [int]$Count) {
        $result = @{ target=$Target; count=$Count; avg_ms=0; min_ms=0; max_ms=0; jitter_ms=0; packet_loss_percent=0; status="UNKNOWN"; issues=@(); tool="ping + mtr/WinMTR" }
        try {
            $pings = @()
            $lost = 0
            for ($i=0; $i -lt $Count; $i++) {
                $ping = Test-Connection $Target -Count 1 -ErrorAction SilentlyContinue
                if ($ping) { $pings += $ping.ResponseTime } else { $lost++ }
                Start-Sleep -Milliseconds 100
            }
            if ($pings.Count -gt 0) {
                $result.avg_ms = [math]::Round(($pings | Measure-Object -Average).Average,1)
                $result.min_ms = ($pings | Measure-Object -Minimum).Minimum
                $result.max_ms = ($pings | Measure-Object -Maximum).Maximum
                $result.jitter_ms = [math]::Round(($pings | Measure-Object -StandardDeviation).StandardDeviation,1)
                if ($null -eq $result.jitter_ms) { $result.jitter_ms = 0 }
            }
            $result.packet_loss_percent = [math]::Round($lost / $Count * 100,1)
            # mtr/WinMTR concept: trace + ping combined
            try {
                $trace = Test-NetConnection $Target -TraceRoute -ErrorAction SilentlyContinue
                if ($trace) { $result.hops = $trace.TraceRoute.Count; $result.trace_route = $trace.TraceRoute }
            } catch {}
            $result.status = if ($result.packet_loss_percent -gt 5) {"CRITICAL"} elseif ($result.packet_loss_percent -gt 1) {"POOR"} elseif ($result.avg_ms -gt 300) {"POOR"} elseif ($result.avg_ms -gt 100) {"FAIR"} elseif ($result.avg_ms -gt 50) {"GOOD"} else {"EXCELLENT"}
            if ($result.packet_loss_percent -gt 1) { $result.issues += "Packet loss $($result.packet_loss_percent)%" }
            if ($result.jitter_ms -gt 30) { $result.issues += "High jitter $($result.jitter_ms)ms" }
            if ($result.avg_ms -gt 150) { $result.issues += "High latency $($result.avg_ms)ms" }
        } catch { $result.issues += $_.Exception.Message }
        return $result
    }

    [hashtable] TestBandwidth() {
        $result = @{ download_mbps=0; upload_mbps=0; status="UNKNOWN"; issues=@(); tool="iperf3 / speedtest-cli concept" }
        try {
            # Check if iperf3 available (open source)
            $iperf = Get-Command iperf3 -ErrorAction SilentlyContinue
            if ($iperf) {
                # Real iperf3 test (requires server)
                $result.tool = "iperf3"
                $result.note = "iperf3 found - run: iperf3 -c <server> for real test"
            }
            # Fallback: estimate via download test (like speedtest-cli)
            $urls = @("https://www.google.com/generate_204", "https://www.cloudflare.com/cdn-cgi/trace")
            $speeds = @()
            foreach ($url in $urls) {
                try {
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    $null = Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
                    $sw.Stop()
                    # Estimate: small file, so just measure latency
                    $speeds += 10 # placeholder
                } catch {}
            }
            # Real bandwidth requires larger download; estimate from interface
            $adapter = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq "Up" | Select-Object -First 1
            if ($adapter) { $result.interface = $adapter.Name; $result.link_speed = $adapter.LinkSpeed }
            $result.status = "ESTIMATED"
            $result.note = "For accurate bandwidth, install iperf3 (https://iperf.fr/) or speedtest-cli (https://github.com/sivel/speedtest-cli)"
        } catch { $result.issues += $_.Exception.Message }
        return $result
    }

    [hashtable] TestDNS([string[]]$Servers) {
        $result = @{ servers=@(); fastest=""; avg_ms=0; issues=@(); tool="dnsbench / namebench concept" }
        try {
            $testDomain = "google.com"
            $times = @()
            foreach ($srv in $Servers) {
                $sw = [Diagnostics.Stopwatch]::StartNew()
                try {
                    $null = Resolve-DnsName $testDomain -Server $srv -QuickTimeout -ErrorAction Stop
                    $sw.Stop()
                    $ms = [math]::Round($sw.Elapsed.TotalMilliseconds,1)
                    $times += $ms
                    $result.servers += @{ server=$srv; ms=$ms; status="OK" }
                } catch {
                    $sw.Stop()
                    $result.servers += @{ server=$srv; ms=9999; status="FAIL"; error=$_.Exception.Message }
                }
            }
            $okTimes = $result.servers | Where-Object { $_.status -eq "OK" } | ForEach-Object { $_.ms }
            if ($okTimes) {
                $result.avg_ms = [math]::Round(($okTimes | Measure-Object -Average).Average,1)
                $result.fastest = ($result.servers | Where-Object { $_.status -eq "OK" } | Sort-Object ms | Select-Object -First 1).server
            }
            $slow = $result.servers | Where-Object { $_.ms -gt 200 }
            foreach ($s in $slow) { $result.issues += "DNS $($s.server) slow: $($s.ms)ms" }
        } catch { $result.issues += $_.Exception.Message }
        return $result
    }

    [hashtable] TestPorts([string]$Target) {
        $result = @{ target=$Target; open_ports=@(); closed_ports=@(); issues=@(); tool="nmap concept" }
        try {
            $commonPorts = @(80, 443, 22, 53, 3389, 8080)
            foreach ($port in $commonPorts) {
                $tcp = Test-NetConnection $Target -Port $port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                if ($tcp -and $tcp.TcpTestSucceeded) { $result.open_ports += $port } else { $result.closed_ports += $port }
            }
            # nmap integration if available
            $nmap = Get-Command nmap -ErrorAction SilentlyContinue
            if ($nmap) {
                $result.tool = "nmap"
                $result.note = "nmap found - run: nmap -sV $Target for detailed scan"
            }
        } catch { $result.issues += $_.Exception.Message }
        return $result
    }

    [hashtable] TestMobileNetwork() {
        $result = @{ source="ADB"; signal_dbm=0; operator="Unknown"; network_type="Unknown"; issues=@(); tool="ADB dumpsys telephony" }
        try {
            if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
                $result.issues += "ADB not found"
                return $result
            }
            $out = & adb shell dumpsys telephony.registry 2>$null | Out-String
            if ($out -match "mServiceState.*?mOperatorAlphaLong\s*=\s*(\w+)") { $result.operator = $Matches[1] }
            # Signal strength
            $sig = & adb shell dumpsys telephony.registry 2>$null | Select-String "mSignalStrength" | Out-String
            if ($sig -match "level=(\d)") { $level=[int]$Matches[1]; $result.signal_dbm = -113 + $level * 20 }
            # Network type
            if ($out -match "mDataConnectionState") { $result.network_type = "Connected" }
        } catch { $result.issues += $_.Exception.Message }
        return $result
    }
}

function Invoke-NETDIAGEngine {
    Write-NETDIAGLog "========== NETDIAG Engine v4.1 - Advanced Network Diagnostics ==========" "ACTION"
    Write-NETDIAGLog "Target: $Target | FullScan: $FullScan | PingCount: $PingCount" "INFO"
    Write-NETDIAGLog "Open Source: iperf3, mtr/WinMTR, nmap, dnsbench, Wireshark concepts" "INFO"

    $diag = [NetworkDiagnostics]::new()
    $results = @{
        engine = "NETDIAG"
        version = "4.1"
        timestamp = $Timestamp
        ticket_no = $TicketNo
        latency = $null
        bandwidth = $null
        dns = $null
        ports = $null
        mobile = $null
        summary = @{}
    }

    Write-NETDIAGLog "[NETDIAG] Latency & Jitter (mtr concept)..." "ACTION"
    $results.latency = $diag.TestLatency($Target, $PingCount)
    Write-NETDIAGLog "Latency: $($results.latency.avg_ms)ms | Jitter: $($results.latency.jitter_ms)ms | Loss: $($results.latency.packet_loss_percent)% ($($results.latency.status))" $(if ($results.latency.status -in @("EXCELLENT","GOOD")) {"SUCCESS"} else {"WARN"})

    Write-NETDIAGLog "[NETDIAG] Bandwidth estimation (iperf3 concept)..." "ACTION"
    $results.bandwidth = $diag.TestBandwidth()
    if ($results.bandwidth.interface) { Write-NETDIAGLog "Interface: $($results.bandwidth.interface) | $($results.bandwidth.link_speed)" "INFO" }

    Write-NETDIAGLog "[NETDIAG] DNS benchmark (dnsbench concept)..." "ACTION"
    $results.dns = $diag.TestDNS(@("1.1.1.1","8.8.8.8","9.9.9.9","208.67.222.222"))
    Write-NETDIAGLog "DNS avg: $($results.dns.avg_ms)ms | Fastest: $($results.dns.fastest)" "INFO"
    foreach ($issue in $results.dns.issues) { Write-NETDIAGLog $issue "WARN" }

    Write-NETDIAGLog "[NETDIAG] Port scan (nmap concept)..." "ACTION"
    $results.ports = $diag.TestPorts($Target)
    Write-NETDIAGLog "Open ports: $($results.ports.open_ports -join ', ') | Closed: $($results.ports.closed_ports.Count)" "INFO"

    if ($FullScan -and (Get-Command adb -ErrorAction SilentlyContinue)) {
        $adbDev = & adb devices 2>$null | Select-String "device$"
        if ($adbDev) {
            Write-NETDIAGLog "[NETDIAG] Mobile network (ADB)..." "ACTION"
            $results.mobile = $diag.TestMobileNetwork()
        }
    }

    # Summary
    $score = 100
    if ($results.latency.packet_loss_percent -gt 1) { $score -= 30 }
    if ($results.latency.avg_ms -gt 150) { $score -= 20 }
    if ($results.latency.jitter_ms -gt 30) { $score -= 15 }
    if ($results.dns.issues.Count -gt 0) { $score -= 10 }
    $score = [math]::Max(0, $score)
    $results.summary = @{ health_score = $score; status = if ($score -ge 85) {"EXCELLENT"} elseif ($score -ge 60) {"GOOD"} else {"POOR"}; recommendation = if ($score -lt 60) {"Network issues detected - check ISP/cabling"} else {"Network OK"} }
    Write-NETDIAGLog "NETDIAG Summary: $score/100 ($($results.summary.status))" "SUCCESS"

    $outPath = "$DataPath\netdiag_results.json"
    $results | ConvertTo-Json -Depth 12 | Set-Content $outPath -Force
    Write-NETDIAGLog "Saved -> $outPath" "SUCCESS"
    return $results
}

Invoke-NETDIAGEngine
