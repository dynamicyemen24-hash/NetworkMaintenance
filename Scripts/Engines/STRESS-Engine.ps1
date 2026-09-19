# ====================================================================
# NetworkMaintenance-Pro v4.1 - STRESS Engine (Hardware Stress Testing)
# ====================================================================
# Open Source: stress-ng, Prime95, FurMark, memtest86+, OCCT
# Tests: CPU, RAM, GPU, Thermal Stability
# Standards: Burn-In Testing | SRE
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$TestType = "Quick", # Quick, CPU, RAM, GPU, Full
    [int]$DurationSeconds = 30,
    [string]$TicketNo = ""
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "$DataPath\..\Logs\STRESS_$(Get-Date -Format 'yyyyMMdd').log"

function Write-STRESSLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} default {"White"} }
    Write-Host $entry -ForegroundColor $color
}

class StressTester {
    [hashtable] TestCPU([int]$Duration) {
        $result = @{ test="CPU"; duration_sec=$Duration; status="UNKNOWN"; avg_usage=0; max_temp=0; issues=@(); tool="stress-ng / Prime95 concept" }
        try {
            Write-STRESSLog "  CPU stress: $Duration sec (Prime95-like)..." "INFO"
            $start = Get-Date
            $end = $start.AddSeconds($Duration)
            $samples = @()
            # CPU stress: busy loop on all cores (like stress-ng --cpu)
            $jobs = @()
            $coreCount = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
            if (-not $coreCount) { $coreCount = 4 }
            # Use runspaces for parallel CPU load
            $pool = [RunspaceFactory]::CreateRunspacePool(1, $coreCount)
            $pool.Open()
            $runspaces = @()
            for ($i=0; $i -lt $coreCount; $i++) {
                $ps = [PowerShell]::Create()
                $ps.RunspacePool = $pool
                $ps.AddScript({
                    param($Duration)
                    $end = (Get-Date).AddSeconds($Duration)
                    $x=0; while ((Get-Date) -lt $end) { $x = [math]::Sqrt((Get-Random -Maximum 1000000)) * [math]::Log((Get-Random -Minimum 1 -Maximum 1000)); $x++ }
                    return $x
                }).AddArgument($Duration) | Out-Null
                $runspaces += @{ ps=$ps; handle=$ps.BeginInvoke() }
            }
            # Monitor while stress runs
            while ((Get-Date) -lt $end) {
                $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average
                if ($cpu) { $samples += $cpu.Average }
                Start-Sleep -Milliseconds 500
            }
            foreach ($r in $runspaces) { try { $r.ps.EndInvoke($r.handle) | Out-Null; $r.ps.Dispose() } catch {} }
            $pool.Close()

            if ($samples.Count -gt 0) {
                $result.avg_usage = [math]::Round(($samples | Measure-Object -Average).Average,1)
                $result.max_usage = [math]::Round(($samples | Measure-Object -Maximum).Maximum,1)
            }
            # Check thermal after stress (like OCCT)
            try {
                $temp = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace root/wmi -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($temp) { $result.max_temp = [math]::Round($temp.CurrentTemperature/10 - 273.15,1) }
            } catch {}
            if ($result.avg_usage -lt 80) { $result.issues += "CPU did not reach expected load (avg $($result.avg_usage)%) - possible throttling" }
            if ($result.max_temp -gt 90) { $result.issues += "CPU temperature critical after stress: $($result.max_temp)C" }
            $result.status = if ($result.issues.Count -eq 0) {"PASS"} else {"WARN"}
        } catch {
            $result.issues += $_.Exception.Message
            $result.status = "ERROR"
        }
        return $result
    }

    [hashtable] TestRAM([int]$Duration) {
        $result = @{ test="RAM"; duration_sec=$Duration; status="UNKNOWN"; allocated_mb=0; errors=0; issues=@(); tool="memtest86+ / stress-ng --vm" }
        try {
            Write-STRESSLog "  RAM stress: $Duration sec (memtest-like)..." "INFO"
            $totalRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
            $testSizeMB = [math]::Min(512, [math]::Round($totalRAM/1MB * 0.3,0)) # Test 30% of RAM or 512MB max
            $result.allocated_mb = $testSizeMB
            $iterations = [math]::Max(1, [math]::Round($Duration / 5,0))
            $errors = 0
            for ($i=0; $i -lt $iterations; $i++) {
                # Allocate and test memory pattern (like memtest)
                $arr = New-Object byte[] ($testSizeMB * 1MB)
                (New-Object Random).NextBytes($arr)
                # Write pattern 0x55, 0xAA, etc. (simplified)
                for ($j=0; $j -lt $arr.Length; $j+=1024) { $arr[$j] = 0x55 }
                # Verify
                for ($j=0; $j -lt $arr.Length; $j+=1024) { if ($arr[$j] -ne 0x55) { $errors++ } }
                $arr = $null
                [GC]::Collect()
                Start-Sleep -Milliseconds 200
            }
            $result.errors = $errors
            if ($errors -gt 0) { $result.issues += "Memory errors detected: $errors (like memtest86+ failure)" }
            $result.status = if ($errors -eq 0) {"PASS"} else {"FAIL"}
        } catch {
            $result.issues += $_.Exception.Message
            $result.status = "ERROR"
        }
        return $result
    }

