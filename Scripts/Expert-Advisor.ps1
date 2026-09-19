# ============================================================================
#  Expert-Advisor.ps1 — Unified expert layer for every end-user journey
#  (طبقة الخبير الموحدة: القائمة + التذاكر + الداشبورد)
#  Serves: Elias Pro menu (option 20), repair-shop tickets, dashboard JSON.
#  Method: fast triage -> ranked next-best-actions (severity x impact/effort)
#          -> guided explanations (AR/EN) -> safe one-key apply.
#  WinPS 5.1 safe. Read-only except: optional DNS flush + report files.
#  Modes: Triage | Tickets | Guide | Session
# ============================================================================
param(
    [ValidateSet("Triage", "Tickets", "Guide", "Session")]
    [string]$Mode = "Triage",
    [int]$SlaDays = 7,
    [switch]$Quiet
)

$ErrorActionPreference = 'SilentlyContinue'
$root      = "C:\NetworkMaintenance"
$dataDir   = Join-Path $root "Data"
$reportDir = Join-Path $root "Reports"

function XSay ($m, $c = 'Gray') { if (-not $Quiet) { Write-Host ("[EXPERT] " + $m) -ForegroundColor $c } }
function XRead-Json ($p) {
    if (-not (Test-Path $p)) { return $null }
    try { return (Get-Content $p -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop) } catch { return $null }
}
function XTo-Array ($o) {
    if ($null -eq $o) { Write-Output @() -NoEnumerate; return }
    if ($o -is [Array]) { Write-Output $o -NoEnumerate; return }
    Write-Output @($o) -NoEnumerate
}
function XAge ($dt) {
    try { return [math]::Floor(((Get-Date) - ([datetime]$dt)).TotalDays) } catch { return -1 }
}

# ============================================================================
# KNOWLEDGE BASE: finding -> expert rule {severity, cause, fix, verify}
# severity: critical=30, warn=20, info=10. impact 1-5, effort 1-5 (lower=better)
# ============================================================================
function Get-ExpertRules {
    return @(
        [ordered]@{ id = "CPU"; severity = "warn"; impact = 4; effort = 2;
            titleAr = "ضغط على المعالج"; titleEn = "CPU pressure";
            causeAr = "عملية تستهلك المعالج أو حمل عام مرتفع"; causeEn = "A process hogs CPU or high overall load";
            fixAr = "تشغيل معالج الصحة OS-Health-Healer"; fixEn = "Run OS-Health-Healer";
            run = "powershell -File Scripts\OS-Health-Healer.ps1 -Enforce" },
        [ordered]@{ id = "RAM"; severity = "warn"; impact = 4; effort = 2;
            titleAr = "ضغط على الذاكرة"; titleEn = "Memory pressure";
            causeAr = "استهلاك رام فوق 90%"; causeEn = "RAM usage above 90%";
            fixAr = "تشغيل معالج الصحة OS-Health-Healer"; fixEn = "Run OS-Health-Healer";
            run = "powershell -File Scripts\OS-Health-Healer.ps1 -Enforce" },
        [ordered]@{ id = "DISK"; severity = "warn"; impact = 3; effort = 1;
            titleAr = "مساحة القرص منخفضة"; titleEn = "Low disk space";
            causeAr = "ملفات مؤقتة أو امتلاء القرص"; causeEn = "Temp files or full disk";
            fixAr = "تنظيف آمن + تقرير"; fixEn = "Safe cleanup + report";
            run = "powershell -File Scripts\OS-Health-Healer.ps1 -Enforce" },
        [ordered]@{ id = "NET-LOSS"; severity = "critical"; impact = 5; effort = 2;
            titleAr = "فقدان حزم أو بطء إنترنت"; titleEn = "Packet loss / slow internet";
            causeAr = "ازدحام وصلة المزود أو انحراف الإعداد"; causeEn = "Uplink congestion or config drift";
            fixAr = "فحص المعيار ثم المراقب"; fixEn = "Apply standard, then watchdog";
            run = "powershell -File Scripts\Apply-NetworkStandard.ps1" },
        [ordered]@{ id = "NET-DRIFT"; severity = "warn"; impact = 4; effort = 1;
            titleAr = "انحراف إعداد الشبكة"; titleEn = "Network config drift";
            causeAr = "DHCP غيّر IP/DNS عن المعيار"; causeEn = "DHCP changed IP/DNS away from standard";
            fixAr = "إعادة فرض المعيار"; fixEn = "Re-apply network standard";
            run = "powershell -File Scripts\Apply-NetworkStandard.ps1" },
        [ordered]@{ id = "DNS"; severity = "warn"; impact = 4; effort = 1;
            titleAr = "تعثر تحليل الأسماء"; titleEn = "DNS resolution failing";
            causeAr = "كاش تالف أو مزود DNS محجوب"; causeEn = "Stale cache or filtered DNS server";
            fixAr = "تنظيف كاش DNS"; fixEn = "Flush DNS cache";
            run = "ipconfig /flushdns" },
        [ordered]@{ id = "REBOOT"; severity = "info"; impact = 2; effort = 1;
            titleAr = "إعادة تشغيل معلقة"; titleEn = "Pending reboot";
            causeAr = "تحديثات بانتظار إعادة التشغيل"; causeEn = "Updates awaiting reboot";
            fixAr = "أعد التشغيل يدوياً عند удобство"; fixEn = "Reboot manually when convenient";
            run = "" },
        [ordered]@{ id = "TICKET-SLA"; severity = "critical"; impact = 5; effort = 2;
            titleAr = "تذاكر متجاوزة SLA"; titleEn = "Tickets breaching SLA";
            causeAr = "تذاكر مفتوحة أقدم من الحد"; causeEn = "Open tickets older than SLA limit";
            fixAr = "مراجعة قائمة الأولويات"; fixEn = "Review priority queue";
            run = "powershell -File Scripts\Expert-Advisor.ps1 -Mode Tickets" },
        [ordered]@{ id = "MONEY"; severity = "warn"; impact = 5; effort = 2;
            titleAr = "مستحقات غير محصلة"; titleEn = "Uncollected balances";
            causeAr = "فواتير جزئية/غير مدفوعة"; causeEn = "Partial/unpaid invoices";
            fixAr = "تقرير مالي + متابعة العملاء"; fixEn = "Financial report + follow up";
            run = "powershell -File Scripts\Generate-BusinessReports.ps1 -Days 30" }
    )
}
function Get-SevScore ($sev) {
    if ($sev -eq "critical") { return 30 }
    if ($sev -eq "warn") { return 20 }
    return 10
}

