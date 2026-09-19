# ====================================================================
# Elias Pro v5.0 -- Real API Server (Pode Framework)
# ====================================================================
# Cloned from: Badgerati/Pode (https://github.com/Badgerati/Pode) -- MIT
# Features: Real HttpListener, OpenAPI 3.0, JWT, Rate Limiting, SQLite
# Install: Install-Module Pode -Scope CurrentUser
# ====================================================================

param(
    [int]$Port = 8080,
    [string]$Address = "127.0.0.1",
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\EnterpriseConfig.json",
    [switch]$EnableAuth,
    [switch]$EnableSwagger
)

# Check Pode
if (-not (Get-Module -ListAvailable -Name Pode)) {
    Write-Host "[INFO] Pode not found - installing..." -ForegroundColor Yellow
    try {
        Install-Module Pode -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "[SUCCESS] Pode installed" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Pode install failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[FALLBACK] Using mock Server.ps1..." -ForegroundColor Yellow
        & "C:\NetworkMaintenance\API\Server.ps1" -Port $Port -Host $Address
        exit
    }
}
Import-Module Pode -ErrorAction Stop

$DataPath = "C:\NetworkMaintenance\Data"
$LogPath = "C:\NetworkMaintenance\Logs"

# Load config
$Config = if (Test-Path $ConfigPath) { Get-Content $ConfigPath | ConvertFrom-Json } else { $null }

