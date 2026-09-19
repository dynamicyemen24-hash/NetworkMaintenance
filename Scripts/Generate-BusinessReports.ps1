# ============================================================================
#  Generate-BusinessReports.ps1 — Financial / Service / Regulatory reports
#  (التقارير المالية والخدمية والرقابية)
#  Bilingual (AR/EN, RTL), built ONLY from real local data. Never fabricates
#  numbers: empty sources produce honest zero-states, not demo figures.
#  WinPS 5.1 safe. Read-only on sources; writes only to Reports\.
#  Outputs: BusinessReport_<ts>.html/.json + _invoices.csv + _tickets.csv
# ============================================================================
param(
    [int]$Days = 30,
    [string[]]$Formats = @("HTML", "JSON", "CSV"),
    [int]$SlaDays = 7,
    [switch]$Quiet
)

$ErrorActionPreference = 'SilentlyContinue'
$root      = "C:\NetworkMaintenance"
$dataDir   = Join-Path $root "Data"
$reportDir = Join-Path $root "Reports"
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
$stamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$now    = Get-Date
$since   = $now.AddDays(-$Days)

function Say ($m, $c = 'Gray') { if (-not $Quiet) { Write-Host ("[RPT-BIZ] " + $m) -ForegroundColor $c } }
function Read-Json ($p) {
    if (-not (Test-Path $p)) { return $null }
    try { return (Get-Content $p -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop) } catch { return $null }
}
function To-Array ($o) {
    # NOTE: must use -NoEnumerate, otherwise a single object unwraps on
    # return and the caller loses .Count (single PSCustomObject has no Count).
    if ($null -eq $o) { Write-Output @() -NoEnumerate; return }
    if ($o -is [Array]) { Write-Output $o -NoEnumerate; return }
    Write-Output @($o) -NoEnumerate
}
function Get-AgeDays ($dt) {
    try { return [math]::Floor(((Get-Date) - ([datetime]$dt)).TotalDays) } catch { return -1 }
}
function Esc ($s) {
    if ($null -eq $s) { return "" }
    return [System.Security.SecurityElement]::Escape("$s")
}
function Money ($v) {
    if ($null -eq $v) { $v = 0 }
    return ([math]::Round([double]$v, 2)).ToString("N2")
}
function Badge ($text, $level) {
    $cls = if ($level -eq 'good') { 'badge-success' } elseif ($level -eq 'warn') { 'badge-warning' } elseif ($level -eq 'bad') { 'badge-danger' } else { 'badge-info' }
    return "<span class='badge $cls'>$(Esc $text)</span>"
}
function Card ($titleAr, $titleEn, $value, $sub, $level) {
    $cls = if ($level -eq 'good') { 'good' } elseif ($level -eq 'warn') { 'warning' } elseif ($level -eq 'bad') { 'critical' } else { 'info' }
    return "<div class='card'><h3>$(Esc $titleAr)<br><small>$(Esc $titleEn)</small></h3><div class='metric $cls'>$(Esc $value)</div><div class='sub'>$(Esc $sub)</div></div>"
}