# ============================================================================
# FAST TRIAGE (~15s, non-admin safe) -> ranked findings
# ============================================================================
function Invoke-ExpertTriage {
    $findings = @()
    $rules = Get-ExpertRules
    $ruleOf = @{}
    foreach ($r in $rules) { $ruleOf[$r.id] = $r }

    # CPU / RAM / Disk
    try { $cpu = (Get-CimInstance Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average } catch { $cpu = 0 }
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $ram = [math]::Round(($cs.TotalPhysicalMemory - ($os.FreePhysicalMemory * 1024)) / $cs.TotalPhysicalMemory * 100, 1)
    } catch { $ram = 0 }
    try {
        $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        $cfree = [math]::Round($c.FreeSpace / $c.Size * 100, 1)
    } catch { $cfree = 100 }
    if ($cpu -gt 85)   { $findings += [ordered]@{ rule = $ruleOf["CPU"];  metric = ("CPU {0}%" -f [math]::Round($cpu,1)) } }
    if ($ram -gt 90)   { $findings += [ordered]@{ rule = $ruleOf["RAM"];  metric = ("RAM {0}%" -f $ram) } }
    if ($cfree -lt 12) { $findings += [ordered]@{ rule = $ruleOf["DISK"]; metric = ("C: free {0}%" -f $cfree) } }

    # Network: gateway loss + internet loss + drift + DNS
    $gw = $null
    try { $gw = (Get-NetIPConfiguration -InterfaceAlias 'Wi-Fi' -ErrorAction Stop).IPv4DefaultGateway.NextHop } catch {}
    if ($gw) {
        $ok = 0
        $pinger = New-Object System.Net.NetworkInformation.Ping
        for ($i = 0; $i -lt 2; $i++) { try { if ($pinger.Send($gw, 1000).Status -eq 'Success') { $ok++ } } catch {} }
        if ($ok -lt 2) { $findings += [ordered]@{ rule = $ruleOf["NET-LOSS"]; metric = "gateway unreachable" } }
    }
    $wok = 0
    try {
        $p2 = New-Object System.Net.NetworkInformation.Ping
        for ($i = 0; $i -lt 3; $i++) { try { if ($p2.Send('8.8.8.8', 1500).Status -eq 'Success') { $wok++ } } catch {} }
    } catch {}
    if ($wok -lt 2) { $findings += [ordered]@{ rule = $ruleOf["NET-LOSS"]; metric = "WAN loss high" } }
    $net = XRead-Json (Join-Path $reportDir "net-health-last.json")
    if ($net -and $net.drift -and @($net.drift).Count -gt 0) {
        $findings += [ordered]@{ rule = $ruleOf["NET-DRIFT"]; metric = ((@($net.drift) | Select-Object -First 2) -join "; ") }
    }
    try {
        Resolve-DnsName -Name 'one.one.one.one' -Server '8.8.8.8' -QuickTimeout -ErrorAction Stop | Out-Null
    } catch { $findings += [ordered]@{ rule = $ruleOf["DNS"]; metric = "resolve failed" } }

    # Pending reboot
    $rb = $false
    try { if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction Stop) { $rb = $true } } catch {}
    try { if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction Stop) { $rb = $true } } catch {}
    if ($rb) { $findings += [ordered]@{ rule = $ruleOf["REBOOT"]; metric = "reboot pending" } }

    # Tickets SLA + money (cross-domain awareness)
    $tq = Get-TicketQueue
    if ($tq.breached -gt 0) { $findings += [ordered]@{ rule = $ruleOf["TICKET-SLA"]; metric = ("{0} breached" -f $tq.breached) } }
    $inv = XTo-Array (XRead-Json (Join-Path $dataDir "invoices.json"))
    $due = 0
    foreach ($v in $inv) {
        $t = 0; $p = 0
        try { $t = [double]$v.total } catch {}
        try { $p = [double]$v.paid } catch {}
        if (($t - $p) -gt 0.009) { $due += ($t - $p) }
    }
    if ($due -gt 0.009) { $findings += [ordered]@{ rule = $ruleOf["MONEY"]; metric = ("{0} EGP due" -f [math]::Round($due, 2)) } }

    # Rank: severity x impact / effort (higher first)
    $ranked = $findings | ForEach-Object {
        $s = (Get-SevScore $_.rule.severity) * $_.rule.impact / $_.rule.effort
        [ordered]@{ score = [math]::Round($s, 1); rule = $_.rule; metric = $_.metric }
    } | Sort-Object { $_.score } -Descending
    return $ranked
}

