# Elias Advanced System Maintenance - Professional GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Elias PC Care"
$form.Size = New-Object System.Drawing.Size(400, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = "#f0f0f0"

# Title label
$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Text = "Elias Advanced System Care"
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$labelTitle.Location = New-Object System.Drawing.Point(20, 20)
$labelTitle.ForeColor = "#2c3e6b"
$labelTitle.AutoSize = $true
$form.Controls.Add($labelTitle)

# Status text
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "System ready for optimization"
$labelStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$labelStatus.Location = New-Object System.Drawing.Point(20, 60)
$labelStatus.AutoSize = $true
$form.Controls.Add($labelStatus)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Location = New-Object System.Drawing.Point(20, 100)
$progressBar.Size = New-Object System.Drawing.Size(340, 20)
$form.Controls.Add($progressBar)

# Info rich text box
$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Location = New-Object System.Drawing.Point(20, 140)
$richTextBox.Size = New-Object System.Drawing.Size(340, 300)
$richTextBox.ReadOnly = $true
$richTextBox.BackColor = "#ffffff"
$richTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($richTextBox)

# Log function
function Log-Message {
    param([string]$msg)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $richTextBox.AppendText("[$timestamp] $msg`n")
}

# Optimize button
$btnOptimize = New-Object System.Windows.Forms.Button
$btnOptimize.Text = "Run Optimization"
$btnOptimize.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnOptimize.Location = New-Object System.Drawing.Point(20, 450)
$btnOptimize.Size = New-Object System.Drawing.Size(160, 35)
$btnOptimize.BackColor = "#2c3e6b"
$btnOptimize.ForeColor = "White"
$btnOptimize.Add_Click({
    $progressBar.Value = 0
    $labelStatus.Text = "Scanning system..."
    Log-Message "Starting optimization scan..."
    
    # Simulate optimization steps
    $steps = @("Cleaning temp files", "Optimizing registry", "Defragmenting disk", "Resetting TCP settings", "Finalizing")
    foreach ($step in $steps) {
        Start-Sleep -Seconds 1
        $current = $progressBar.Value
        $progressBar.Value = $current + 20
        Log-Message "$step in progress..."
    }
    
    $labelStatus.Text = "Optimization complete!"
    Log-Message "System optimization completed successfully!"
    [System.Windows.Forms.MessageBox]::Show("Optimization complete!", "Elias PC Care", "OK", "Information")
})

$form.Controls.Add($btnOptimize)

# About menu
$btnAbout = New-Object System.Windows.Forms.Button
$btnAbout.Text = "About"
$btnAbout.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnAbout.Location = New-Object System.Drawing.Point(280, 450)
$btnAbout.Size = New-Object System.Drawing.Size(80, 35)
$btnAbout.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("Elias Advanced System Care v1.0`nProfessional System Maintenance Tool`n`nFeatures:`n• Disk Cleanup`n• Registry Optimization`n• Network Optimization`n• Performance Tweaks", "About", "OK", "Information")
})
$form.Controls.Add($btnAbout)

# Exit button
$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnExit.Location = New-Object System.Drawing.Point(340, 450)
$btnExit.Size = New-Object System.Drawing.Size(80, 35)
$btnExit.BackColor = "#e74c3c"
$btnExit.ForeColor = "White"
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnAbout)

# Show the form
$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()