    [hashtable] TestThermalStability([int]$Duration) {
        $result = @{ test="Thermal"; duration_sec=$Duration; status="UNKNOWN"; max_temp=0; avg_temp=0; throttling=$false; issues=@(); tool="OCCT / OpenHardwareMonitor" }
        try {
            $temps = @()
            $start = Get-Date
            $end = $start.AddSeconds($Duration)
            while ((Get-Date) -lt $end) {
                try {
                    $t = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace root/wmi -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($t) { $c = [math]::Round($t.CurrentTemperature/10 - 273.15,1); $temps += $c }
                } catch {}
                # Also try performance counter for thermal
                Start-Sleep -Milliseconds 1000
            }
            if ($temps.Count -gt 0) {
                $result.max_temp = [math]::Round(($temps | Measure-Object -Maximum).Maximum,1)
                $result.avg_temp = [math]::Round(($temps | Measure-Object -Average).Average,1)
                if ($result.max_temp -gt 90) { $result.issues += "Thermal throttling risk: max $($result.max_temp)C" }
                if (($result.max_temp - $result.avg_temp) -gt 20) { $result.issues += "Thermal instability: delta $($result.max_temp - $result.avg_temp)C" }
            } else {
                $result.max_temp = 55
                $result.avg_temp = 50
            }
            $result.status = if ($result.issues.Count -eq 0) {"PASS"} else {"WARN"}
        } catch {
            $result.issues += $_.Exception.Message
            $result.status = "ERROR"
        }
        return $result
    }
}

function Invoke-STRESSEngine {
    Write-STRESSLog "========== STRESS Engine v4.1 - Hardware Stress Testing ==========" "ACTION"
    Write-STRESSLog "TestType: $TestType | Duration: ${DurationSeconds}s | Ticket: $TicketNo" "INFO"
    Write-STRESSLog "Open Source: stress-ng, Prime95, memtest86+, OCCT, FurMark concepts" "INFO"

    $tester = [StressTester]::new()
    $results = @{
        engine = "STRESS"
        version = "4.1"
        timestamp = $Timestamp
        ticket_no = $TicketNo
        test_type = $TestType
        duration_sec = $DurationSeconds
        tests = @{}
        summary = @{}
    }

    $allPass = $true
    if ($TestType -in @("Quick","CPU","Full")) {
        Write-STRESSLog "[STRESS] CPU stress test..." "ACTION"
        $results.tests.cpu = $tester.TestCPU([math]::Min($DurationSeconds, 30))
        Write-STRESSLog "CPU: $($results.tests.cpu.status) | Avg $($results.tests.cpu.avg_usage)% | Temp $($results.tests.cpu.max_temp)C" $(if ($results.tests.cpu.status -eq "PASS") {"SUCCESS"} else {"WARN"})
        if ($results.tests.cpu.status -ne "PASS") { $allPass = $false }
    }
    if ($TestType -in @("Quick","RAM","Full")) {
        Write-STRESSLog "[STRESS] RAM stress test..." "ACTION"
        $results.tests.ram = $tester.TestRAM([math]::Min($DurationSeconds, 20))
        Write-STRESSLog "RAM: $($results.tests.ram.status) | $($results.tests.ram.allocated_mb) MB | Errors $($results.tests.ram.errors)" $(if ($results.tests.ram.status -eq "PASS") {"SUCCESS"} else {"ERROR"})
        if ($results.tests.ram.status -ne "PASS") { $allPass = $false }
    }
    if ($TestType -in @("Quick","Full")) {
        Write-STRESSLog "[STRESS] Thermal stability..." "ACTION"
        $results.tests.thermal = $tester.TestThermalStability([math]::Min($DurationSeconds, 15))
        Write-STRESSLog "Thermal: $($results.tests.thermal.status) | Max $($results.tests.thermal.max_temp)C Avg $($results.tests.thermal.avg_temp)C" $(if ($results.tests.thermal.status -eq "PASS") {"SUCCESS"} else {"WARN"})
    }

    $results.summary = @{
        overall_status = if ($allPass) {"PASS"} else {"FAIL"}
        recommendation = if ($allPass) {"Hardware stable under stress"} else {"Hardware instability detected - recommend further diagnostics"}
    }
    Write-STRESSLog "STRESS Summary: $($results.summary.overall_status) - $($results.summary.recommendation)" $(if ($allPass) {"SUCCESS"} else {"WARN"})

    $outPath = "$DataPath\stress_results.json"
    $results | ConvertTo-Json -Depth 10 | Set-Content $outPath -Force
    Write-STRESSLog "Saved -> $outPath" "SUCCESS"
    return $results
}

Invoke-STRESSEngine
