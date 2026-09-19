# ====================================================================
# Elias Pro — Device-Diagnostics Module
# تشخيص عميق حقيقي للكمبيوتر والموبايل عبر WMI / SMART / powercfg / ADB
# تُستدعى من خادم Pode (API) وتُوصَل وقتها بالواجهة العربية
# ====================================================================
$script:Root = "C:\NetworkMaintenance"
$script:ReportsDir = "$script:Root\Reports"
$script:HistoryFile = "$script:Root\Data\device-history.json"
$script:HistoryCap = 120

# ---------- أداة آمنة: تنفيذ أمر مع مهلة زمنية ----------
function Invoke-CmdCaptured {
    param(
        [string]$FilePath,
        [string[]]$ArgList,
        [int]$TimeoutSec = 8
    )
    $out = Join-Path $env:TEMP ("elias_out_" + [guid]::NewGuid().ToString("N") + ".txt")
    $err = Join-Path $env:TEMP ("elias_err_" + [guid]::NewGuid().ToString("N") + ".txt")
    $stdout = ""
    try {
        $p = Start-Process -FilePath $FilePath -ArgumentList $ArgList -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -WindowStyle Hidden -PassThru
        $exited = $p.WaitForExit($TimeoutSec * 1000)
        if (-not $exited) { try { $p.Kill() } catch { } }
        if (Test-Path $out) { $stdout = (Get-Content $out -Raw) -replace "`0", "" }
    } catch { $stdout = "" }
    finally {
        Start-Sleep -Milliseconds 120
        Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
    }
    return $stdout
}

# ---------- حقائق النظام (PC) ----------
function Get-DeviceFacts {
    $facts = @{
        os = $null; version = $null; build = $null; arch = $null
        manufacturer = $null; model = $null; system_serial = $null
        cpu = $null; cores = $null; threads = $null; cpu_load = $null
        gpu = $null; motherboard = $null; bios = $null
        total_ram_gb = $null; free_ram_gb = $null; used_ram_gb = $null; used_ram_pct = $null
        uptime_sec = $null; last_boot = $null
        adapters = @()
    }
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $facts.os = $os.Caption; $facts.version = $os.Version
        $facts.build = $os.BuildNumber; $facts.arch = $os.OSArchitecture
        $lastBoot = $os.LastBootUpTime
        $facts.last_boot = $lastBoot.ToString("o")
        $facts.uptime_sec = [int]((Get-Date) - $lastBoot).TotalSeconds
    } catch { }
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        $facts.manufacturer = $cs.Manufacturer; $facts.model = $cs.Model
        $facts.total_ram_gb = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    } catch { }
    try {
        $sp = Get-CimInstance Win32_ComputerSystemProduct
        $facts.system_serial = $sp.IdentifyingNumber
    } catch { }
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $facts.cpu = $cpu.Name; $facts.cores = $cpu.NumberOfCores
        $facts.threads = $cpu.NumberOfLogicalProcessors
        $c1 = 0; $c2 = 0
        try { $c1 = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop).CounterSamples[0].CookedValue } catch { }
        Start-Sleep -Milliseconds 300
        try { $c2 = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop).CounterSamples[0].CookedValue } catch { }
        $facts.cpu_load = [math]::Round($c2, 1)
    } catch { }
    try {
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
        $facts.gpu = $gpu.Name
    } catch { }
    try {
        $mb = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
        $facts.motherboard = (($mb.Manufacturer + ' ' + $mb.Product)).Trim()
    } catch { }
    try {
        $bios = Get-CimInstance Win32_BIOS | Select-Object -First 1
        $facts.bios = $bios.SMBIOSBIOSVersion
    } catch { }
    try {
        $osf = Get-CimInstance Win32_OperatingSystem
        $total = [double]$facts.total_ram_gb * 1GB
        $free = [double]$osf.FreePhysicalMemory * 1KB
        $used = $total - $free
        $facts.free_ram_gb = [math]::Round($free / 1GB, 1)
        $facts.used_ram_gb = [math]::Round($used / 1GB, 1)
        $facts.used_ram_pct = if ($total -gt 0) { [math]::Round(100 * $used / $total, 0) } else { $null }
    } catch { }
    try {
        $nics = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        $facts.adapters = @(foreach ($n in $nics) {
            @{
                name = $n.Name; interface = $n.InterfaceDescription
                mac = $n.MacAddress
                speed_gbps = if ($n.LinkSpeed) { [math]::Round([double]$n.LinkSpeed / 1e9, 2) } else { $null }
            }
        })
    } catch { }
    return $facts
}

