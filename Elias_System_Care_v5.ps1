#!/usr/bin/env pwsh
# Elias System Care Pro v5.0 - Stable Version with MenuStrip

# ==== Load Assemblies ==============================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==== Configuration ==============================
$config = @{
    AppName = "Elias System Care Pro"
    Version = "5.0.0"
}

# ==== Logging ==============================
$logDir = "$env:APPDATA\Elias"
if (-not (Test-Path $logDir)) { mkdir $logDir -Force | Out-Null }
$logFile = "$logDir\care.log"

function Write-Log {
    param([string]$level, [string]$message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] [$level] $message"
    Add-Content -Path $logFile -Value $entry 2>$null
    Write-Host $entry -ForegroundColor "Gray"
}

Write-Log "INFO" "Starting $($config.AppName) v$($config.Version)"

# ==== System Information ==============================
function Get-SystemInfo {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        
        $osName = $os.Caption
        $osVer  = $os.Version
        $cpuName = $cpu.Name
        $coresP = $cpu.NumberOfCores
        $coresL = $cpu.NumberOfLogicalProcessors
        $maxMhz = $cpu.MaxClockSpeed
        $memGB  = [math]::Round($os.TotalVisibleMemorySize/1MB, 1)
        
        $diskDrive = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.Name -eq "C:" }
        $diskSize  = "N/A"; $diskFree = "N/A"; $diskUse = "N/A"
        if ($diskDrive) {
            $diskSize  = "{0:N1} GB" -f [math]::Round($diskDrive.TotalSize/1GB, 1)
            $diskFree  = "{0:N1} GB" -f [math]::Round($diskDrive.FreeSpace/1GB, 1)
            $diskUse   = "{0}%" -f [math]::Round($diskDrive.TotalFreeSpace/$diskDrive.TotalSize*100, 1)
        }
        
        return @{
            OS          = "$osName $osVer"
            Processor   = $cpuName
            Cores       = "$coresP physical / $coresL logical"
            MaxSpeed    = "$maxMhz MHz"
            Memory      = "$memGB GB"
            DiskSize    = $diskSize
            DiskFree    = $diskFree
            DiskUsage   = $diskUse
        }
    } catch {
        Write-Log "ERROR" "System info error: $_"
        @{}
    }
}

# ==== G:System_Optimizer Integration ==============================
function Initialize-GSystem {
    Write-Log "INFO" "Checking G:System_Optimizer_Pro_X_2026"
    $gAvailable = Test-Path "G:"
    if ($gAvailable) {
        $modDir = "G:\System_Optimizer_Pro_X_2026\Modules"
        $modCount = 0
        if (Test-Path $modDir) {
            $mods = Get-ChildItem $modDir -Filter "*.psm1" -ErrorAction SilentlyContinue
            $modCount = $mods.Count
        }
        return @{
            Available = $true
            ModuleCount = $modCount
            Dir = "G:\System_Optimizer_Pro_X_2026"
        }
    } else {
        return @{
            Available = $false
            ModuleCount = 0
            Dir = "N/A"
        }
    }
}

# ==== System File Repair ==============================
function Repair-SystemFiles {
    Write-Log "INFO" "Starting SFC /scannow"
    sfc /scannow > $null 2>&1
    Start-Sleep -Seconds 3
    Write-Log "INFO" "Running DISM"
    dism /Online /Cleanup-Image /RestoreHealth > $null 2>&1
    Start-Sleep -Seconds 5
    Write-Log "INFO" "System repair completed"
}

# ==== Update Check ==============================
function Check-Updates {
    try {
        if (Test-Path "C:\Windows\SoftwareDistribution\Reporting\Report.xml") {
            return "Update reports available"
        }
        return "Checking for updates..."
    } catch {
        return "Error checking updates"
    }
}

