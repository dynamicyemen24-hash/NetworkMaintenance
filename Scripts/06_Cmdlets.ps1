# ====================================================================
# NetworkMaintenance-Pro v2.0.0 - Command Reference
# ====================================================================
# Description: Quick reference for all maintenance commands
# ====================================================================

<#

NETWORK MAINTENANCE-PRO v2.0.0 - COMMAND REFERENCE
==================================================

QUICK START COMMANDS:
─────────────────────

# Full maintenance run (diagnose + heal + optimize + report)
powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\05_Maintenance.ps1" -Mode Full -AutoHeal

# Quick diagnostics only
powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\05_Maintenance.ps1" -Mode Diagnostics

# Apply optimizations (no reboot needed)
powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\05_Maintenance.ps1" -Mode Optimize

# Auto-heal mode
powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\05_Maintenance.ps1" -Mode Heal

# Start continuous monitoring (30 second intervals)
powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\05_Maintenance.ps1" -Mode Monitor -Continuous

# Generate report
powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\05_Maintenance.ps1" -Mode Report

# Dry run (see what would change without applying)
powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\02_Optimization.ps1" -DryRun

# Schedule daily maintenance at 6 AM
powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\05_Maintenance.ps1" -Mode Scheduler

MANUAL COMMANDS:
────────────────

# Network Diagnostics
ping -n 20 8.8.8.8                          → Test latency
tracert -d -h 15 8.8.8.8                    → Trace route
pathping -n -q 100 -w 500 8.8.8.8          → Path + ping analysis
nslookup google.com 8.8.8.8                 → Test DNS resolution
Resolve-DnsName google.com -Server 1.1.1.1  → PowerShell DNS test

# TCP/IP Optimization Commands
netsh int tcp set global autotuninglevel=experimental  → Enable advanced auto-tuning
netsh int tcp set global ecncapability=enabled           → Enable ECN
netsh int tcp set global pacingprofile=delay-based       → Enable delay-based pacing
netsh int tcp set global initialRTO=500                  → Reduce retransmission timeout
netsh int tcp set global congestionprovider=ctcp         → Use CTCP congestion control
netsh int tcp set global rss=enabled                     → Enable Receive Segment Coalescing
netsh interface ipv4 set subinterface "Wi-Fi" mtu=1450 store=persistent → Set MTU

# DNS Optimization
netsh interface ipv4 set dns "Wi-Fi" static 1.1.1.1      → Set primary DNS
netsh interface ipv4 add dns "Wi-Fi" 8.8.8.8 index=2     → Add secondary DNS
ipconfig /flushdns                                       → Clear DNS cache
ipconfig /registerdns                                    → Re-register DNS

# Network Reset
netsh int ip reset                                       → Reset IP stack
netsh winsock reset                                      → Reset Winsock catalog
ipconfig /flushdns                                       → Flush DNS cache
netsh int tcp reset                                      → Reset TCP parameters

# Virtual Adapter Management
Disable-NetAdapter -Name "vEthernet (Default Switch)"     → Disable Hyper-V adapter
Get-NetAdapter | Where-Object {$_.Status -eq "Up"}        → List active adapters
Set-NetAdapterPowerManagement -Name "Wi-Fi" -Enabled $false → Disable power saving

# Monitoring
Get-Counter "\Network Interface(Wi-Fi)\Bytes Total/sec"  → Monitor bandwidth
netstat -an | findstr ESTABLISHED                         → Count active connections
netsh interface ipv4 show neighbors                       → Show ARP table

# Registry Checks
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay

TROUBLESHOOTING FLOWCHART:
─────────────────────────

1. Is internet slow?
   ├─ YES → Run: Mode: Heal
   ├─ After heal → Run: Mode: Diagnostics
   └─ Still slow? → Check: ISP/Router/Hardware

2. Is DNS slow?
   ├─ YES → Run: DNS Optimization commands
   ├─ Switch to 1.1.1.1 (Cloudflare)
   └─ Still slow? → Check: DNS Hijacking

3. Are virtual adapters causing issues?
   ├─ YES → Disable Hyper-V, Docker, Bluetooth adapters
   ├─ Change interface metrics
   └─ Reboot and retest

4. Is TCP/IP corrupted?
   ├─ YES → Run: Network Reset commands
   ├─ Reboot
   └─ Re-run diagnostics

5. Is Wi-Fi slow?
   ├─ YES → Check: Interference, Channel, Distance
   ├─ Change Wi-Fi channel (use 1, 6, or 11)
   ├─ Set MTU to 1450
   └─ Disable power saving on adapter

SCHEDULED MAINTENANCE:
──────────────────────

Daily:   06:00 AM - Quick diagnostics
Weekly:  Sunday 02:00 AM - Full optimization
Monthly: 1st of month 03:00 AM - Full reset + report

ALERT THRESHOLDS:
─────────────────

Latency:
  EXCELLENT: <50ms
  GOOD:      <100ms
  FAIR:      <150ms
  POOR:      <300ms
  CRITICAL:  >300ms

DNS Resolution:
  EXCELLENT: <10ms
  GOOD:      <50ms
  SLOW:      >200ms
  FAILED:    Timeout

Packet Loss:
  EXCELLENT: 0%
  ACCEPTABLE: <1%
  WARNING:   1-5%
  CRITICAL:  >5%

VERSION HISTORY:
─────────────────

v2.0.0 - Current - Professional maintenance system
v1.0.0 - Initial - Basic diagnostics and optimization

(C) NetworkMaintenance-Pro v2.0.0

#>
Write-Host "NetworkMaintenance-Pro v2.0.0 - Command Reference" -ForegroundColor Cyan
Write-Host "Use: powershell.exe -ExecutionPolicy Bypass -File C:\NetworkMaintenance\Scripts\05_Maintenance.ps1 -Mode <mode>" -ForegroundColor White