# ============================================================================
# TICKET QUEUE: expert routing + SLA prioritization
# ============================================================================
function Get-TicketQueue {
    $tickets = XTo-Array (XRead-Json (Join-Path $dataDir "tickets.json"))
    $invoices = XTo-Array (XRead-Json (Join-Path $dataDir "invoices.json"))
    $closedStates = @("DELIVERED", "CANCELLED", "CLOSED")
    $nextOf = @{
        RECEIVED = "ابدأ التشخيص / Start diagnosis"; DIAGNOSED = "أرسل عرض السعر / Send quote";
        QUOTED = "تابع العميل / Follow up customer"; APPROVED = "ابدأ الإصلاح / Start repair";
        REPAIRING = "تابع التقدم / Track progress"; QC = "افحص ثم سلّم / QC then deliver";
        READY = "أشعر العميل بالاستلام / Notify pickup"
    }
    $prioW = @{ HIGH = 30; URGENT = 40; MEDIUM = 15; LOW = 5 }
    $queue = @(); $breached = 0
    foreach ($t in $tickets) {
        $st = if ($t.status) { "$($t.status)" } else { "UNKNOWN" }
        if ($closedStates -contains $st) { continue }
        $age = XAge $t.received_at
        $pr = if ($t.priority) { "$($t.priority)".ToUpper() } else { "MEDIUM" }
        $pw = if ($prioW.ContainsKey($pr)) { $prioW[$pr] } else { 10 }
        $due = 0
        foreach ($v in $invoices) {
            if ("$($v.ticket_no)" -eq "$($t.ticket_no)") {
                $tt = 0; $pp = 0
                try { $tt = [double]$v.total } catch {}
                try { $pp = [double]$v.paid } catch {}
                $due += ($tt - $pp)
            }
        }
        $isBreach = ($age -gt $SlaDays)
        if ($isBreach) { $breached++ }
        $nx = if ($nextOf.ContainsKey($st)) { $nextOf[$st] } else { "راجع الحالة / Review status" }
        $score = $pw + [math]::Min($age * 2, 30) + $(if ($isBreach) { 20 } else { 0 })
        $queue += [ordered]@{
            ticket_no = "$($t.ticket_no)"; device = "$(if ($t.brand) { "$($t.brand) $($t.model)" } else { "$($t.model)" })"
            status = $st; priority = $pr; age_days = $age; breached = $isBreach
            amount_due = [math]::Round($due, 2); next_step = $nx; score = $score
        }
    }
    $queue = @($queue | Sort-Object { $_.score } -Descending)
    return [ordered]@{ open = $queue.Count; breached = $breached; queue = $queue }
}