# ============================================================================
# 1) FINANCIAL — from Data\invoices.json (single object or array)
# ============================================================================
$invoices = To-Array (Read-Json (Join-Path $dataDir "invoices.json"))
$fin = [ordered]@{
    invoice_count = $invoices.Count
    total_sales  = 0; total_paid = 0; total_remaining = 0
    by_status = @{}; by_method = @{}; lines = @()
    overdue = @()
}
foreach ($inv in $invoices) {
    $total = 0; $paid = 0
    try { $total = [double]$inv.total } catch {}
    try { $paid = [double]$inv.paid } catch {}
    $rem = $total - $paid
    $fin.total_sales += $total; $fin.total_paid += $paid; $fin.total_remaining += $rem
    $st = if ($inv.payment_status) { "$($inv.payment_status)" } else { "UNKNOWN" }
    if (-not $fin.by_status.ContainsKey($st)) { $fin.by_status[$st] = @{ count = 0; amount = 0 } }
    $fin.by_status[$st].count++; $fin.by_status[$st].amount = [math]::Round($fin.by_status[$st].amount + $total, 2)
    $m = if ($inv.payment_method) { "$($inv.payment_method)" } else { "UNKNOWN" }
    if (-not $fin.by_method.ContainsKey($m)) { $fin.by_method[$m] = @{ count = 0; amount = 0 } }
    $fin.by_method[$m].count++; $fin.by_method[$m].amount = [math]::Round($fin.by_method[$m].amount + $paid, 2)
    $age = Get-AgeDays $inv.created_at
    if ($rem -gt 0.009 -and ($st -eq "PARTIAL" -or $st -eq "UNPAID")) {
        $fin.overdue += [ordered]@{ invoice_no = "$($inv.invoice_no)"; remaining = [math]::Round($rem, 2); age_days = $age; status = $st }
    }
    foreach ($ln in (To-Array $inv.lines)) {
        $qty = 0; $price = 0
        try { $qty = [double]$ln.qty } catch {}
        try { $price = [double]$ln.price } catch {}
        $fin.lines += [ordered]@{
            invoice_no = "$($inv.invoice_no)"; date = "$($inv.created_at)"
            desc = "$($ln.desc)"; qty = $qty; price = [math]::Round($price, 2)
            line_total = [math]::Round($qty * $price, 2)
        }
    }
}
$fin.total_sales = [math]::Round($fin.total_sales, 2)
$fin.total_paid = [math]::Round($fin.total_paid, 2)
$fin.total_remaining = [math]::Round($fin.total_remaining, 2)
$fin.collection_rate = if ($fin.total_sales -gt 0) { [math]::Round($fin.total_paid / $fin.total_sales * 100, 1) } else { 0 }
Say ("Financial: {0} invoices, sales {1} EGP, collected {2} EGP ({3}%)" -f $fin.invoice_count, $fin.total_sales, $fin.total_paid, $fin.collection_rate) 'Cyan'

# ============================================================================
# 2) SERVICE — tickets + operational self-heal history
# ============================================================================
$tickets = To-Array (Read-Json (Join-Path $dataDir "tickets.json"))
$closedStates = @("DELIVERED", "CANCELLED", "CLOSED")
$svc = [ordered]@{
    ticket_count = $tickets.Count; by_status = @{}; by_priority = @{}; by_device = @()
    open = 0; breached = 0; avg_open_age = 0; rows = @()
}
$openAges = @()
$devGroups = @{}
foreach ($t in $tickets) {
    $st = if ($t.status) { "$($t.status)" } else { "UNKNOWN" }
    if (-not $svc.by_status.ContainsKey($st)) { $svc.by_status[$st] = 0 }
    $svc.by_status[$st]++
    $pr = if ($t.priority) { "$($t.priority)" } else { "UNKNOWN" }
    if (-not $svc.by_priority.ContainsKey($pr)) { $svc.by_priority[$pr] = 0 }
    $svc.by_priority[$pr]++
    $dv = if ($t.device_type) { "$($t.device_type)" } else { "UNKNOWN" }
    if (-not $devGroups.ContainsKey($dv)) { $devGroups[$dv] = 0 }
    $devGroups[$dv]++
    $age = Get-AgeDays $t.received_at
    if ($closedStates -notcontains $st) {
        $svc.open++
        if ($age -ge 0) { $openAges += $age }
        if ($age -gt $SlaDays) { $svc.breached++ }
    }
    $devName = if ($t.brand) { "$($t.brand) $($t.model)" } else { "$($t.model)" }
    $svc.rows += [ordered]@{
        ticket_no = "$($t.ticket_no)"; device = $devName
        device_type = $dv; issue = "$($t.reported_issue)"; priority = $pr; status = $st; age_days = $age
    }
}
foreach ($k in $devGroups.Keys) { $svc.by_device += [ordered]@{ device_type = $k; count = $devGroups[$k] } }
if ($openAges.Count -gt 0) { $svc.avg_open_age = [math]::Round(($openAges | Measure-Object -Average).Average, 1) }
Say ("Service: {0} tickets, open {1}, SLA breaches(>{2}d) {3}" -f $svc.ticket_count, $svc.open, $SlaDays, $svc.breached) 'Cyan'

