# ====================================================================
# NetworkMaintenance-Pro v2.0.0 - Optimization Module
# ====================================================================
# Description: Apply TCP/IP, DNS, and adapter optimizations
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\Config.json",
    [string]$LogPath = "C:\NetworkMaintenance\Logs",
    [switch]$DryRun,
    [switch]$ForceApply
)

$Config = Get-Content $ConfigPath | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogFile = "$LogPath\Optimization_$(Get-Date -Format 'yyyyMMdd').log"
$AppliedFixes = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force
    switch ($Level) {
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARN" { Write-Host $entry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        "ACTION" { Write-Host $entry -ForegroundColor Cyan }
        default { Write-Host $entry -ForegroundColor White }
    }
}

function Apply-TcpOptimization {
    Write-Log "=== Applying TCP/IP Optimizations ===" "ACTION"
    
    $opt = $Config.Optimization
    $ecnStr = if ($opt.EnableEcn) { "enabled" } else { "disabled" }
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would set: autotuninglevel=$($opt.TcpAutoTuningLevel)" "ACTION"
        Write-Log "[DRY RUN] Would set: ecncapability=$ecnStr" "ACTION"
        Write-Log "[DRY RUN] Would set: pacingprofile=$($opt.PacingProfile)" "ACTION"
        Write-Log "[DRY RUN] Would set: initialRTO=$($opt.InitialRto)" "ACTION"
        Write-Log "[DRY RUN] Would set: maxsynretransmissions=$($opt.MaxSynRetransmissions)" "ACTION"
        Write-Log "[DRY RUN] Would set: congestionprovider=$($opt.CongestionProvider)" "ACTION"
        Write-Log "[DRY RUN] Would set: MTU=$($opt.Mtu)" "ACTION"
        Write-Log "[DRY RUN] Would set: rcvwnd=$($opt.RcvWnd)" "ACTION"
        return
    }
    
    try {
        # TCP Auto-Tuning
        Write-Log "Setting TCP Auto-Tuning to $($opt.TcpAutoTuningLevel)..." "ACTION"
        cmd /c "netsh int tcp set global autotuninglevel=$($opt.TcpAutoTuningLevel)" | Out-Null
        $AppliedFixes += "TCP-AutoTuning=$($opt.TcpAutoTuningLevel)"
        
        # ECN
        $ecnStr = if ($opt.EnableEcn) { "enabled" } else { "disabled" }
        Write-Log "Setting ECN to $ecnStr..." "ACTION"
        cmd /c "netsh int tcp set global ecncapability=$ecnStr" | Out-Null
        $AppliedFixes += "TCP-ECN=$ecnStr"
        
        # Pacing
        Write-Log "Setting Pacing Profile to $($opt.PacingProfile)..." "ACTION"
        cmd /c "netsh int tcp set global pacingprofile=$($opt.PacingProfile)" | Out-Null
        $AppliedFixes += "TCP-Pacing=$($opt.PacingProfile)"
        
        # Initial RTO
        Write-Log "Setting Initial RTO to $($opt.InitialRto)ms..." "ACTION"
        cmd /c "netsh int tcp set global initialRTO=$($opt.InitialRto)" | Out-Null
        $AppliedFixes += "TCP-RTO=$($opt.InitialRto)"
        
        # Max SYN Retransmissions
        Write-Log "Setting Max SYN Retransmissions to $($opt.MaxSynRetransmissions)..." "ACTION"
        cmd /c "netsh int tcp set global maxsynretransmissions=$($opt.MaxSynRetransmissions)" | Out-Null
        $AppliedFixes += "TCP-SYNRetry=$($opt.MaxSynRetransmissions)"
        
        # Congestion Control
        Write-Log "Setting Congestion Provider to $($opt.CongestionProvider)..." "ACTION"
        cmd /c "netsh int tcp set global congestionprovider=$($opt.CongestionProvider)" | Out-Null
        $AppliedFixes += "TCP-Congestion=$($opt.CongestionProvider)"
        
        # Receive Window
        Write-Log "Setting Receive Window to $($opt.RcvWnd)..." "ACTION"
        cmd /c "netsh int tcp set global rcvwnd=$($opt.RcvWnd)" | Out-Null
        $AppliedFixes += "TCP-RcvWnd=$($opt.RcvWnd)"
        
        # MTU
        Write-Log "Setting MTU to $($opt.Mtu) on interface '$($Config.Network.PrimaryInterface)'..." "ACTION"
        cmd /c "netsh interface ipv4 set subinterface `"$($Config.Network.PrimaryInterface)`" mtu=$($opt.Mtu) store=persistent" | Out-Null
        $AppliedFixes += "MTU=$($opt.Mtu)"
        
        # Chimney Offload
        Write-Log "Setting Chimney Offload to $(if($opt.EnableChimneyOffload){'enabled'}else{'disabled'})..." "ACTION"
        cmd /c "netsh interface ipv4 set subinterface `"$($Config.Network.PrimaryInterface)`" chimney=$(if($opt.EnableChimneyOffload){'enabled'}else{'disabled'})" | Out-Null
        $AppliedFixes += "Chimney=$(if($opt.EnableChimneyOffload){'enabled'}else{'disabled'})"
        
        Write-Log "TCP Optimization Complete!" "SUCCESS"
    } catch {
        Write-Log "Error applying TCP optimization: $_" "ERROR"
    }
}

