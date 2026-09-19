# ====================================================================
# NetworkMaintenance-Pro v4.1 - Open Source Toolkit Detector
# ====================================================================
# Auto-detects open source tools and provides wrappers
# Projects: smartctl, ADB, HWiNFO, CrystalDiskInfo, iperf3, nmap, etc.
# ====================================================================

param([switch]$InstallGuide, [switch]$Json)

$Tools = @{
    "smartctl" = @{ name="smartmontools/smartctl"; desc="SMART disk health"; url="https://www.smartmontools.org/"; check="smartctl --version"; install="choco install smartmontools -y  OR  winget install smartmontools"; category="Storage" }
    "adb" = @{ name="Android Platform-Tools (ADB)"; desc="Android diagnostics"; url="https://developer.android.com/studio/releases/platform-tools"; check="adb --version"; install="choco install adb -y"; category="Mobile" }
    "fastboot" = @{ name="Android fastboot"; desc="Android bootloader"; url="https://developer.android.com/studio/releases/platform-tools"; check="fastboot --version"; install="choco install adb -y"; category="Mobile" }
    "scrcpy" = @{ name="Genymobile/scrcpy"; desc="Android screen mirror"; url="https://github.com/Genymobile/scrcpy"; check="scrcpy --version"; install="choco install scrcpy -y"; category="Mobile" }
    "ideviceinfo" = @{ name="libimobiledevice"; desc="iOS diagnostics"; url="https://libimobiledevice.org/"; check="ideviceinfo --help"; install="choco install libimobiledevice -y (or compile)"; category="Mobile" }
    "hwinfo" = @{ name="OpenHardwareMonitor/HWiNFO"; desc="Hardware sensors"; url="https://openhardwaremonitor.org/ + https://www.hwinfo.com/"; check="OpenHardwareMonitor"; install="Download from openhardwaremonitor.org"; category="Hardware" }
    "CrystalDiskInfo" = @{ name="CrystalDiskInfo"; desc="Disk health GUI"; url="https://crystalmark.info/"; check="DiskInfo64"; install="choco install crystaldiskinfo -y"; category="Storage" }
    "memtest" = @{ name="memtest86+"; desc="RAM testing"; url="https://www.memtest.org/"; check="memtest"; install="Bootable USB - https://www.memtest86.com/"; category="Hardware" }
    "stress-ng" = @{ name="stress-ng"; desc="Stress testing (Linux)"; url="https://github.com/ColinIanKing/stress-ng"; check="stress-ng --version"; install="wsl: apt install stress-ng"; category="Stress" }
    "prime95" = @{ name="Prime95"; desc="CPU stress"; url="https://www.mersenne.org/download/"; check="prime95"; install="Download from mersenne.org"; category="Stress" }
    "iperf3" = @{ name="iperf3"; desc="Bandwidth testing"; url="https://iperf.fr/"; check="iperf3 --version"; install="choco install iperf3 -y"; category="Network" }
    "nmap" = @{ name="nmap"; desc="Port scanning"; url="https://nmap.org/"; check="nmap --version"; install="choco install nmap -y"; category="Network" }
    "wireshark" = @{ name="Wireshark"; desc="Packet analysis"; url="https://www.wireshark.org/"; check="wireshark --version"; install="choco install wireshark -y"; category="Network" }
    "WinMTR" = @{ name="WinMTR"; desc="mtr for Windows"; url="https://github.com/White-Tiger/WinMTR"; check="WinMTR"; install="choco install winmtr -y"; category="Network" }
    "BleachBit" = @{ name="BleachBit"; desc="Safe cleaning (like SCE)"; url="https://www.bleachbit.org/"; check="bleachbit --version"; install="choco install bleachbit -y"; category="Cleaning" }
    "TestDisk" = @{ name="TestDisk/PhotoRec"; desc="Data recovery"; url="https://www.cgsecurity.org/wiki/TestDisk"; check="testdisk /version"; install="choco install testdisk -y"; category="Recovery" }
    "HDDScan" = @{ name="HDDScan"; desc="Disk surface test"; url="http://hddscan.com/"; check="HDDScan"; install="Download from hddscan.com"; category="Storage" }
    "speedtest" = @{ name="speedtest-cli"; desc="Speed test"; url="https://github.com/sivel/speedtest-cli"; check="speedtest --version"; install="pip install speedtest-cli"; category="Network" }
}

$results = @()
foreach ($key in $Tools.Keys | Sort-Object) {
    $tool = $Tools[$key]
    $found = $false
    $version = ""
    try {
        $cmd = $key
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            $found = $true
            try {
                $out = Invoke-Expression "$($tool.check) 2>&1 | Out-String" | Select-Object -First 1
                $version = $out.Trim().Substring(0, [Math]::Min(60, $out.Trim().Length))
            } catch { $version = "found" }
        }
    } catch {}
    $results += [PSCustomObject]@{
        Tool = $key
        Name = $tool.name
        Category = $tool.category
        Installed = $found
        Version = $version
        URL = $tool.url
        Install = $tool.install
    }
}

if ($Json) {
    $results | ConvertTo-Json -Depth 4 | Set-Content "C:\NetworkMaintenance\Data\toolkit_status.json" -Force
    $results | ConvertTo-Json -Depth 4
} elseif ($InstallGuide) {
    Write-Host "========== Open Source Toolkit - Install Guide ==========" -ForegroundColor Cyan
    foreach ($r in $results | Where-Object { -not $_.Installed }) {
        Write-Host "`n$($r.Tool) ($($r.Category)) - NOT INSTALLED" -ForegroundColor Yellow
        Write-Host "  $($r.Name)" -ForegroundColor White
        Write-Host "  Install: $($r.Install)" -ForegroundColor Gray
        Write-Host "  URL: $($r.URL)" -ForegroundColor DarkGray
    }
    Write-Host "`nInstalled: $(($results | Where-Object Installed).Count) / $($results.Count)" -ForegroundColor Green
} else {
    Write-Host "========== Open Source Toolkit Status ==========" -ForegroundColor Cyan
    $results | Format-Table Tool, Category, Installed, Version -AutoSize
    Write-Host "`nInstalled: $(($results | Where-Object Installed).Count) / $($results.Count) | Missing: $(($results | Where-Object {-not $_.Installed}).Count)" -ForegroundColor $(if (($results | Where-Object Installed).Count -ge 5) {"Green"} else {"Yellow"})
    Write-Host "`nFor install guide: .\OpenSourceToolkit.ps1 -InstallGuide" -ForegroundColor Gray
    Write-Host "For JSON: .\OpenSourceToolkit.ps1 -Json" -ForegroundColor Gray
    $results | ConvertTo-Json -Depth 4 | Set-Content "C:\NetworkMaintenance\Data\toolkit_status.json" -Force
}