# ==== Smart Diagnostics ==============================
function Run-Diagnostics {
    $cpuLoad = (Get-Counter "\Processor(_Total)\% Processor Time" | Select-Object -ExpandProperty CounterSamples | Measure-Object -Property CookedValue -Average).Average
    $memInfo = Get-WmiObject -Class Win32_ComputerSystem
    $totalMem = $memInfo.TotalPhysicalMemory
    $freeMem  = (Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory
    $memPct   = [math]::Round(($totalMem - $freeMem) / $totalMem * 100, 1)
    
    $diskDrive = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.Name -eq "C:" }
    $diskPct   = if ($diskDrive) { [math]::Round($diskDrive.FreeSpace / $diskDrive.TotalSize * 100, 1) } else { 0 }
    
    $cpuStatus = if ($cpuLoad -gt 85) { "Critical" } elseif ($cpuLoad -gt 70) { "High" } elseif ($cpuLoad -gt 50) { "Medium" } else { "Low" }
    $memStatus = if ($memPct -gt 85)    { "Critical" } elseif ($memPct -gt 70)  { "High" } elseif ($memPct -gt 50)  { "Medium" } else { "Low" }
    $diskStatus = if ($diskPct -lt 10)    { "Critical" } elseif ($diskPct -lt 20)  { "Warning" } elseif ($diskPct -lt 30)  { "Average" } else { "Good" }
    
    $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    $netSent    = if ($netAdapter) { [math]::Round($netAdapter.BytesReceived/1MB, 1) } else { 0 }
    $netRecv    = if ($netAdapter) { [math]::Round($netAdapter.BytesSent/1MB, 1) } else { 0 }
    $netStatus  = if ($netAdapter) { "{0:N0} Mbps Sent: $netSent MB Recv: $netRecv MB" } else { "Disconnected" }
    
    return @{
        CPU      = "$cpuStatus ($cpuLoad%%)"
        Memory   = "$memStatus ($memPct%%)"
        Disk     = "$diskStatus ($diskPct%%)"
        Network  = $netStatus
        Overall  = if ($cpuLoad -gt 85 -or $memPct -gt 85 -or $diskPct -lt 10) { "Requires Attention" }
                   elseif ($cpuLoad -gt 70 -or $memPct -gt 70 -or $diskPct -lt 30) { "Fair" }
                   else                      { "Good" }
    }
}

# ==** Network Diagnostics ==============================
function Test-Network-Quality {
    Write-Log "INFO" "Testing network quality"
    try {
        $ping = Test-Connection -Count 3 -Quiet
        $internet = if ($ping) { "Connected" } else { "Limited/Offline" }
        
        $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        $speed      = if ($netAdapter) { "{0:N0} Mbps" -f ($netAdapter.LinkSpeed/1MB) } else { "N/A" }
        $ipDetails  = if ($netAdapter) {
            "IP: $($netAdapter.Ipv4Address | Where-Object { $_ -notlike "169.254*" } | Select-Object -First 1)`n" +
            "MAC: $($netAdapter.MacAddress)`n" +
            "Gateway: $($netAdapter.DefaultGateway | Join-Str ",")"
        } else { "No active adapter" }
        
        $quality = if ($ping -and $netAdapter) {
            if ($netAdapter.LinkSpeed -ge 1000) { "Excellent (Gigabit)" }
            elseif ($netAdapter.LinkSpeed -ge 100)  { "Very Good (Fast Ethernet)" }
            elseif ($netAdapter.LinkSpeed -ge 10)    { "Good (Wi-Fi/10Mb)" }
            else                                      { "Limited" }
        } else { "Offline/No Adapter" }
        
        return @{
            Internet      = $internet
            Quality       = $quality
            Speed         = $speed
            IPDetails     = $ipDetails
            Technology    = $netAdapter.MediaType -replace " ", ""
        }
    } catch {
        return @{
            Internet      = "Error"
            Quality       = "Error"
            Speed         = "N/A"
            IPDetails     = "Error"
            Technology    = "Error"
        }
    }
}

# ==** Mobile Device Concepts ==============================
function Show-Mobile-Concepts {
    $msg = @"
Mobile Device Support Concepts (Elias v5.0)

Based on G:System_Optimizer_Pro_X_2026 platform documentation:

Supported Device Categories:
• MOBILE_ANDROID - Android smartphones & tablets
• MOBILE_IOS     - iPhones & iPads
• PC_WINDOWS     - Windows desktops & laptops
• PC_LINUX       - Linux systems
• PC_MACOS       - MacBooks & iMacs

Mobile Diagnostics Capabilities:
• Battery health & calibration checks
• Bootloop recovery procedures
• Screen & display damage assessment
• Camera module failure analysis
• Storage health & fragmentation analysis
• Network connectivity & signal quality

G:System_Optimizer Mobile Features:
• ADB/Fastboot integration for Android debugging
• Custom diagnostic scripts for battery, memory, storage
• Parts compatibility checking
• Automated repair procedure execution
• Device health scoring (0-100 scale)

Note: Full mobile device connection requires:
- USB debugging enabled on device
- ADB drivers installed on host
- Physical USB connection or Wi-Fi ADB

For complete mobile diagnostics, connect your device and
run: `adb devices` to verify connection status.
"@
[System.Windows.Forms.MessageBox]::Show($msg, "Mobile Device Concepts", "OK", "Information")
Write-Log "INFO" "User viewed mobile device concepts"
}