# ---------- البطارية (عبر WMI + powercfg /batteryreport الحقيقي) ----------
function Get-DeviceBattery {
    $bat = @{
        present = $false; level_pct = $null; ac_status = $null; charging = $null
        design_mwh = $null; full_mwh = $null; health_pct = $null; cycles = $null; temp_c = $null
    }
    try {
        $wb = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
        if ($wb) {
            $bat.present = $true
            $bat.level_pct = $wb.EstimatedChargeRemaining
            $bat.ac_status = $wb.BatteryStatus
            $bat.charging = ($wb.BatteryStatus -ne 1)
            $bat.temp_c = $null
        }
    } catch { }
    try {
        $st = Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus -ErrorAction Stop | Select-Object -First 1
        if ($st -and $st.Temperature -gt 0) { $bat.temp_c = [math]::Round($st.Temperature / 10) }
    } catch { }
    # تقرير البطارية الحقيقي (يعمل دون صلاحيات إدارية في أغلب الأجهزة)
    $rep = Join-Path $env:TEMP ("elias_batt_" + [guid]::NewGuid().ToString("N") + ".html")
    try {
        & powercfg /batteryreport /output $rep 2>$null | Out-Null
        if (Test-Path $rep) {
            $h = Get-Content $rep -Raw
            # رصد كل الخلايا ذات وحدات mWh مهما كانت لغة التقرير:
            # السطران الأولان عادة التصميمية ثم الكاملة.
            $cells = [regex]::Matches($h, '<td><span class="label">[^<]*</span></td><td>\s*([\d,]+)\s*mWh')
            $nums = @()
            foreach ($c in $cells) {
                $v = [double]($c.Groups[1].Value -replace ',', '')
                if ($v -gt 0) { $nums += $v }
            }
            if ($nums.Count -ge 2) {
                $bat.design_mwh = $nums[0]; $bat.full_mwh = $nums[1]
                if ($nums[0] -gt 0) { $bat.health_pct = [math]::Round(100 * $nums[1] / $nums[0], 0) }
            }
            $cyc = [regex]::Match($h, '<td><span class="label">[^<]*</span></td><td>\s*"?([\d,]+)"?\s*</td>')
            # دورة الشحن (قد تُظهر "-")
            $raw = $h
            $m = [regex]::Match($raw, '<td><span class="label">[^<]*</span></td>\s*<td>\s*<span>\s*-')
            $cyc2 = [regex]::Matches($raw, '<td><span class="label">[^<]*</span></td><td>\s*([\d,]+)\s*</td>')
            # عدد الدورات هو ثالث قيمة رقمية في جدول معلومات البطارية عادة (بعد التصميمية والكاملة)
            $valRows = @()
            foreach ($x in [regex]::Matches($raw, '<td><span class="label">[^<]*</span></td><td>\s*([\d,]+)\s*(?:mWh|)\s*</td>')) {
                $vv = [double]($x.Groups[1].Value -replace ',', '')
                if ($vv -gt 0) { $valRows += $vv }
            }
            if ($valRows.Count -ge 3) {
                # ثالث قيمة غالبًا دورة الشحن؛ تجاهليها إن تزامنت مع القيمة الكاملة (خلية "-" غير رقمية)
                if ([int]$valRows[2] -ne $bat.full_mwh) { $bat.cycles = [int]$valRows[2] }
            }
        }
    } catch { }
    finally {
        Remove-Item -LiteralPath $rep -Force -ErrorAction SilentlyContinue
    }
    return $bat
}

