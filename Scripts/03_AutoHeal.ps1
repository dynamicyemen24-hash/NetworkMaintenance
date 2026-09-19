# ====================================================================
# NetworkMaintenance-Pro v2.0.0 - Auto-Healing Module
# ====================================================================
# Description: Automatic detection and healing of network issues
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\Config.json",
    [string]$LogPath = "C:\NetworkMaintenance\Logs",
    [switch]$VerboseMode
)

$Config = Get-Content $ConfigPath | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogFile = "$LogPath\AutoHeal_$(Get-Date -Format 'yyyyMMdd').log"
$HealsApplied = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force
    switch ($Level) {
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARN" { Write-Host $entry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        "HEAL" { Write-Host $entry -ForegroundColor Cyan }
        default { Write-Host $entry -ForegroundColor White }
    }
}

function Test-LatencyThreshold {
    $target = $Config.Diagnostic.PingTarget
    $count = $Config.Diagnostic.PingCount
    $critical = $Config.Network.CriticalLatencyMs
    
    Write-Log "Testing latency to $target..." "INFO"
    
    $pingOutput = cmd /c "ping -n 5 $target"
    $latencies = @()
    
    foreach ($line in $pingOutput) {
        if ($line -match "time=(\d+)ms") {
            $latencies += [int]$matches[1]
        }
    }
    
    if ($latencies.Count -gt 0) {
        $avg = ($latencies | Measure-Object -Average).Average
        Write-Log "Average latency: $([math]::Round($avg,1))ms (threshold: $critical ms)" "INFO"
        
        if ($avg -gt $critical) {
            Write-Log "CRITICAL LATENCY DETECTED! Initiating auto-heal..." "WARN"
            return $false
        }
    }
    return $true
}

function Heal-DnsIssues {
    Write-Log "=== Checking DNS Issues ===" "HEAL"
    
    # Test DNS resolution
    $dnsTest = Resolve-DnsName "google.com" -ErrorAction SilentlyContinue
    if (!$dnsTest) {
        Write-Log "DNS Resolution FAILED! Initiating DNS heal..." "WARN"
        
        # Flush DNS
        Write-Log "Flushing DNS cache..." "HEAL"
        cmd /c "ipconfig /flushdns" | Out-Null
        $script:HealsApplied += "DNS-Flush"
        
        # Reset DNS to Cloudflare
        Write-Log "Resetting DNS to Cloudflare..." "HEAL"
        cmd /c "netsh interface ipv4 set dns `"$($Config.Network.PrimaryInterface)`" static 1.1.1.1" | Out-Null
        cmd /c "netsh interface ipv4 add dns `"$($Config.Network.PrimaryInterface)`" 8.8.8.8 index=2" | Out-Null
        $script:HealsApplied += "DNS-Reset"
        
        # Flush again after reset
        cmd /c "ipconfig /flushdns" | Out-Null
        
        Write-Log "DNS heal complete!" "SUCCESS"
        return $false
    }
    Write-Log "DNS is working correctly" "SUCCESS"
    return $true
}

function Heal-TcpIssues {
    Write-Log "=== Checking TCP Issues ===" "HEAL"
    
    # Check TCP auto-tuning
    $tcpState = cmd /c "netsh int tcp show global"
    
    if ($tcpState -match "Receive Window Auto-Tuning Level\s*:\s*disabled") {
        Write-Log "TCP Auto-Tuning is DISABLED! Healing..." "WARN"
        cmd /c "netsh int tcp set global autotuninglevel=normal" | Out-Null
        $script:HealsApplied += "TCP-AutoTuning"
        Write-Log "TCP Auto-Tuning restored to normal" "SUCCESS"
    }
    
    # Check for stuck connections
    $netstat = cmd /c "netstat -an"
    $timeWaitCount = ($netstat | Select-String "TIME_WAIT").Count
    $establishedCount = ($netstat | Select-String "ESTABLISHED").Count
    
    if ($timeWaitCount -gt 100) {
        Write-Log "High TIME_WAIT count detected ($timeWaitCount). Reducing..." "WARN"
        cmd /c "netsh int tcp set global timewaitdelay=30" | Out-Null
        $script:HealsApplied += "TCP-TIME_WAIT"
    }
    
    Write-Log "TCP check complete" "SUCCESS"
    return $true
}

function Heal-AdapterIssues {
    Write-Log "=== Checking Adapter Issues ===" "HEAL"
    
    # Check for disconnected interfaces
    $adapters = cmd /c "netsh interface ipv4 show interfaces"
    $disconnected = $adapters | Select-String "disconnected"
    
    if ($disconnected) {
        Write-Log "Disconnected adapters found. Attempting to restart..." "WARN"
        
        # Restart the primary Wi-Fi adapter
        Disable-NetAdapter -Name $Config.Network.PrimaryInterface -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Enable-NetAdapter -Name $Config.Network.PrimaryInterface -Confirm:$false -ErrorAction SilentlyContinue
        
        Write-Log "Adapter restart initiated" "HEAL"
        $script:HealsApplied += "Adapter-Restart"
    }
    
    # Check for duplicate IPs
    $ipConfig = cmd /c "ipconfig /all"
    if ($ipConfig -match "autoconfiguration") {
        Write-Log "APIPA detected - possible DHCP issue" "WARN"
        cmd /c "ipconfig /release" | Out-Null
        Start-Sleep -Seconds 2
        cmd /c "ipconfig /renew" | Out-Null
        $script:HealsApplied += "DHCP-Renew"
    }
    
    Write-Log "Adapter check complete" "SUCCESS"
    return $true
}

function Heal-DriverIssues {
    Write-Log "=== Checking Driver Issues ===" "HEAL"
    
    # Reset TCP/IP stack
    Write-Log "Resetting TCP/IP stack..." "HEAL"
    cmd /c "netsh int ip reset" | Out-Null
    
    # Reset Winsock
    Write-Log "Resetting Winsock catalog..." "HEAL"
    cmd /c "netsh winsock reset" | Out-Null
    
    # Flush DNS
    Write-Log "Flushing DNS cache..." "HEAL"
    cmd /c "ipconfig /flushdns" | Out-Null
    
    $script:HealsApplied += "Driver-Reset"
    Write-Log "Driver reset complete!" "SUCCESS"
    return $true
}

function Run-AutoHeal {
    Write-Log "========================================" "HEAL"
    Write-Log "Starting Auto-Healing Process" "HEAL"
    Write-Log "========================================" "HEAL"
    
    $latencyOk = Test-LatencyThreshold
    
    if (-not $latencyOk) {
        Heal-DriverIssues
        Heal-DnsIssues
        Heal-TcpIssues
        Heal-AdapterIssues
    }
    
    # Final DNS check
    Heal-DnsIssues
    
    # Save results
    $result = @{
        Timestamp = $Timestamp
        HealsApplied = $script:HealsApplied
        HealsCount = $script:HealsApplied.Count
        Status = if ($script:HealsApplied.Count -gt 0) { "HEALED" } else { "HEALTHY" }
    }
    
    $result | ConvertTo-Json | Set-Content "C:\NetworkMaintenance\Config\LastHeal.json" -Force
    
    Write-Log "========================================" "HEAL"
    Write-Log "Auto-Heal Complete. Heals: $($script:HealsApplied.Count)" "SUCCESS"
    Write-Log "========================================" "HEAL"
    
    return $script:HealsApplied
}

# Execute
Run-AutoHeal | Out-Null
Write-Log "Auto-heal results saved to C:\NetworkMaintenance\Config\LastHeal.json" "INFO"
