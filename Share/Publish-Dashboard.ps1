# ====================================================================
# Publish-Dashboard.ps1 — خادم نشر محلي (Windows, PS 5.1+)
# بلا أي اعتماد (لا Pode ولا Node ولا Python):
# يخدم مجلد C:\NetworkMaintenance بالكامل ويعرض "رابطًا" جاهزًا
# للمشاركة مع العملاء على شبكتك المحلية، مع اختبار ذاتي للروابط.
# اضغط Ctrl+C للإيقاف.
# ====================================================================
param(
    [int]$Port = 8081,
    [switch]$Firewall,
    [switch]$Quiet
)
$ErrorActionPreference = "Stop"
$Root = "C:\NetworkMaintenance"

# ---------- خرائط MIME ----------
$mime = @{
    ".html" = "text/html; charset=utf-8"; ".htm" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8";  ".js"  = "application/javascript; charset=utf-8"
    ".mjs"  = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg"  = "image/svg+xml";       ".png" = "image/png";   ".jpg" = "image/jpeg"
    ".jpeg" = "image/jpeg";          ".gif" = "image/gif";   ".ico" = "image/x-icon"
    ".webp" = "image/webp";          ".woff" = "font/woff";  ".woff2" = "font/woff2"
    ".ttf"  = "font/ttf";            ".txt" = "text/plain; charset=utf-8"
    ".log"  = "text/plain; charset=utf-8"; ".md" = "text/plain; charset=utf-8"
    ".pdf"  = "application/pdf";     ".zip" = "application/zip"; ".wasm" = "application/wasm"
}

# ---------- رسالة بسيطة إلى المقبس ----------
function Send-Bytes {
    param([System.Net.Sockets.NetworkStream]$Stream, [byte[]]$Bytes)
    try { $Stream.Write($Bytes, 0, $Bytes.Length); $Stream.Flush() } catch { }
}

function Send-Text {
    param([System.Net.Sockets.NetworkStream]$Stream, [string]$Text, [string]$Status = "200 OK", [string]$Type = "text/html; charset=utf-8")
    $body = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $head = "HTTP/1.1 $Status`r`n" +
        "Content-Type: $Type`r`n" +
        "Content-Length: $($body.Length)`r`n" +
        "Cache-Control: no-store`r`n" +
        "X-Content-Type-Options: nosniff`r`n" +
        "Connection: close`r`n`r`n"
    Send-Bytes $Stream ([System.Text.Encoding]::ASCII.GetBytes($head))
    Send-Bytes $Stream $body
}

# ---------- معالج الطلب الواحد ----------
function Handle-Client {
    param([System.Net.Sockets.TcpClient]$Client)
    try {
        $stream = $Client.GetStream()
        $stream.ReadTimeout = 5000
        # قراءة سطر الطلب الأول فقط (GET /path HTTP/1.1)
        $crlf = 0
        $line = ""
        while ($crlf -lt 2) {
            $b = $stream.ReadByte()
            if ($b -lt 0) { break }
            $line += [char]$b
            if ($line.EndsWith("`r`n")) { break }
        }
        if (-not $line) { return }
        if ($line -notmatch '^GET\s+(\S+)\s+HTTP') {
            Send-Text $stream "Method Not Allowed" "405 Method Not Allowed"
            return
        }
        $rawPath = $Matches[1]
        $path = $rawPath
        $qi = $path.IndexOf('?'); if ($qi -ge 0) { $path = $path.Substring(0, $qi) }
        try { $decoded = [System.Uri]::UnescapeDataString($path) } catch { $decoded = $path }
        if ($decoded -match '\.\.' -or $decoded -match '\.\.+') {
            Send-Text $stream "Forbidden" "403 Forbidden"
            return
        }
        $rel = $decoded.TrimStart('/').Replace('/', '\')
        $full = Join-Path $Root $rel
        if ([System.IO.Path]::GetFullPath($full) -notlike "$Root*") {
            Send-Text $stream "Forbidden" "403 Forbidden"; return
        }
        if (Test-Path -LiteralPath $full -PathType Container) {
            $full = Join-Path $full "index.html"
        }
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            Send-Text $stream "<h1>404 - Not Found</h1><p>$([System.Security.SecurityElement]::Escape($rawPath))</p>" "404 Not Found"
            return
        }
        $ext = [System.IO.Path]::GetExtension($full).ToLower()
        $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $head = "HTTP/1.1 200 OK`r`n" +
            "Content-Type: $type`r`n" +
            "Content-Length: $($bytes.Length)`r`n" +
            "Cache-Control: public, max-age=300`r`n" +
            "X-Content-Type-Options: nosniff`r`n" +
            "Connection: close`r`n`r`n"
        Send-Bytes $stream ([System.Text.Encoding]::ASCII.GetBytes($head))
        Send-Bytes $stream $bytes
    } catch { try { Add-Content -LiteralPath "C:\NetworkMaintenance\Share\server-debug.log" -Value "[$(Get-Date)] ERR: $($_.Exception.Message) | LINE: $line" } catch { } }
    finally {
        try { Start-Sleep -Milliseconds 80; $Client.Close() } catch { }
    }
}