# ---------- التخزين + عداد SMART ----------
function Get-DeviceStorage {
    $disks = @()
    try {
        $pds = Get-PhysicalDisk -ErrorAction Stop
        foreach ($pd in $pds) {
            $d = @{
                index = $pd.DeviceId
                model = $pd.FriendlyName
                serial = $pd.SerialNumber
                size_gb = [math]::Round($pd.Size / 1GB, 1)
                type = $pd.MediaType
                health = $pd.HealthStatus.ToString()
                bus = $pd.BusType.ToString()
                wear_pct = $null; temp_c = $null
                read_errors = $null; write_errors = $null
            }
            try {
                # قد تتطلب صلاحيات إدارية على بعض الأجهزة
                $rc = Get-StorageReliabilityCounter -PhysicalDisk $pd -ErrorAction SilentlyContinue
                if ($rc) {
                    $d.wear_pct = $rc.Wear
                    $d.temp_c = if ($rc.Temperature) { [int]$rc.Temperature } else { $null }
                    $d.read_errors = $rc.ReadErrorsTotal
                    $d.write_errors = $rc.WriteErrorsTotal
                }
            } catch { }
            $disks += $d
        }
    } catch { }
    return $disks
}

# ---------- الحرارة (قد لا تكون معروضة عبر ACPI على أجهزة كثيرة) ----------
function Get-DeviceThermal {
    $t = @{ source = "acpi"; zones = @(); summary = $null }
    try {
        $z = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
        $list = @()
        foreach ($zone in $z) {
            $c = [math]::Round(([int]$zone.CurrentTemperature / 10) - 273)
            if ($c -gt 0) { $list += $c }
        }
        if ($list.Count) {
            $t.zones = $list
            $t.summary = ($list | Measure-Object -Maximum).Maximum
        } else { $t.source = "acpi-empty" }
    } catch { $t.source = "not-exposed" }
    return $t
}

# ---------- أهم العمليات (قياس حقيقي بفارق زمني) ----------
function Get-TopProcesses {
    $p0 = @{}; $p1 = @{}
    try { Get-Process | ForEach-Object { $p0[$_.Id] = @{ cpu = $_.CPU; mem = $_.WorkingSet64; name = $_.ProcessName } } } catch { }
    Start-Sleep -Milliseconds 600
    try { Get-Process | ForEach-Object { $p1[$_.Id] = @{ cpu = $_.CPU; mem = $_.WorkingSet64; name = $_.ProcessName } } } catch { }
    $cores = 0
    try { $cores = (Get-CimInstance Win32_Processor | Select-Object -First 1).NumberOfLogicalProcessors } catch { $cores = 1 }
    $rows = @()
    foreach ($id in $p1.Keys) {
        if (-not $p0.ContainsKey($id)) { continue }
        $dCpu = [double]$p1[$id].cpu - [double]$p0[$id].cpu
        if ($dCpu -lt 0) { $dCpu = 0 }
        $cpuPct = [math]::Round(100 * $dCpu / 0.6 / $cores, 1)
        $rows += [pscustomobject]@{
            name = $p1[$id].name
            pid = $id
            cpu_pct = $cpuPct
            mem_mb = [math]::Round($p1[$id].mem / 1MB, 0)
        }
    }
    $rows = @($rows | Sort-Object cpu_pct -Descending | Select-Object -First 10)
    return @($rows | ForEach-Object {
        @{ name = $_.name; pid = $_.pid; cpu_pct = $_.cpu_pct; mem_mb = $_.mem_mb }
    })
}

# ---------- تشخيص الموبايل Android عبر ADB ----------
function Find-Adb {
    $cand = @()
    try { $c = Get-Command adb -ErrorAction SilentlyContinue; if ($c) { $cand += $c.Source } } catch { }
    $paths = @(
        "$script:Root\Scripts\Tools\adb.exe",
        "$script:Root\Scripts\Tools\platform-tools\adb.exe",
        "$script:Root\Tools\platform-tools\adb.exe",
        "$script:Root\Dist\adb.exe",
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "C:\Android\platform-tools\adb.exe",
        "C:\adb\adb.exe"
    )
    foreach ($p in $paths) { if (Test-Path -LiteralPath $p) { $cand += $p } }
    if ($cand.Count) { return $cand | Select-Object -First 1 }
    return $null
}

