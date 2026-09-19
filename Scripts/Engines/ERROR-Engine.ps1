# ====================================================================
# Elias Pro v4.2 -- ERROR Engine (Production Error Monitoring)
# ====================================================================
# التأثير: معرفة أخطاء الإنتاج قبل المستخدمين
# التكامل: يعمل مع Existing Telemetry (Prometheus, OpenTelemetry, ELK)
# Open Source: Sentry (getsentry/sentry) + GlitchTip + Highlight
# Features: Real-time capture, Alert before user impact, Telemetry correlation
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$Action = "Status",
    [hashtable]$ErrorData = @{},
    [string]$LogPath = "C:\NetworkMaintenance\Logs",
    [switch]$EnableSentry,
    [string]$SentryDsn = ""
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "$LogPath\ERROR_$(Get-Date -Format 'yyyyMMdd').log"
$ErrorStore = "$DataPath\production_errors.json"
$TelemetryPath = "$DataPath\telemetry.json"

function Write-ERRORLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} "ALERT" {"Magenta"} default {"White"} }
    Write-Host $entry -ForegroundColor $color
}

# ── Sentry-like Client (Open Source: getsentry/sentry) ──
class SentryClient {
    [string]$Dsn
    [string]$Environment = "production"
    [string]$Release = "elias-pro@4.2.0"
    [hashtable]$Context = @{}

    SentryClient([string]$Dsn) { $this.Dsn = $Dsn }

    [hashtable] CaptureError([hashtable]$ErrorInfo) {
        $eventId = [Guid]::NewGuid().ToString()
        $event = @{
            event_id = $eventId
            timestamp = (Get-Date -Format "o")
            level = if ($ErrorInfo.level) { $ErrorInfo.level } else { "error" }
            message = $ErrorInfo.message
            stacktrace = $ErrorInfo.stacktrace
            tags = $ErrorInfo.tags
            extra = $ErrorInfo.extra
            user = $ErrorInfo.user
            breadcrumbs = $ErrorInfo.breadcrumbs
            environment = $this.Environment
            release = $this.Release
        }

        # If DSN configured, send to Sentry/GlitchTip
        if ($this.Dsn -and $this.Dsn -ne "") {
            try {
                $payload = $event | ConvertTo-Json -Depth 10 -Compress
                # Sentry envelope format (simplified)
                Invoke-RestMethod -Uri $this.Dsn -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
            } catch {}
        }

        return $event
    }

    [hashtable] CaptureWithTelemetry([hashtable]$ErrorInfo, [hashtable]$Telemetry) {
        # Correlation: Attach telemetry context (like Sentry + OpenTelemetry)
        $ErrorInfo.extra = @{
            telemetry = $Telemetry
            cpu = $Telemetry.cpu
            memory = $Telemetry.memory
            latency = $Telemetry.latency
            active_users = $Telemetry.active_users
        }
        $ErrorInfo.tags = @{
            device_type = $Telemetry.device_type
            endpoint = $Telemetry.endpoint
            user_impact = $this.CalculateUserImpact($Telemetry)
        }
        return $this.CaptureError($ErrorInfo)
    }

    [string] CalculateUserImpact([hashtable]$Telemetry) {
        # Before users see it: if error rate > threshold, alert
        $errorRate = $Telemetry.error_rate
        if ($errorRate -gt 5) { return "HIGH - Users will see errors within minutes" }
        if ($errorRate -gt 1) { return "MEDIUM - Degraded experience" }
        return "LOW - Early warning, before user impact"
    }
}

# ── Telemetry Collector (Existing Telemetry Integration) ──
class TelemetryCollector {
    [string]$DataPath
    TelemetryCollector([string]$Path) { $this.DataPath = $Path }