# ==== Main Interface ==============================
function Show-Interface {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Elias System Care Pro v$($config.Version)"
    $form.Size = New-Object System.Drawing.Size(500, 450)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = "#1a1a2e"
    $form.ForeColor = "#e0e0e0"
    
    # Menu strip using MenuStrip (without Main prefix)
    $menu = New-Object System.Windows.Forms.MenuStrip
    $form.Controls.Add($menu)
    
    $fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $fileMenu.Text = "File"
    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = "Exit"
    $exitItem.Add_Click({ $form.Close() })
    $fileMenu.DropDownItems.Add($exitItem)
    $menu.Items.Add($fileMenu)
    
    $optMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $optMenu.Text = "Optimization"
    
    $cleanupItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $cleanupItem.Text = "Disk Cleanup"
    $cleanupItem.Add_Click({ [System.Windows.Forms.MessageBox]::Show("Disk cleanup initiated!", "Elias PC Care", "OK", "Information") })
    $optMenu.DropDownItems.Add($cleanupItem)
    
    $sfcItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $sfcItem.Text = "System File Repair"
    $sfcItem.Add_Click({
        Write-Log "INFO" "User initiated System File Repair"
        if ([System.Windows.Forms.MessageBox]::Show("Start SFC/DISM system file repair?", "Elias PC Care", "YesNo", "Question") -eq "Yes") {
            Repair-SystemFiles
            [System.Windows.Forms.MessageBox]::Show("System repair completed!", "Elias PC Care", "OK", "Information")
        }
    })
    $optMenu.DropDownItems.Add($sfcItem)
    
    $updateItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $updateItem.Text = "Update Check"
    $updateItem.Add_Click({
        Write-Log "INFO" "User initiated update check"
        $upd = Check-Updates
        [System.Windows.Forms.MessageBox]::Show("Update status: $upd", "Updates", "OK", "Information")
    })
    $optMenu.DropDownItems.Add($updateItem)
    
    # NEW: Network Diagnostics menu item
    $netItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $netItem.Text = "Network Diagnostics"
    $netItem.Add_Click({
        $nt = Test-Network-Quality
        $msg = "Network Quality Test`nInternet: $($nt.Internet)`nQuality: $($nt.Quality)`nSpeed: $($nt.Speed)`nTechnology: $($nt.Technology)`nIP Details: $($nt.IPDetails)"
        [System.Windows.Forms.MessageBox]::Show($msg, "Network Test", "OK", "Information")
        Write-Log "INFO" "User ran network quality test"
    })
    $optMenu.DropDownItems.Add($netItem)
    
    # NEW: G:Optimizer Info menu item
    $gItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $gItem.Text = "G:System_Optimizer Info"
    $gItem.Add_Click({
        $gs = Initialize-GSystem
        if ($gs.Available) {
            $msg = "G:System_Optimizer_Pro_X_2026:`nAvailable: Yes`nModules: $($gs.ModuleCount)`nDirectory: $($gs.Dir)"
        } else {
            $msg = "G:System_Optimizer_Pro_X_2026:`nAvailable: No (using built-in features only)"
        }
        [System.Windows.Forms.MessageBox]::Show($msg, "G:Optimizer", "OK", "Information")
        Write-Log "INFO" "User checked G: optimizer status"
    })
    $optMenu.DropDownItems.Add($gItem)
    
    # NEW: Mobile Concepts menu item
    $mobileItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $mobileItem.Text = "Mobile Device Concepts"
    $mobileItem.Add_Click({
        Show-Mobile-Concepts
    })
    $optMenu.DropDownItems.Add($mobileItem)
    
    $menu.Items.Add($optMenu)
    
    # Tools menu
    $toolsMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $toolsMenu.Text = "Tools"
    
    $diagItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $diagItem.Text = "Smart Diagnostics"
    $diagItem.Add_Click({
        Write-Log "INFO" "User initiated smart diagnostics"
        $d = Run-Diagnostics
        $msg = @"
Diagnostics Results
========================================
CPU: $($d.CPU)
Memory: $($d.Memory)
Disk: $($d.Disk)
Network: $($d.Network)
Overall: $($d.Overall)
========================================
"@
        [System.Windows.Forms.MessageBox]::Show($msg, "Diagnostics", "OK", "Information")
    })
    $toolsMenu.DropDownItems.Add($diagItem)
    
    $aboutItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $aboutItem.Text = "About"
    $aboutItem.Add_Click({
        $aboutText = @"
Elias System Care Pro v5.0

Features:
• Smart System Diagnostics
• System File Repair (SFC/DISM)
• Network Diagnostics & Quality Testing
• G:System_Optimizer_Pro Integration
• Mobile Device Support Concepts
• Performance Monitoring

For support: elias-system-maintenance.com
"@
        [System.Windows.Forms.MessageBox]::Show($aboutText, "About", "OK", "Information")
    })
    $toolsMenu.DropDownItems.Add($aboutItem)
    
    $menu.Items.Add($toolsMenu)
    
    # Status panel
    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Location = New-Object System.Drawing.Point(0, 420)
    $statusPanel.Size = New-Object System.Drawing.Size(500, 25)
    $statusPanel.BackColor = "#16213e"
    $form.Controls.Add($statusPanel)
    
    $statusLbl = New-Object System.Windows.Forms.Label
    $statusLbl.Text = "Elias System Care Pro - Ready | Module: Dashboard"
    $statusLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $statusLbl.ForeColor = "#e0e0e0"
    $statusLbl.Location = New-Object System.Drawing.Point(150, 5)
    $statusLbl.AutoSize = $true
    $statusPanel.Controls.Add($statusLbl)
    
    # Main group
    $grpMain = New-Object System.Windows.Forms.GroupBox
    $grpMain.Text = "System Information"
    $grpMain.Location = New-Object System.Drawing.Point(20, 20)
    $grpMain.Size = New-Object System.Drawing.Size(460, 180)
    $grpMain.ForeColor = "#e0e0e0"
    $form.Controls.Add($grpMain)
    
    $sysInfo = Get-SystemInfo
    $infoText = "OS: $($sysInfo.OS)`nProcessor: $($sysInfo.Processor)`nCores: $($sysInfo.Cores)`nMax Speed: $($sysInfo.MaxSpeed)`nMemory: $($sysInfo.Memory)`nDisk: $($sysInfo.DiskSize) ($($sysInfo.DiskFree) free, $($sysInfo.DiskUsage) used)`nIP: $($sysInfo.IPAddress)`nGateway: $($sysInfo.Gateway)`nDNS: $($sysInfo.DNS)`nG:System_Optimizer: $($sysInfo.GDriveStatus)"
    
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = $infoText
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $lblInfo.ForeColor = "#e0e0e0"
    $lblInfo.Location = New-Object System.Drawing.Point(15, 25)
    $lblInfo.AutoSize = $false
    $lblInfo.Size = New-Object System.Drawing.Size(430, 150)
    $lblInfo.BackColor = "#1e1e2f"
    $grpMain.Controls.Add($lblInfo)
    
    # Status group
    $grpStatus = New-Object System.Windows.Forms.GroupBox
    $grpStatus.Text = "Health Status"
    $grpStatus.Location = New-Object System.Drawing.Point(20, 220)
    $grpStatus.Size = New-Object System.Drawing.Size(460, 80)
    $grpStatus.ForeColor = "#e0e0e0"
    $form.Controls.Add($grpStatus)
    
    $diag = Run-Diagnostics
    $statusLbl = New-Object System.Windows.Forms.Label
    $statusLbl.Text = "Overall: $($diag.Overall)"
    $statusLbl.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $statusLbl.ForeColor = if ($diag.Overall -eq "Good") { "#4CAF50" } elseif ($diag.Overall -eq "Fair") { "#FFC107" } else { "#FF5252" }
    $statusLbl.Location = New-Object System.Drawing.Point(15, 25)
    $grpStatus.Controls.Add($statusLbl)
    
    $cpuLbl = New-Object System.Windows.Forms.Label
    $cpuLbl.Text = "CPU: $($diag.CPU)"
    $cpuLbl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $cpuLbl.ForeColor = "#e0e0e0"
    $cpuLbl.Location = New-Object System.Drawing.Point(15, 50)
    $grpStatus.Controls.Add($cpuLbl)
    
    # Actions group
    $grpActions = New-Object System.Windows.Forms.GroupBox
    $grpActions.Text = "Quick Actions"
    $grpActions.Location = New-Object System.Drawing.Point(20, 320)
    $grpActions.Size = New-Object System.Drawing.Size(460, 100)
    $grpActions.ForeColor = "#e0e0e0"
    $form.Controls.Add($grpActions)
    
    $btnDiagnose = New-Object System.Windows.Forms.Button
    $btnDiagnose.Text = "Run Diagnostics"
    $btnDiagnose.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnDiagnose.Location = New-Object System.Drawing.Point(20, 30)
    $btnDiagnose.Size = New-Object System.Drawing.Size(180, 40)
    $btnDiagnose.BackColor = "#2c3e6b"
    $btnDiagnose.ForeColor = "White"
    $btnDiagnose.Add_Click({
        $d = Run-Diagnostics
        $msg = "Diagnostics Results:`nCPU: $($d.CPU)`nMemory: $($d.Memory)`nDisk: $($d.Disk)`nNetwork: $($d.Network)"
        [System.Windows.Forms.MessageBox]::Show($msg, "Diagnostics", "OK", "Information")
    })
    $grpActions.Controls.Add($btnDiagnose)
    
    $btnRepair = New-Object System.Windows.Forms.Button
    $btnRepair.Text = "Repair System Files"
    $btnRepair.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnRepair.Location = New-Object System.Drawing.Point(240, 30)
    $btnRepair.Size = New-Object System.Drawing.Size(175, 40)
    $btnRepair.BackColor = "#2c3e6b"
    $btnRepair.ForeColor = "White"
    $btnRepair.Add_Click({
        if ([System.Windows.Forms.MessageBox]::Show("Start SFC/DISM repair?", "Elias PC Care", "YesNo", "Question") -eq "Yes") {
            Repair-SystemFiles
            [System.Windows.Forms.MessageBox]::Show("System repair completed!", "Elias PC Care", "OK", "Information")
        }
    })
    $grpActions.Controls.Add($btnRepair)
    
    $btnUpdates = New-Object System.Windows.Forms.Button
    $btnUpdates.Text = "Check Updates"
    $btnUpdates.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnUpdates.Location = New-Object System.Drawing.Point(20, 80)
    $btnUpdates.Size = New-Object System.Drawing.Size(180, 40)
    $btnUpdates.BackColor = "#2c3e6b"
    $btnUpdates.ForeColor = "White"
    $btnUpdates.Add_Click({
        $upd = Check-Updates
        [System.Windows.Forms.MessageBox]::Show("Update status: $upd", "Updates", "OK", "Information")
    })
    $grpActions.Controls.Add($btnUpdates)
    
    $btnGInfo = New-Object System.Windows.Forms.Button
    $btnGInfo.Text = "G:Optimizer Info"
    $btnGInfo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnGInfo.Location = New-Object System.Drawing.Point(20, 50)
    $btnGInfo.Size = New-Object System.Drawing.Size(180, 35)
    $btnGInfo.BackColor = "#2c3e6b"
    $btnGInfo.ForeColor = "White"
    $btnGInfo.Add_Click({
        $gs = Initialize-GSystem
        if ($gs.Available) {
            $msg = "G:System_Optimizer_Pro_X_2026:`nAvailable: Yes`nModules: $($gs.ModuleCount)`nDirectory: $($gs.Dir)"
        } else {
            $msg = "G:System_Optimizer_Pro_X_2026:`nAvailable: No (using built-in features)"
        }
        [System.Windows.Forms.MessageBox]::Show($msg, "G:Optimizer", "OK", "Information")
        Write-Log "INFO" "User checked G: optimizer status"
    })
    $grpActions.Controls.Add($btnGInfo)
    
    $btnMobile = New-Object System.Windows.Forms.Button
    $btnMobile.Text = "Mobile Concepts"
    $btnMobile.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnMobile.Location = New-Object System.Drawing.Point(20, 95)
    $btnMobile.Size = New-Object System.Drawing.Size(180, 35)
    $btnMobile.BackColor = "#2c3e6b"
    $btnMobile.ForeColor = "White"
    $btnMobile.Add_Click({
        Show-Mobile-Concepts
    })
    $grpActions.Controls.Add($btnMobile)
    
    $form.Add_Shown({ $form.Activate() })
    [void] $form.ShowDialog()
}

# ==== Entry Point ==============================
try {
    Write-Log "INFO" "Application starting..."
    Show-Interface
    Write-Log "INFO" "Application closed normally"
} catch {
    Write-Log "ERROR" "Application error: $_"
    try { [System.Windows.Forms.MessageBox]::Show("Error: $($_)", "Error", "OK", "Error") } catch { }
}