function Get-AndroidFacts {
    $res = @{ adb_available = $false; adb_path = $null; error = $null; devices = @() }
    $adb = Find-Adb
    if (-not $adb) {
        $res.error = "adb غير مثبت — ثبّت platform-tools عبر OpenSourceToolkit أو أدرجه في Dist\platform-tools"
        return $res
    }
    $res.adb_available = $true
    $res.adb_path = $adb
    $out = Invoke-CmdCaptured -FilePath $adb -ArgumentList @("devices") -TimeoutSec 10
    $ids = @()
    foreach ($ln in ($out -split "`r?`n")) {
        if ($ln -match '^([a-zA-Z0-9_.:]+)\s+device\s*$') { $ids += $Matches[1] }
        elseif ($ln -match '^no devices') { break }
    }
    foreach ($id in $ids) {
        $dev = @{ id = $id; model = $null; brand = $null; android = $null; sdk = $null;
                  battery_level = $null; battery_temp_c = $null; battery_health = $null; battery_health_txt = $null;
                  storage_total_gb = $null; storage_free_gb = $null; connected = $false }
        $model = Invoke-CmdCaptured -FilePath $adb -ArgumentList @("-s", $id, "shell", "getprop", "ro.product.model") -TimeoutSec 6
        $brand = Invoke-CmdCaptured -FilePath $adb -ArgumentList @("-s", $id, "shell", "getprop", "ro.product.brand") -TimeoutSec 6
        $ver = Invoke-CmdCaptured -FilePath $adb -ArgumentList @("-s", $id, "shell", "getprop", "ro.build.version.release") -TimeoutSec 6
        $sdk = Invoke-CmdCaptured -FilePath $adb -ArgumentList @("-s", $id, "shell", "getprop", "ro.build.version.sdk") -TimeoutSec 6
        $dev.model = (($model -split "`r?`n" | Select-Object -First 1).Trim())
        $dev.brand = (($brand -split "`r?`n" | Select-Object -First 1).Trim())
        $dev.android = (($ver -split "`r?`n" | Select-Object -First 1).Trim())
        $dev.sdk = (($sdk -split "`r?`n" | Select-Object -First 1).Trim())
        if ($dev.model) { $dev.connected = $true }

        $batt = Invoke-CmdCaptured -FilePath $adb -ArgumentList @("-s", $id, "shell", "dumpsys", "battery") -TimeoutSec 6
        foreach ($bl in ($batt -split "`r?`n")) {
            $m = [regex]::Match($bl, '^\s*level:\s*(\d+)'); if ($m.Success) { $dev.battery_level = [int]$m.Groups[1].Value }
            $m = [regex]::Match($bl, '^\s*temperature:\s*(\d+)'); if ($m.Success) { $dev.battery_temp_c = [math]::Round([int]$m.Groups[1].Value / 10) }
            $m = [regex]::Match($bl, '^\s*health:\s*(\d+)')
            if ($m.Success) {
                $dev.battery_health = [int]$m.Groups[1].Value
                $dev.battery_health_txt = switch ($dev.battery_health) {
                    2 { "جيد" }; 3 { "حرارة زائدة" }; 4 { "تالفة" }; 5 { "جهد زائد" }; 6 { "غير محدد" }; 7 { "باردة" }; default { "غير معروف" }
                }
            }
        }

        $df = Invoke-CmdCaptured -FilePath $adb -ArgumentList @("-s", $id, "shell", "df", "/data") -TimeoutSec 6
        foreach ($dfl in ($df -split "`r?`n")) {
            if ($dfl -match '^/dev/[^\s]+\s+(\d+)\s+\d+\s+(\d+)\s+') {
                $totalBlocks = [double]$Matches[1]; $freeBlocks = [double]$Matches[2]
                if ($totalBlocks -gt 0) {
                    $dev.storage_total_gb = [math]::Round($totalBlocks / (1024 * 1024), 1)
                    $dev.storage_free_gb = [math]::Round($freeBlocks / (1024 * 1024), 1)
                }
            }
        }
        $res.devices += $dev
    }
    return $res
}

# ---------- قراءة تقارير الشبكة من الحارس ----------
function Get-DeviceNetworkReport {
    $n = @{ present = $false; dns_ms = $null; gw_loss = $null; wan_loss = $null; conflicts = $null; bounces = $null; status = $null; ssid = $null; ipv4 = $null; sla = @() }
    try {
        $f = "$script:ReportsDir\net-health-last.json"
        if (Test-Path $f) {
            $j = Get-Content $f -Raw | ConvertFrom-Json
            $n.present = $true
            $n.dns_ms = $j.dnsMs; $n.gw_loss = $j.gatewayLossPct; $n.wan_loss = $j.wanLossPct
            $n.conflicts = $j.conflicts24h; $n.bounces = $j.wlanBounce24h
            $n.status = $j.status; $n.ssid = $j.ssid; $n.ipv4 = $j.ipv4
            if ($j.slaFailures) { $n.sla = @($j.slaFailures) }
        }
    } catch { }
    return $n
}