# ---------- جمع عناوين LAN ----------
function Get-LanUrls {
    $urls = @()
    try {
        $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }
        foreach ($ip in $ips) { $urls += "http://$($ip.IPAddress):$Port" }
        $wl = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like '169.254.*' }
        foreach ($ip in $wl) { $urls += "http://$($ip.IPAddress):$Port (كتابة ذاتية)" }
    } catch {
        try { $urls += "http://$([System.Net.Dns]::GetHostName()):$Port (اسم المضيف)" } catch { }
    }
    $urls += "http://localhost:$Port (على هذا الجهاز)"
    return @($urls | Select-Object -Unique)
}

# ---------- قواعد جدار الحماية (تتطلب إدارة) ----------
if ($Firewall) {
    try {
        $null = New-NetFirewallRule -DisplayName "Elias Pro Publish $Port" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -ErrorAction Stop
        Write-Host "قاعدة جدار الحماية أُضيفت للمنفذ $Port" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] أضف قاعدة جدار الحماية كمسؤول:" -ForegroundColor Yellow
        Write-Host "  netsh advfirewall firewall add rule name=EliasPro name=$Port dir=in action=allow protocol=TCP localport=$Port"
    }
}

# ---------- الإقلاع ----------
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
$listener.Start()
$urls = Get-LanUrls

if (-not $Quiet) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  الياس برو — النشر الاحترافي للمشاركة مع العملاء" -ForegroundColor Cyan
    Write-Host "  Elias Pro v4.8.0 — Share Server (PS only, no deps)" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  🖥️  غرفة التحكم  :  $("{0}/Dashboard/app.html" -f $urls[0])" 
    Write-Host "  🔍  التشخيص العميق: $("{0}/Dashboard/deep.html" -f $urls[0])"
    Write-Host ""
    Write-Host "  روابط الشبكة المحلية (شاركها مع العملاء):" -ForegroundColor Yellow
    foreach ($u in $urls) { Write-Host "    • $u" -ForegroundColor White }
    Write-Host ""
    Write-Host "  يفحص الجهاز تلقائيًا: desktop / mobile / tablet عبر deep.html" -ForegroundColor Gray
    Write-Host "  اضغط Ctrl+C للإيقاف."
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

# اختبار ذاتي فوري (اختياري)
if (-not $Quiet) {
    Start-Sleep -Milliseconds 250
    $probeOk = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($probeOk) { Write-Host "  ✓ الخادم يستمع على المنفذ $Port (اختبار ذاتي نجح)" -ForegroundColor Green }
    else { Write-Host "  ⚠ الخادم يعمل لكن المنفذ لم يستجب للاختبار — تحقق من جدار الحماية" -ForegroundColor Yellow }
    Write-Host ""
}

while ($true) {
    try {
        $client = $listener.AcceptTcpClient()
        $client.NoDelay = $true
        Handle-Client $client | Out-Null
    } catch {
        Start-Sleep -Milliseconds 120
    }
}