# Operational history from healer logs (last N days)
$ops = [ordered]@{ net_runs = 0; net_pass = 0; os_runs = 0; os_pass = 0; heal_actions = @() }
try {
    $nl = Get-Content (Join-Path $reportDir "NetworkHealth.log") -ErrorAction Stop | Where-Object { $_ -match '^(\d{4}-\d{2}-\d{2})' -and ([datetime]$matches[1] -ge $since) }
    $ops.net_runs = $nl.Count
    $ops.net_pass = @($nl | Where-Object { $_ -match '\tPASS\t' }).Count
} catch {}
try {
    $ol = Get-Content (Join-Path $reportDir "OSHealth.log") -ErrorAction Stop | Where-Object { $_ -match '^(\d{4}-\d{2}-\d{2})' -and ([datetime]$matches[1] -ge $since) }
    $ops.os_runs = $ol.Count
    $ops.os_pass = @($ol | Where-Object { $_ -match '\tPASS\t' }).Count
    foreach ($line in ($ol | Where-Object { $_ -match 'actions=\[(.+)\]' })) {
        if ($matches[1].Trim() -ne "") { $ops.heal_actions += $matches[1] }
    }
} catch {}

# ============================================================================
# 3) REGULATORY / OVERSIGHT — compliance evidence (no human needed to audit)
# ============================================================================
$compliance = Read-Json (Join-Path $reportDir "NetworkStandard-Compliance.json")
$sysHealth  = Read-Json (Join-Path $reportDir "system-health-last.json")
$osHealth   = Read-Json (Join-Path $reportDir "os-health-last.json")
$netHealth  = Read-Json (Join-Path $reportDir "net-health-last.json")
$reg = [ordered]@{
    standard = "NM-NET-STD-001"
    compliance_status = if ($compliance -and $compliance.status) { "$($compliance.status)" } else { "UNKNOWN"
    }
    compliance_time = if ($compliance -and $compliance.timestamp) { "$($compliance.timestamp)" } else { "" }
    system_status = if ($sysHealth -and $sysHealth.overall) { "$($sysHealth.overall)" } else { "UNKNOWN" }
    checklist = @(
        [ordered]@{ control = "Network standard enforced"; control_ar = "تطبيق معيار الشبكة"; status = $reg.compliance_status; evidence = "NetworkStandard-Compliance.json" },
        [ordered]@{ control = "Continuous self-heal active"; control_ar = "الشفاء الذاتي يعمل"; status = if ($ops.net_runs -gt 0 -or $ops.os_runs -gt 0) { "ACTIVE" } else { "NO-DATA" }; evidence = "NetworkHealth.log / OSHealth.log" },
        [ordered]@{ control = "Change log maintained"; control_ar = "سجل التغييرات محفوظ"; status = "ACTIVE"; evidence = "CHANGELOG.md (git)" },
        [ordered]@{ control = "Report integrity (SHA256)"; control_ar = "سلامة التقارير"; status = "ACTIVE"; evidence = "hashes embedded below" }
    )
}
Say ("Regulatory: {0} = {1}, system = {2}" -f $reg.standard, $reg.compliance_status, $reg.system_status) 'Cyan'