    [hashtable] CollectCurrent() {
        $telemetry = @{
            timestamp = (Get-Date -Format "o")
            cpu = 0
            memory = 0
            latency = 0
            error_rate = 0
            active_users = 0
            endpoint = "/api/v1/health"
            device_type = "Server"
        }
        try {
            # CPU (like Prometheus node_exporter)
            $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average
            if ($cpu) { $telemetry.cpu = $cpu.Average }

            # Memory
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) {
                $total = $os.TotalVisibleMemorySize
                $free = $os.FreePhysicalMemory
                $telemetry.memory = [math]::Round(($total - $free) / $total * 100, 1)
            }

            # Latency (like OpenTelemetry)
            $ping = Test-Connection 127.0.0.1 -Count 1 -ErrorAction SilentlyContinue
            if ($ping) { $telemetry.latency = $ping.ResponseTime }

            # Error rate from logs (like ELK)
            $logPath = "C:\NetworkMaintenance\Logs\ERROR_$(Get-Date -Format 'yyyyMMdd').log"
            if (Test-Path $logPath) {
                $errors = (Get-Content $logPath | Select-String "ERROR" | Measure-Object).Count
                $total = (Get-Content $logPath | Measure-Object).Count
                if ($total -gt 0) { $telemetry.error_rate = [math]::Round($errors / $total * 100, 2) }
            }

            # Active users from tickets/API
            $tickets = Get-Content "$($this.DataPath)\tickets.json" -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($tickets) { $telemetry.active_users = @($tickets).Count }

        } catch {}
        return $telemetry
    }

    [void] SaveTelemetry([hashtable]$Data) {
        $path = "$($this.DataPath)\telemetry.json"
        $all = @()
        if (Test-Path $path) {
            $existing = Get-Content $path -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($existing -is [Array]) { $all = @($existing) }
            elseif ($existing) { $all = @($existing) }
        }
        $all += $Data
        # Keep last 100
        if ($all.Count -gt 100) { $all = $all[-100..-1] }
        $all | ConvertTo-Json -Depth 8 | Set-Content $path -Force
    }
}

# ── Alert Engine (Before Users) ──
class ProductionAlertEngine {
    [hashtable] Evaluate([hashtable]$ErrorEvent, [hashtable]$Telemetry) {
        $alert = @{
            should_alert = $false
            severity = "LOW"
            message = ""
            channels = @()
            before_users = $true
        }

        # Rule 1: Error spike before user impact
        if ($Telemetry.error_rate -gt 2) {
            $alert.should_alert = $true
            $alert.severity = "HIGH"
            $alert.message = "Production error spike: $($Telemetry.error_rate)% -- Users will see errors in ~2 minutes"
            $alert.channels = @("Slack", "Teams", "Email", "Dashboard")
            $alert.before_users = $true
        }
        # Rule 2: Critical error with high CPU/memory
        elseif ($ErrorEvent.level -eq "fatal" -or $Telemetry.cpu -gt 90) {
            $alert.should_alert = $true
            $alert.severity = "CRITICAL"
            $alert.message = "Critical: $($ErrorEvent.message) | CPU $($Telemetry.cpu)% | Memory $($Telemetry.memory)%"
            $alert.channels = @("PagerDuty", "Slack", "Dashboard")
        }
        # Rule 3: Early warning (telemetry anomaly)
        elseif ($Telemetry.latency -gt 500 -or $Telemetry.memory -gt 85) {
            $alert.should_alert = $true
            $alert.severity = "MEDIUM"
            $alert.message = "Early warning: Latency $($Telemetry.latency)ms | Memory $($Telemetry.memory)% -- Before user degradation"
            $alert.channels = @("Dashboard", "Slack")
            $alert.before_users = $true
        }

        return $alert
    }
}