function Apply-DnsOptimization {
    Write-Log "=== Applying DNS Optimizations ===" "ACTION"
    
    $dns = $Config.Dns
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would set primary DNS: $($dns.PrimaryDns)" "ACTION"
        Write-Log "[DRY RUN] Would set secondary DNS: $($dns.SecondaryDns)" "ACTION"
        Write-Log "[DRY RUN] Would set tertiary DNS: $($dns.TertiaryDns)" "ACTION"
        Write-Log "[DRY RUN] Would enable DNS over HTTPS: $($dns.EnableDnsOverHttps)" "ACTION"
        return
    }
    
    try {
        Write-Log "Setting primary DNS to $($dns.PrimaryDns)..." "ACTION"
        cmd /c "netsh interface ipv4 set dns `"$($Config.Network.PrimaryInterface)`" static $($dns.PrimaryDns)" | Out-Null
        $AppliedFixes += "DNS-Primary=$($dns.PrimaryDns)"
        
        Write-Log "Adding secondary DNS $($dns.SecondaryDns)..." "ACTION"
        cmd /c "netsh interface ipv4 add dns `"$($Config.Network.PrimaryInterface)`" $($dns.SecondaryDns) index=2" | Out-Null
        $AppliedFixes += "DNS-Secondary=$($dns.SecondaryDns)"
        
        Write-Log "Adding tertiary DNS $($dns.TertiaryDns)..." "ACTION"
        cmd /c "netsh interface ipv4 add dns `"$($Config.Network.PrimaryInterface)`" $($dns.TertiaryDns) index=3" | Out-Null
        $AppliedFixes += "DNS-Tertiary=$($dns.TertiaryDns)"
        
        Write-Log "DNS Optimization Complete!" "SUCCESS"
    } catch {
        Write-Log "Error applying DNS optimization: $_" "ERROR"
    }
}

function Apply-VirtualAdapterManagement {
    Write-Log "=== Managing Virtual Adapters ===" "ACTION"
    
    $vOpt = $Config.VirtualAdapters
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would disable Hyper-V adapters" "ACTION"
        Write-Log "[DRY RUN] Would disable Docker adapters" "ACTION"
        Write-Log "[DRY RUN] Would disable Bluetooth adapters" "ACTION"
        return
    }
    
    try {
        # Set metrics to deprioritize virtual adapters
        Write-Log "Setting Hyper-V metric to $($vOpt.HyperVMetric)..." "ACTION"
        cmd /c "netsh interface ipv4 set subinterface `"$($Config.Network.PrimaryInterface)`" metric=$($vOpt.PrimaryInterfaceMetric) store=persistent" | Out-Null
        
        # Disable non-essential adapters (commented out for safety)
        # Disable-NetAdapter -Name "vEthernet (Default Switch)" -Confirm:$false
        # Disable-NetAdapter -Name "Bluetooth Network Connection" -Confirm:$false
        
        Write-Log "Virtual Adapter Management Complete!" "SUCCESS"
    } catch {
        Write-Log "Error managing virtual adapters: $_" "ERROR"
    }
}

function Apply-NetworkReset {
    Write-Log "=== Applying Network Reset ===" "ACTION"
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would reset: netsh int ip reset" "ACTION"
        Write-Log "[DRY RUN] Would reset: netsh winsock reset" "ACTION"
        Write-Log "[DRY RUN] Would flush DNS cache" "ACTION"
        return
    }
    
    try {
        Write-Log "Resetting IP stack..." "ACTION"
        cmd /c "netsh int ip reset" | Out-Null
        
        Write-Log "Resetting Winsock..." "ACTION"
        cmd /c "netsh winsock reset" | Out-Null
        
        Write-Log "Flushing DNS cache..." "ACTION"
        cmd /c "ipconfig /flushdns" | Out-Null
        
        Write-Log "Registering DNS..." "ACTION"
        cmd /c "ipconfig /registerdns" | Out-Null
        
        Write-Log "Network Reset Complete! A reboot is required for full effect." "WARN"
        $AppliedFixes += "NetworkReset=Applied"
    } catch {
        Write-Log "Error during network reset: $_" "ERROR"
    }
}

function Run-FullOptimization {
    Write-Log "========================================" "ACTION"
    Write-Log "Starting Full Network Optimization" "ACTION"
    Write-Log "========================================" "ACTION"
    
    if ($DryRun) {
        Write-Log "*** DRY RUN MODE - No changes will be applied ***" "WARN"
    }
    
    Apply-TcpOptimization
    Apply-DnsOptimization
    Apply-VirtualAdapterManagement
    
    if ($ForceApply) {
        Apply-NetworkReset
    }
    
    # Save results
    $result = @{
        Timestamp = $Timestamp
        DryRun = $DryRun
        FixesApplied = $AppliedFixes
        Status = "COMPLETED"
    }
    
    $result | ConvertTo-Json | Set-Content "C:\NetworkMaintenance\Config\LastOptimization.json" -Force
    
    Write-Log "========================================" "ACTION"
    Write-Log "Optimization Complete. Fixes: $($AppliedFixes.Count)" "SUCCESS"
    Write-Log "========================================" "ACTION"
    
    return $AppliedFixes
}

# Execute
Run-FullOptimization | Out-Null
Write-Log "Optimization results saved to C:\NetworkMaintenance\Config\LastOptimization.json" "INFO"