# ============================================================================
# GUIDE: dashboard-consumable journey JSON
# ============================================================================
function Export-ExpertGuide ($triage, $queue) {
    $steps = @()
    $n = 1
    foreach ($f in ($triage | Select-Object -First 5)) {
        $steps += [ordered]@{
            step = $n; level = $f.rule.severity; title_ar = $f.rule.titleAr; title_en = $f.rule.titleEn
            metric = $f.metric; cause_ar = $f.rule.causeAr; fix_ar = $f.rule.fixAr; run = $f.rule.run
            target = "menu"
        }
        $n++
    }
    foreach ($q in ($queue.queue | Select-Object -First 5)) {
        $steps += [ordered]@{
            step = $n; level = if ($q.breached) { "critical" } else { "warn" }
            title_ar = ("تذكرة {0}" -f $q.ticket_no); title_en = ("Ticket {0}" -f $q.ticket_no)
            metric = ("{0} | {1}d | due {2}" -f $q.status, $q.age_days, $q.amount_due)
            cause_ar = ""; fix_ar = $q.next_step; run = ""; target = "shop"
        }
        $n++
    }
    if ($steps.Count -eq 0) {
        $steps += [ordered]@{ step = 1; level = "info"; title_ar = "كل شيء سليم"; title_en = "All clear";
            metric = "PASS"; cause_ar = ""; fix_ar = "لا إجراء مطلوب"; run = ""; target = "none" }
    }
    $guide = [ordered]@{
        generated = (Get-Date).ToString("s"); engine = "Expert-Advisor v1.0"
        steps = $steps
    }
    $gf = Join-Path $reportDir "expert-guide.json"
    $guide | ConvertTo-Json -Depth 5 | Set-Content $gf -Force -Encoding UTF8
    return $gf
}

# ============================================================================
# MAIN
# ============================================================================
if ($Mode -eq "Triage") {
    XSay "Fast expert triage..." 'Cyan'
    $ranked = Invoke-ExpertTriage
    if ($ranked.Count -eq 0) { XSay "No findings - system and shop look healthy (PASS)" 'Green' }
    foreach ($f in $ranked) {
        $c = if ($f.rule.severity -eq 'critical') { 'Red' } elseif ($f.rule.severity -eq 'warn') { 'Yellow' } else { 'Gray' }
        XSay ("[{0}] {1} ({2}) score={3}" -f $f.rule.severity.ToUpper(), $f.rule.titleAr, $f.metric, $f.score) $c
        XSay ("   السبب: {0}" -f $f.rule.causeAr) 'DarkGray'
        XSay ("   الإصلاح: {0}" -f $f.rule.fixAr) 'White'
        if ($f.rule.run -ne "") { XSay ("   الأمر: {0}" -f $f.rule.run) 'DarkCyan' }
    }
    return $ranked
}

if ($Mode -eq "Tickets") {
    XSay "Expert ticket queue..." 'Cyan'
    $tq = Get-TicketQueue
    XSay ("Open: {0} | Breached(>{1}d): {2}" -f $tq.open, $SlaDays, $tq.breached) 'Cyan'
    foreach ($q in $tq.queue) {
        $c = if ($q.breached) { 'Red' } elseif ($q.priority -eq 'HIGH' -or $q.priority -eq 'URGENT') { 'Yellow' } else { 'White' }
        XSay ("#{0} {1} [{2}/{3}] {4}d due={5} => {6}" -f $q.ticket_no, $q.device, $q.status, $q.priority, $q.age_days, $q.amount_due, $q.next_step) $c
    }
    return $tq
}

if ($Mode -eq "Guide") {
    $ranked = Invoke-ExpertTriage
    $tq = Get-TicketQueue
    $gf = Export-ExpertGuide $ranked $tq
    XSay ("Dashboard guide: $gf") 'Green'
    return $gf
}

if ($Mode -eq "Session") {
    XSay "=== Guided expert session / جلسة خبير موجهة ===" 'Magenta'
    $ranked = Invoke-ExpertTriage
    if ($ranked.Count -eq 0) { XSay "Everything looks healthy. No action needed. / كل شيء سليم" 'Green'; return }
    $safeRuns = @("ipconfig /flushdns")
    foreach ($f in ($ranked | Select-Object -First 5)) {
        Write-Host ""
        XSay ("[{0}] {1} ({2})" -f $f.rule.severity.ToUpper(), $f.rule.titleAr, $f.metric) 'Yellow'
        XSay ("Why: {0} / السبب: {1}" -f $f.rule.causeEn, $f.rule.causeAr) 'Gray'
        XSay ("Fix: {0} / الإصلاح: {1}" -f $f.rule.fixEn, $f.rule.fixAr) 'White'
        if ($f.rule.run -ne "") {
            if ($safeRuns -contains $f.rule.run) {
                $ans = Read-Host "  Apply now? (y/n) / تنفيذ الآن؟"
                if ($ans -eq 'y' -or $ans -eq 'Y') {
                    Invoke-Expression $f.rule.run | Out-Null
                    XSay "Applied: $($f.rule.run)" 'Green'
                }
            } else {
                XSay ("  Run when ready: {0}" -f $f.rule.run) 'DarkCyan'
            }
        }
    }
    Write-Host ""
    XSay "Session complete. Full report: run Generate-BusinessReports. / انتهت الجلسة" 'Magenta'
}