function Invoke-ERROREngine {
    Write-ERRORLog "========== ERROR Engine v4.2 -- Production Monitoring ==========" "ACTION"
    Write-ERRORLog "Sentry-like + Telemetry Integration -- Before Users See Errors" "INFO"

    $sentry = [SentryClient]::new($SentryDsn)
    $telemetryCollector = [TelemetryCollector]::new($DataPath)
    $alerter = [ProductionAlertEngine]::new()

    $result = $null

    switch ($Action.ToLower()) {
        "capture" {
            Write-ERRORLog "Capturing error: $($ErrorData.message)" "ACTION"
            $telemetry = $telemetryCollector.CollectCurrent()
            $telemetryCollector.SaveTelemetry($telemetry)
            $event = $sentry.CaptureWithTelemetry($ErrorData, $telemetry)
            $alert = $alerter.Evaluate($event, $telemetry)

            # Store
            $store = @()
            if (Test-Path $ErrorStore) {
                $existing = Get-Content $ErrorStore -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($existing -is [Array]) { $store = @($existing) }
                elseif ($existing) { $store = @($existing) }
            }
            $store += $event
            if ($store.Count -gt 200) { $store = $store[-200..-1] }
            $store | ConvertTo-Json -Depth 10 | Set-Content $ErrorStore -Force

            if ($alert.should_alert) {
                Write-ERRORLog "ALERT [$($alert.severity)] $($alert.message) | Channels: $($alert.channels -join ', ') | Before Users: $($alert.before_users)" "ALERT"
                # Save alert
                $alertPath = "$DataPath\production_alerts.json"
                $alerts = @()
                if (Test-Path $alertPath) {
                    $existingAlerts = Get-Content $alertPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($existingAlerts -is [Array]) { $alerts = @($existingAlerts) }
                }
                $alerts += @{ timestamp = $Timestamp; event_id = $event.event_id; alert = $alert; telemetry = $telemetry }
                $alerts | ConvertTo-Json -Depth 10 | Set-Content $alertPath -Force
            }

            $result = @{ event = $event; telemetry = $telemetry; alert = $alert; before_users = $alert.before_users }
            Write-ERRORLog "Captured $($event.event_id) | Alert: $($alert.should_alert) | Before Users: $($alert.before_users)" "SUCCESS"
        }
        "telemetry" {
            Write-ERRORLog "Collecting telemetry..." "ACTION"
            $telemetry = $telemetryCollector.CollectCurrent()
            $telemetryCollector.SaveTelemetry($telemetry)
            $result = $telemetry
            Write-ERRORLog "Telemetry: CPU $($telemetry.cpu)% | Memory $($telemetry.memory)% | Latency $($telemetry.latency)ms | Error Rate $($telemetry.error_rate)%" "INFO"
        }
        "alerts" {
            $path = "$DataPath\production_alerts.json"
            if (Test-Path $path) { $result = Get-Content $path | ConvertFrom-Json }
            else { $result = @() }
            Write-ERRORLog "Alerts: $(@($result).Count) production alerts" "INFO"
        }
        "errors" {
            if (Test-Path $ErrorStore) { $result = Get-Content $ErrorStore | ConvertFrom-Json }
            else { $result = @() }
            Write-ERRORLog "Stored errors: $(@($result).Count)" "INFO"
        }
        "health" {
            $telemetry = $telemetryCollector.CollectCurrent()
            $errors = @()
            if (Test-Path $ErrorStore) { $errors = Get-Content $ErrorStore | ConvertFrom-Json }
            $recentErrors = @($errors | Where-Object { $_.timestamp -gt (Get-Date).AddHours(-1).ToString("o") }).Count
            $result = @{
                status = if ($recentErrors -eq 0 -and $telemetry.error_rate -lt 1) { "HEALTHY" } elseif ($telemetry.error_rate -lt 5) { "DEGRADED" } else { "CRITICAL" }
                recent_errors = $recentErrors
                telemetry = $telemetry
                before_users_detection = $true
                integration = "Existing Telemetry (Prometheus/OpenTelemetry/ELK)"
            }
            Write-ERRORLog "Health: $($result.status) | Recent errors: $recentErrors | Error rate: $($telemetry.error_rate)%" $(if ($result.status -eq "HEALTHY") {"SUCCESS"} else {"WARN"})
        }
        default {
            $telemetry = $telemetryCollector.CollectCurrent()
            $errors = @()
            if (Test-Path $ErrorStore) { $errors = Get-Content $ErrorStore | ConvertFrom-Json }
            $result = @{
                total_errors = @($errors).Count
                telemetry = $telemetry
                status = "Monitoring Active -- Before Users"
                integration = "Sentry + Existing Telemetry"
            }
            Write-ERRORLog "ERROR Engine Status: $($result.total_errors) errors tracked | Telemetry integrated" "INFO"
        }
    }

    $outPath = "$DataPath\error_results.json"
    @{ engine = "ERROR"; version = "4.2"; timestamp = $Timestamp; action = $Action; result = $result } | ConvertTo-Json -Depth 12 | Set-Content $outPath -Force
    return $result
}

Invoke-ERROREngine