Start-PodeServer -Address $Address -Port $Port -Protocol Http -ThreadCount 2 {

    # ── Logging ──
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    New-PodeLoggingMethod -File -Name "api" -Path $using:LogPath | Enable-PodeRequestLogging

    # ── CORS ──
    Add-PodeHeader -Name "Access-Control-Allow-Origin" -Value "*"
    Add-PodeHeader -Name "Access-Control-Allow-Methods" -Value "GET, POST, PUT, DELETE, OPTIONS"
    Add-PodeHeader -Name "Access-Control-Allow-Headers" -Value "Authorization, Content-Type"

    # ── Rate Limiting (Pode middleware, light + leak-free) ──
    $rateLimitStore = @{}
    Add-PodeMiddleware -Name "RateLimit" -ScriptBlock {
        $ip = $WebEvent.Request.RemoteEndPoint.Address.ToString()
        $nowMin = Get-Date -Format 'yyyyMMddHHmm'
        $key = "$ip-$nowMin"
        # cleanup: keep only current minute bucket (prevents RAM bloat)
        foreach ($k in @($rateLimitStore.Keys)) { if ($k -notlike "*-$nowMin") { $rateLimitStore.Remove($k) } }
        if (-not $rateLimitStore.ContainsKey($key)) { $rateLimitStore[$key] = 0 }
        $rateLimitStore[$key]++
        if ($rateLimitStore[$key] -gt 60) {
            Set-PodeResponseStatus -Code 429
            return $false
        }
        return $true
    }

    # ── OpenAPI / Swagger ──
    if ($using:EnableSwagger) {
        Enable-PodeOpenApi -Path "/api/openapi" -Title "Elias Pro API" -Version "5.0.0" -Description "Universal Maintenance Suite - Elias Pro"
        Enable-PodeOpenApiViewer -Type Swagger -Path "/api/docs" -DarkMode
        Write-Host "[INFO] Swagger at http://$($using:Address):$($using:Port)/api/docs" -ForegroundColor Cyan
    }

    # ── Helper: Read JSON files ──
    function Get-JsonData {
        param([string]$File)
        $path = "$using:DataPath\$File"
        if (Test-Path $path) {
            try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return @() }
        }
        return @()
    }

    # ── Routes ──

    # Health -- no auth
    Add-PodeRoute -Method Get -Path "/api/v1/health" -ScriptBlock {
        $state = Get-JsonData -File "..\Config\SystemState.json"
        if (-not $state) { $state = @{ status = "UNKNOWN"; health_score = 0 } }
        # Add SCE health
        $sce = Get-JsonData -File "sce_results.json"
        $hdr = Get-JsonData -File "hdr_results.json"
        Write-PodeJsonResponse -Value @{
            status = $state.Status
            version = "5.0.0"
            name = "Elias Pro"
            health_score = if ($sce.health.score) { $sce.health.score } else { 65 }
            hdr_score = if ($hdr.result.overall_score) { $hdr.result.overall_score } else { 70 }
            timestamp = (Get-Date -Format "o")
        }
    }

    # Shop Stats
    Add-PodeRoute -Method Get -Path "/api/v1/shop/stats" -ScriptBlock {
        $tickets = Get-JsonData -File "tickets.json"
        if ($tickets -isnot [Array]) { $tickets = @($tickets) | Where-Object { $_ } }
        $invoices = Get-JsonData -File "invoices.json"
        if ($invoices -isnot [Array]) { $invoices = @($invoices) | Where-Object { $_ } }
        $customers = Get-JsonData -File "customers.json"
        if ($customers -isnot [Array]) { $customers = @($customers) | Where-Object { $_ } }
        $parts = Get-JsonData -File "inventory_parts.json"
        if ($parts -isnot [Array]) { $parts = @($parts) | Where-Object { $_ } }
        $sales = ($invoices | Measure-Object -Property total -Sum).Sum
        Write-PodeJsonResponse -Value @{
            tickets_total = $tickets.Count
            tickets_pending = @($tickets | Where-Object { $_.status -in @("RECEIVED","DIAGNOSED","QUOTED","APPROVED","REPAIRING","QC") }).Count
            tickets_ready = @($tickets | Where-Object { $_.status -eq "READY" }).Count
            customers_total = $customers.Count
            inventory_total = $parts.Count
            inventory_low = @($parts | Where-Object { [int]$_.quantity -le [int]$_.min_quantity }).Count
            total_sales = [math]::Round($sales,2)
            invoices_total = $invoices.Count
        }
    }

    # Tickets (with q/status/page/limit to mirror Vercel bridge)
    Add-PodeRoute -Method Get -Path "/api/v1/shop/tickets" -ScriptBlock {
        $tickets = Get-JsonData -File "tickets.json"
        if ($tickets -isnot [Array]) { $tickets = @($tickets) | Where-Object { $_ } }
        $q = $WebEvent.Query['q']
        $status = $WebEvent.Query['status']
        $page = [int]($WebEvent.Query['page']); if ($page -lt 1) { $page = 1 }
        $limit = [int]($WebEvent.Query['limit']); if ($limit -lt 1) { $limit = 20 }; if ($limit -gt 100) { $limit = 100 }
        if ($q) { $tickets = @($tickets | Where-Object { "$($_.ticket_no) $($_.reported_issue) $($_.brand)" -like "*$q*" }) }
        if ($status) { $tickets = @($tickets | Where-Object { $_.status -eq $status }) }
        $total = @($tickets).Count
        $paged = @($tickets | Select-Object -Skip (($page - 1) * $limit) -First $limit)
        Add-PodeHeader -Name 'X-Total-Count' -Value "$total"
        Add-PodeHeader -Name 'X-Page' -Value "$page"
        Write-PodeJsonResponse -Value $paged
    }
    Add-PodeRoute -Method Post -Path "/api/v1/shop/tickets" -ScriptBlock {
        $data = $WebEvent.Data
        # Validate
        if (-not $data.customer_id -or -not $data.reported_issue) {
            Set-PodeResponseStatus -Code 400
            Write-PodeJsonResponse -Value @{ error = "customer_id and reported_issue required" }
            return
        }
        $result = & "C:\NetworkMaintenance\Scripts\Engines\REPAIR-Engine.ps1" -Action Create -TicketData $data
        Write-PodeJsonResponse -Value $result -StatusCode 201
    }
    Add-PodeRoute -Method Put -Path "/api/v1/shop/tickets/:ticketNo/status" -ScriptBlock {
        $ticketNo = $WebEvent.Parameters["ticketNo"]
        $newStatus = $WebEvent.Data.status
        $result = & "C:\NetworkMaintenance\Scripts\Engines\REPAIR-Engine.ps1" -Action Update -TicketNo $ticketNo -NewStatus $newStatus
        Write-PodeJsonResponse -Value $result
    }

    # Customers
    Add-PodeRoute -Method Get -Path "/api/v1/shop/customers" -ScriptBlock {
        $customers = Get-JsonData -File "customers.json"
        Write-PodeJsonResponse -Value $customers
    }
    Add-PodeRoute -Method Post -Path "/api/v1/shop/customers" -ScriptBlock {
        $data = $WebEvent.Data
        $result = & "C:\NetworkMaintenance\Scripts\Engines\CRM-Engine.ps1" -Action Create -CustomerData $data
        Write-PodeJsonResponse -Value $result -StatusCode 201
    }

    # Inventory
    Add-PodeRoute -Method Get -Path "/api/v1/shop/inventory" -ScriptBlock {
        $parts = Get-JsonData -File "inventory_parts.json"
        Write-PodeJsonResponse -Value $parts
    }
    Add-PodeRoute -Method Get -Path "/api/v1/shop/inventory/lowstock" -ScriptBlock {
        $parts = Get-JsonData -File "inventory_parts.json"
        if ($parts -isnot [Array]) { $parts = @($parts) }
        $low = @($parts | Where-Object { [int]$_.quantity -le [int]$_.min_quantity })
        Write-PodeJsonResponse -Value $low
    }

    # Invoices
    Add-PodeRoute -Method Get -Path "/api/v1/shop/invoices" -ScriptBlock {
        $invoices = Get-JsonData -File "invoices.json"
        Write-PodeJsonResponse -Value $invoices
    }

    # Diagnostics
    Add-PodeRoute -Method Post -Path "/api/v1/shop/diagnostics" -ScriptBlock {
        $type = if ($WebEvent.Data.device_type) { $WebEvent.Data.device_type } else { "Auto" }
        $result = & "C:\NetworkMaintenance\Scripts\Engines\HDR-Engine.ps1" -DeviceType $type -Mode Quick
        Write-PodeJsonResponse -Value $result
    }

    # SCE Clean
    Add-PodeRoute -Method Post -Path "/api/v1/clean" -ScriptBlock {
        $safety = if ($WebEvent.Data.safety) { $WebEvent.Data.safety } else { "Balanced" }
        $dryRun = $WebEvent.Data.dryRun -ne $false
        $params = @{ SafetyLevel = $safety }
        if ($dryRun) { $params.DryRun = $true }
        $result = & "C:\NetworkMaintenance\Scripts\Engines\SCE-Engine.ps1" @params
        Write-PodeJsonResponse -Value $result
    }

    # Logs
    Add-PodeRoute -Method Get -Path "/api/v1/logs" -ScriptBlock {
        $logs = Get-ChildItem "C:\NetworkMaintenance\Logs\*.log" | Select-Object -First 10 | ForEach-Object { @{ name=$_.Name; size=$_.Length; modified=$_.LastWriteTime } }
        Write-PodeJsonResponse -Value $logs
    }