# ---------- لقطة شاملة ----------
function Get-DeviceSnapshot {
    $snap = @{
        timestamp = (Get-Date -Format "o")
        device = Get-DeviceFacts
        battery = Get-DeviceBattery
        storage = Get-DeviceStorage
        thermal = Get-DeviceThermal
        processes = Get-TopProcesses
        adb = Get-AndroidFacts
        network = Get-DeviceNetworkReport
    }
    $snap.summary = @{
        cpu_load = $snap.device.cpu_load
        ram_pct = $snap.device.used_ram_pct
        battery_health_pct = $snap.battery.health_pct
        battery_level_pct = $snap.battery.level_pct
        cpu_temp = $snap.thermal.summary
        max_disk_wear = $null
        disk_healthy = $null
        adb_available = $snap.adb.adb_available
        devices_count = @($snap.adb.devices).Count
        dns_ms = $snap.network.dns_ms
        network_status = $snap.network.status
    }
    $wears = @($snap.storage | ForEach-Object { if ($null -ne $_.wear_pct) { [double]$_.wear_pct } })
    if ($wears.Count) { $snap.summary.max_disk_wear = ($wears | Measure-Object -Maximum).Maximum }
    $unhealthy = @($snap.storage | Where-Object { $_.health -and $_.health -ne "Healthy" })
    $snap.summary.disk_healthy = $unhealthy.Count -eq 0
    return $snap
}

# ---------- سجل النقاط الزمنية (للتاريخ والتنبؤ) ----------
function Save-DevicePoint {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Snapshot)
    $point = @{
        at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        cpu = $Snapshot.summary.cpu_load
        cpu_temp = $Snapshot.summary.cpu_temp
        ram = $Snapshot.summary.ram_pct
        battery = $Snapshot.summary.battery_health_pct
        disk_wear = $Snapshot.summary.max_disk_wear
        dns_ms = $Snapshot.summary.dns_ms
        wan = $Snapshot.network.wan_loss
        status = $Snapshot.summary.network_status
    }
    $hist = @()
    if (Test-Path $script:HistoryFile) {
        try { $hist = @(Get-Content $script:HistoryFile -Raw | ConvertFrom-Json) } catch { $hist = @() }
    }
    $raw = @()
    foreach ($h in $hist) {
        if ($h.at -and $raw.Count -ge $script:HistoryCap - 1) { break }
        $raw += @{ at = [string]$h.at; cpu = $h.cpu; cpu_temp = $h.cpu_temp; ram = $h.ram; battery = $h.battery; disk_wear = $h.disk_wear; dns_ms = $h.dns_ms; wan = $h.wan; status = [string]$h.status }
    }
    $raw += $point
    if ($raw.Count -gt $script:HistoryCap) { $raw = $raw | Select-Object -Last $script:HistoryCap }
    try {
        $dir = Split-Path $script:HistoryFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $json = ConvertTo-Json -InputObject $raw -Depth 4
        [System.IO.File]::WriteAllText($script:HistoryFile, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
    return $point
}

function Get-DeviceHistory {
    $hist = @()
    if (Test-Path $script:HistoryFile) {
        try { $hist = @(Get-Content $script:HistoryFile -Raw | ConvertFrom-Json) } catch { $hist = @() }
    }
    return @($hist | ForEach-Object {
        @{ at = [string]$_.at; cpu = $_.cpu; cpu_temp = $_.cpu_temp; ram = $_.ram; battery = $_.battery; disk_wear = $_.disk_wear; dns_ms = $_.dns_ms; wan = $_.wan; status = [string]$_.status }
    })
}

# التصدير اختياري (يعمل عند الاستيراد كوحدة؛ عند الدمج بـ dot-source يُتجاهل)
try { Export-ModuleMember -Function Get-DeviceFacts, Get-DeviceBattery, Get-DeviceStorage, Get-DeviceThermal, Get-TopProcesses, Get-AndroidFacts, Get-DeviceNetworkReport, Get-DeviceSnapshot, Save-DevicePoint, Get-DeviceHistory } catch { }