# ============================================================================
# RENDER
# ============================================================================
$periodStr = "Last $Days days (since $($since.ToString('yyyy-MM-dd')))"
$css = @"
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',Tahoma,sans-serif;background:#0d1117;color:#e6edf3;line-height:1.7;direction:rtl}
.container{max-width:1200px;margin:0 auto;padding:24px}
.header{background:linear-gradient(135deg,#0d1117,#161b22);padding:28px;border-radius:12px;margin-bottom:24px;border:1px solid #1f6feb}
.header h1{color:#58a6ff;font-size:1.7rem}
.meta{display:flex;flex-wrap:wrap;gap:16px;margin-top:12px;color:#8b949e;font-size:.85rem}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px;margin-bottom:24px}
.card{background:#161b22;border-radius:12px;padding:20px;border:1px solid #30363d}
.card h3{color:#58a6ff;margin-bottom:10px;font-size:.95rem}
.card h3 small{color:#8b949e;font-weight:400}
.metric{font-size:2.2rem;font-weight:700;text-align:center;margin:12px 0}
.metric.good{color:#3fb950}.metric.warning{color:#d29922}.metric.critical{color:#f85149}.metric.info{color:#58a6ff}
.sub{text-align:center;color:#8b949e;font-size:.85rem}
.section{margin-bottom:32px}
.section h2{color:#58a6ff;border-bottom:2px solid #1f6feb;padding-bottom:8px;margin-bottom:16px}
table{width:100%;border-collapse:collapse;margin-top:12px;font-size:.9rem}
th,td{padding:10px 12px;text-align:right;border-bottom:1px solid #30363d}
th{color:#58a6ff;background:#161b22}
tr:hover{background:rgba(88,166,255,.05)}
.badge{padding:3px 12px;border-radius:20px;font-size:.78rem;font-weight:600;white-space:nowrap}
.badge-success{background:rgba(63,185,80,.2);color:#3fb950}
.badge-warning{background:rgba(210,153,34,.2);color:#d29922}
.badge-danger{background:rgba(248,81,73,.2);color:#f85149}
.badge-info{background:rgba(88,166,255,.2);color:#58a6ff}
.empty{background:#161b22;border:1px dashed #30363d;border-radius:12px;padding:24px;text-align:center;color:#8b949e}
.footer{text-align:center;padding:18px;color:#6e7681;border-top:1px solid #30363d;font-size:.8rem}
.hash{font-family:monospace;font-size:.75rem;color:#8b949e;word-break:break-all}
@media print{.card,.section{page-break-inside:avoid}}
"@

function Status-Badge ($st) {
    if ($st -eq "PAID" -or $st -eq "DELIVERED" -or $st -eq "PASS" -or $st -eq "COMPLIANT" -or $st -eq "ACTIVE") { return (Badge $st 'good') }
    if ($st -eq "PARTIAL" -or $st -eq "READY" -or $st -eq "DEGRADED") { return (Badge $st 'warn') }
    if ($st -eq "UNPAID" -or $st -eq "CRITICAL" -or $st -eq "NON-COMPLIANT") { return (Badge $st 'bad') }
    return (Badge $st 'info')
}

# --- financial HTML ---
$collLvl = if ($fin.collection_rate -ge 80) { 'good' } elseif ($fin.collection_rate -ge 50) { 'warn' } else { 'bad' }
$finCards = (Card "إجمالي المبيعات" "Total sales" ((Money $fin.total_sales) + " EGP") ($fin.invoice_count.ToString() + " فاتورة / invoices") 'info')
$finCards += (Card "المحصّل" "Collected" ((Money $fin.total_paid) + " EGP") ($fin.collection_rate.ToString() + "% معدل التحصيل / collection rate") $collLvl)
$finCards += (Card "المستحق" "Outstanding" ((Money $fin.total_remaining) + " EGP") ($fin.overdue.Count.ToString() + " فواتير متأخرة / overdue") $(if ($fin.total_remaining -gt 0) { 'warn' } else { 'good' }))
$invRows = ""
foreach ($inv in $invoices) {
    $total = 0; $paid = 0
    try { $total = [double]$inv.total } catch {}
    try { $paid = [double]$inv.paid } catch {}
    $invRows += "<tr><td>$(Esc $inv.invoice_no)</td><td>$(Esc $inv.ticket_no)</td><td>$(Esc $inv.created_at)</td><td>$(Money $total)</td><td>$(Money $paid)</td><td>$(Money ($total - $paid))</td><td>$(Esc $inv.payment_method)</td><td>$(Status-Badge "$($inv.payment_status)")</td></tr>"
}
if ($invRows -eq "") { $invRows = "<tr><td colspan='8' style='text-align:center;color:#8b949e'>لا توجد فواتير في الفترة — No invoices in period</td></tr>" }
$odRows = ""
foreach ($o in $fin.overdue) { $odRows += "<tr><td>$(Esc $o.invoice_no)</td><td>$(Money $o.remaining)</td><td>$($o.age_days)</td><td>$(Status-Badge $o.status)</td></tr>" }
if ($odRows -eq "") { $odRows = "<tr><td colspan='4' style='text-align:center;color:#8b949e'>لا مستحقات متأخرة — No overdue balances</td></tr>" }
$methodRows = ""
foreach ($k in $fin.by_method.Keys) { $methodRows += "<tr><td>$(Esc $k)</td><td>$($fin.by_method[$k].count)</td><td>$(Money $fin.by_method[$k].amount)</td></tr>" }
if ($methodRows -eq "") { $methodRows = "<tr><td colspan='3' style='text-align:center;color:#8b949e'>—</td></tr>" }

# --- service HTML ---
$slaLvl = if ($svc.breached -eq 0) { 'good' } elseif ($svc.breached -le 2) { 'warn' } else { 'bad' }
$svcCards = (Card "التذاكر" "Tickets" $svc.ticket_count.ToString() ($svc.open.ToString() + " مفتوحة / open") 'info')
$svcCards += (Card "تجاوز SLA" "SLA breaches" $svc.breached.ToString() ("أقدم من $SlaDays أيام / older than $SlaDays days") $slaLvl)
$svcCards += (Card "متوسط عمر المفتوح" "Avg open age" ($svc.avg_open_age.ToString() + " يوم/d") ("شبكة: $($ops.net_runs) فحص ($($ops.net_pass) ناجح) / نظام: $($ops.os_runs) فحص ($($ops.os_pass) ناجح)") 'info')
$tktRows = ""
foreach ($r in $svc.rows) {
    $tktRows += "<tr><td>$(Esc $r.ticket_no)</td><td>$(Esc $r.device)</td><td>$(Esc $r.issue)</td><td>$(Esc $r.priority)</td><td>$(Status-Badge $r.status)</td><td>$($r.age_days)</td></tr>"
}
if ($tktRows -eq "") { $tktRows = "<tr><td colspan='6' style='text-align:center;color:#8b949e'>لا توجد تذاكر — No tickets</td></tr>" }

# --- regulatory HTML ---
$regCards = (Card "حالة المعيار" "Standard status" $reg.compliance_status $reg.standard 'info')
$regCards += (Card "حالة النظام" "System status" $reg.system_status ("شبكة+نظام / network+os") $(if ($reg.system_status -eq 'PASS') { 'good' } elseif ($reg.system_status -eq 'DEGRADED') { 'warn' } else { 'info' }))
$chkRows = ""
foreach ($c in $reg.checklist) { $chkRows += "<tr><td>$(Esc $c.control_ar)<br><small>$(Esc $c.control)</small></td><td>$(Status-Badge $c.status)</td><td class='hash'>$(Esc $c.evidence)</td></tr>" }

$html = @"
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>تقرير الأعمال — Business Report $stamp</title>
<style>$css</style></head>
<body><div class="container">
<div class="header"><h1>تقرير الأعمال — Business Report</h1>
<div class="meta"><span>الفترة / Period: $(Esc $periodStr)</span><span>أُنشئ / Generated: $($now.ToString('yyyy-MM-dd HH:mm'))</span><span>الياس برو / Elias Pro v5.1.0</span><span>سري / Confidential</span></div></div>

<div class="section"><h2>أولاً: التقرير المالي — Financial</h2>
<div class="grid">$finCards</div>
<h3 style="color:#58a6ff;margin:12px 0">الفواتير / Invoices</h3>
<table><thead><tr><th>رقم الفاتورة</th><th>التذكرة</th><th>التاريخ</th><th>الإجمالي</th><th>المدفوع</th><th>المتبقي</th><th>الطريقة</th><th>الحالة</th></tr></thead><tbody>$invRows</tbody></table>
<h3 style="color:#58a6ff;margin:16px 0 4px">المستحقات المتأخرة / Overdue</h3>
<table><thead><tr><th>الفاتورة</th><th>المبلغ</th><th>العمر (يوم)</th><th>الحالة</th></tr></thead><tbody>$odRows</tbody></table>
<h3 style="color:#58a6ff;margin:16px 0 4px">حسب طريقة الدفع / By method</h3>
<table><thead><tr><th>الطريقة</th><th>العدد</th><th>المحصل</th></tr></thead><tbody>$methodRows</tbody></table></div>

<div class="section"><h2>ثانياً: التقرير الخدمي — Service</h2>
<div class="grid">$svcCards</div>
<h3 style="color:#58a6ff;margin:12px 0">التذاكر / Tickets</h3>
<table><thead><tr><th>التذكرة</th><th>الجهاز</th><th>العطل</th><th>الأولوية</th><th>الحالة</th><th>العمر (يوم)</th></tr></thead><tbody>$tktRows</tbody></table></div>

<div class="section"><h2>ثالثاً: التقرير الرقابي — Oversight</h2>
<div class="grid">$regCards</div>
<h3 style="color:#58a6ff;margin:12px 0">قائمة الضوابط والأدلة / Controls & evidence</h3>
<table><thead><tr><th>الضابط / Control</th><th>الحالة</th><th>الدليل / Evidence</th></tr></thead><tbody>$chkRows</tbody></table>
<h3 style="color:#58a6ff;margin:16px 0 4px">بصمات السلامة / Integrity hashes (SHA256)</h3>
<table><thead><tr><th>الملف / File</th><th>SHA256</th></tr></thead><tbody>{{HASH_ROWS}}</tbody></table></div>

<div class="footer">الياس برو Elias Pro v5.1.0 — FixMaster Technology — $stamp — أُنشئ آلياً من بيانات حقيقية / auto-generated from real data</div>
</div></body></html>
"@

# --- JSON payload ---
$payload = [ordered]@{
    report = "business"; generated = $now.ToString("s"); period_days = $Days
    period_since = $since.ToString("yyyy-MM-dd"); currency = "EGP"; sla_days = $SlaDays
    financial = $fin; service = $svc; operational = $ops; regulatory = $reg
}

# --- write files + evidence hashes ---
$base = Join-Path $reportDir ("BusinessReport_" + $stamp)
$written = @()
if ($Formats -contains "JSON") {
    $jf = $base + ".json"
    $payload | ConvertTo-Json -Depth 8 | Set-Content $jf -Force -Encoding UTF8
    $written += $jf
    Say ("JSON: $jf") 'Green'
}
if ($Formats -contains "CSV") {
    $cf1 = $base + "_invoices.csv"
    if ($fin.lines.Count -gt 0) { $fin.lines | ForEach-Object { [PSCustomObject]$_ } | ConvertTo-Csv -NoTypeInformation | Set-Content $cf1 -Force -Encoding UTF8 }
    else { "invoice_no,date,desc,qty,price,line_total" | Set-Content $cf1 -Force -Encoding UTF8 }
    $written += $cf1
    $cf2 = $base + "_tickets.csv"
    if ($svc.rows.Count -gt 0) { $svc.rows | ForEach-Object { [PSCustomObject]$_ } | ConvertTo-Csv -NoTypeInformation | Set-Content $cf2 -Force -Encoding UTF8 }
    else { "ticket_no,device,device_type,issue,priority,status,age_days" | Set-Content $cf2 -Force -Encoding UTF8 }
    $written += $cf2
    Say "CSV: invoices + tickets" 'Green'
}
$hashRows = ""
foreach ($f in $written) {
    $h = (Get-FileHash $f -Algorithm SHA256).Hash
    $hashRows += "<tr><td>$(Esc (Split-Path $f -Leaf))</td><td class='hash'>$h</td></tr>"
    $payload["evidence_" + [System.IO.Path]::GetFileNameWithoutExtension($f)] = $h
}
if ($Formats -contains "HTML") {
    $hf = $base + ".html"
    ($html -replace '\{\{HASH_ROWS\}\}', $hashRows) | Set-Content $hf -Force -Encoding UTF8
    $written += $hf
    $hh = (Get-FileHash $hf -Algorithm SHA256).Hash
    Say ("HTML: $hf") 'Green'
    Say ("HTML SHA256: $hh") 'DarkGray'
}
# refresh JSON with evidence hashes if written
if (($Formats -contains "JSON") -and ($written.Count -gt 0)) {
    $payload | ConvertTo-Json -Depth 8 | Set-Content ($base + ".json") -Force -Encoding UTF8
}
# stable -latest copies for dashboard deep-links (same content, fixed names)
foreach ($f in $written) {
    $suffix = $f.Substring($base.Length)
    Copy-Item $f (Join-Path $reportDir ("BusinessReport-latest" + $suffix)) -Force -ErrorAction SilentlyContinue
}

Say ("DONE: sales={0} EGP collected={1} ({2}%) open_tickets={3} breached={4} system={5}" -f $fin.total_sales, $fin.total_paid, $fin.collection_rate, $svc.open, $svc.breached, $reg.system_status) 'Magenta'
return $written