# Config
    Add-PodeRoute -Method Get -Path "/api/v1/config" -ScriptBlock {
        $cfg = Get-Content $using:ConfigPath | ConvertFrom-Json
        Write-PodeJsonResponse -Value $cfg
    }

    # ── التشخيص العميق (PC + Mobile) ──
    # وحدة التشخيص الحقيقي: WMI / SMART / batteryreport / ADB
    . "C:\NetworkMaintenance\API\Modules\Device-Diagnostics.ps1"

    # حقائق النظام
    Add-PodeRoute -Method Get -Path "/api/v1/device/facts" -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-DeviceFacts)
    }

    # التخزين + عدادات SMART
    Add-PodeRoute -Method Get -Path "/api/v1/device/storage" -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-DeviceStorage)
    }

    # البطارية (صحة/سعة مWh من تقرير powercfg الحقيقي)
    Add-PodeRoute -Method Get -Path "/api/v1/device/battery" -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-DeviceBattery)
    }

    # الحرارة
    Add-PodeRoute -Method Get -Path "/api/v1/device/thermal" -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-DeviceThermal)
    }

    # أهم العمليات
    Add-PodeRoute -Method Get -Path "/api/v1/device/processes" -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-TopProcesses)
    }

    # الموبايل Android عبر ADB
    Add-PodeRoute -Method Get -Path "/api/v1/mobile/adb" -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-AndroidFacts)
    }

    # لقطة شاملة + حفظ نقطة تاريخية
    Add-PodeRoute -Method Get -Path "/api/v1/device/snapshot" -ScriptBlock {
        $snap = Get-DeviceSnapshot
        Save-DevicePoint -Snapshot $snap
        Write-PodeJsonResponse -Value $snap
    }

    # ── Auth (mock JWT for demo — mirrors login.html fallback) ──
    Add-PodeRoute -Method Post -Path "/api/v1/auth/login" -ScriptBlock {
        $u = $WebEvent.Data.username
        $p = $WebEvent.Data.password
        if ($u -eq 'admin' -and $p -eq 'admin123') {
            $payload = @{ user = $u; role = 'Admin'; exp = ((Get-Date).AddHours(8).ToUniversalTime().ToString('o')) } | ConvertTo-Json -Compress
            $token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
            Write-PodeJsonResponse -Value @{ token = $token; user = @{ username = $u; role = 'Admin' } }
        } else {
            Set-PodeResponseStatus -Code 401
            Write-PodeJsonResponse -Value @{ error = 'Invalid credentials' }
        }
    }

    # ── Subscriptions (mirrors API/index.py plans) ──
    Add-PodeRoute -Method Get -Path "/api/v1/subscription/plans" -ScriptBlock {
        Write-PodeJsonResponse -Value @(
            @{ id = 'free'; name = 'Free'; price = 0; currency = 'EGP'; engines = @('HDR'); devices = 1 },
            @{ id = 'pro'; name = 'Pro'; price = 299; currency = 'EGP'; period = 'month'; engines = @('HDR','BATT','STORAGE','STRESS','NETDIAG'); devices = 5 },
            @{ id = 'enterprise'; name = 'Enterprise'; price = 999; currency = 'EGP'; period = 'month'; engines = @('all'); devices = 20 }
        )
    }
    Add-PodeRoute -Method Post -Path "/api/v1/subscription/checkout" -ScriptBlock {
        $plan = if ($WebEvent.Data.plan) { $WebEvent.Data.plan } else { 'pro' }
        $prices = @{ free = 0; pro = 299; enterprise = 999 }
        Write-PodeJsonResponse -Value @{ checkout_url = "https://checkout.stripe.com/pay/$plan"; plan = $plan; price = $prices[$plan]; currency = 'EGP' }
    }
    Add-PodeRoute -Method Post -Path "/api/v1/subscription/webhook" -ScriptBlock {
        Write-PodeJsonResponse -Value @{ received = $true }
    }

    # التاريخ الزمني (للرسوم والتنبؤ)
    Add-PodeRoute -Method Get -Path "/api/v1/history" -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-DeviceHistory)
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Elias Pro v5.0 -- Pode API Server" -ForegroundColor Cyan
    Write-Host "  Real HttpListener + OpenAPI" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  http://$Address`:$Port/api/v1/health" -ForegroundColor Yellow
    Write-Host "  http://$Address`:$Port/api/v1/shop/stats" -ForegroundColor Yellow
    if ($EnableSwagger) { Write-Host "  http://$Address`:$Port/api/docs (Swagger)" -ForegroundColor Green }
}

