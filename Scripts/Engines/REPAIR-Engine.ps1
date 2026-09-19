# ====================================================================
# NetworkMaintenance-Pro v4.0 - REPAIR Engine (Ticket Lifecycle)
# ====================================================================
# Methodology: ITIL v4 Incident + SRE Workflow + State Machine
# Standards: ITIL v4 | ISO 27001 | PCI-DSS
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\UniversalConfig.json",
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$Action = "Status",
    [string]$TicketNo = "",
    [hashtable]$TicketData = @{},
    [string]$NewStatus = ""
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$DBPath = "$DataPath\repair_shop.db"
$LogFile = "$DataPath\..\Logs\REPAIR_$(Get-Date -Format 'yyyyMMdd').log"

function Write-REPAIRLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    switch ($Level) {
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARN" { Write-Host $entry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        "ACTION" { Write-Host $entry -ForegroundColor Cyan }
        default { Write-Host $entry -ForegroundColor White }
    }
}

# ── State Machine ──
class RepairStateMachine {
    [hashtable]$Transitions = @{}
    [string[]]$AllStatuses = @("RECEIVED","DIAGNOSED","QUOTED","APPROVED","REPAIRING","QC","READY","DELIVERED","CANCELLED","WARRANTY")

    RepairStateMachine() {
        $this.Transitions = @{
            "RECEIVED"  = @("DIAGNOSED","CANCELLED")
            "DIAGNOSED" = @("QUOTED","CANCELLED")
            "QUOTED"    = @("APPROVED","CANCELLED")
            "APPROVED"  = @("REPAIRING","CANCELLED")
            "REPAIRING" = @("QC","CANCELLED")
            "QC"        = @("READY","REPAIRING")
            "READY"     = @("DELIVERED","WARRANTY")
            "DELIVERED" = @("WARRANTY")
            "WARRANTY"  = @("REPAIRING","DELIVERED")
            "CANCELLED" = @()
        }
    }
    [bool] CanTransition([string]$From, [string]$To) {
        if (-not $this.Transitions.ContainsKey($From)) { return $false }
        return $To -in $this.Transitions[$From]
    }
    [string[]] GetNextStatuses([string]$Current) {
        if ($this.Transitions.ContainsKey($Current)) { return $this.Transitions[$Current] }
        return @()
    }
}

# ── Ticket Manager ──
class TicketManager {
    [string]$DBPath
    [RepairStateMachine]$SM

    TicketManager([string]$DBPath) {
        $this.DBPath = $DBPath
        $this.SM = [RepairStateMachine]::new()
        $this.EnsureDB()
    }

    [void] EnsureDB() {
        if (!(Test-Path $this.DBPath)) {
            $schema = Get-Content "C:\NetworkMaintenance\Data\repair_shop_schema.sql" -Raw -ErrorAction SilentlyContinue
            if ($schema) {
                # Create via sqlite3 if available, else create empty and log
                try {
                    $tmp = "$env:TEMP\schema_init.sql"
                    Set-Content $tmp $schema -Force
                    if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
                        & sqlite3 $this.DBPath ".read $tmp" 2>$null
                    } else {
                        # Fallback: create DB file so path exists
                        New-Item -ItemType File -Path $this.DBPath -Force | Out-Null
                    }
                } catch {}
            }
        }
    }

    [string] GenerateTicketNo() {
        $prefix = "TKT-{0:yyyy}-{0:MM}" -f (Get-Date)
        # Simple counter based on existing files + random
        $rand = Get-Random -Minimum 1000 -Maximum 9999
        return "$prefix-$rand"
    }

    [hashtable] CreateTicket([hashtable]$Data) {
        $ticketNo = $this.GenerateTicketNo()
        $ticketId = [Guid]::NewGuid().ToString()
        $customerId = $Data.customer_id
        if (-not $customerId) { throw "customer_id required" }

        $record = @{
            ticket_id = $ticketId
            ticket_no = $ticketNo
            customer_id = $customerId
            device_type = $Data.device_type
            brand = $Data.brand
            model = $Data.model
            serial_number = $Data.serial_number
            imei = $Data.imei
            reported_issue = $Data.reported_issue
            status = "RECEIVED"
            priority = if ($Data.priority) { $Data.priority } else { "NORMAL" }
            estimated_cost = if ($Data.estimated_cost) { $Data.estimated_cost } else { 0 }
            received_at = (Get-Date -Format "o")
        }

        # Try SQLite, fallback to JSON file
        $jsonPath = "C:\NetworkMaintenance\Data\tickets.json"
        try {
            $all = @()
            if (Test-Path $jsonPath) { $all = Get-Content $jsonPath | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($all -isnot [Array]) { $all = @($all) } }
            $all += $record
            $all | ConvertTo-Json -Depth 8 | Set-Content $jsonPath -Force
        } catch {}

        return $record
    }

    [hashtable] UpdateStatus([string]$TicketNo, [string]$NewStatus, [string]$Notes) {
        $jsonPath = "C:\NetworkMaintenance\Data\tickets.json"
        if (!(Test-Path $jsonPath)) { throw "Ticket not found: $TicketNo" }
        $all = Get-Content $jsonPath | ConvertFrom-Json
        if ($all -isnot [Array]) { $all = @($all) }
        $found = $null
        foreach ($t in $all) {
            if ($t.ticket_no -eq $TicketNo) { $found = $t; break }
        }
        if (-not $found) { throw "Ticket $TicketNo not found" }

        $current = $found.status
        if (-not $this.SM.CanTransition($current, $NewStatus)) {
            throw "Invalid transition: $current -> $NewStatus. Allowed: $($this.SM.GetNextStatuses($current) -join ', ')"
        }

        $found.status = $NewStatus
        $found.updated_at = (Get-Date -Format "o")
        # Set timestamp fields
        $fieldMap = @{ "DIAGNOSED"="diagnosed_at"; "QUOTED"="quoted_at"; "APPROVED"="approved_at"; "REPAIRING"="started_at"; "READY"="completed_at"; "DELIVERED"="delivered_at" }
        if ($fieldMap.ContainsKey($NewStatus)) { $found.($fieldMap[$NewStatus]) = (Get-Date -Format "o") }

        $all | ConvertTo-Json -Depth 8 | Set-Content $jsonPath -Force

        # History
        $histPath = "C:\NetworkMaintenance\Data\ticket_history.json"
        $hist = @(); if (Test-Path $histPath) { $hist = Get-Content $histPath | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($hist -isnot [Array]) { $hist = @($hist) } }
        $hist += @{ ticket_no = $TicketNo; from = $current; to = $NewStatus; notes = $Notes; at = (Get-Date -Format "o") }
        $hist | ConvertTo-Json -Depth 6 | Set-Content $histPath -Force

        return @{ ticket_no = $TicketNo; from = $current; to = $NewStatus; success = $true }
    }

    [object[]] ListTickets([string]$StatusFilter) {
        $jsonPath = "C:\NetworkMaintenance\Data\tickets.json"
        if (!(Test-Path $jsonPath)) { return @() }
        $all = Get-Content $jsonPath | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($all -isnot [Array]) { $all = @($all) }
        if ($StatusFilter) { return @($all | Where-Object { $_.status -eq $StatusFilter }) }
        return $all
    }

    [hashtable] GetStats() {
        $tickets = $this.ListTickets("")
        $byStatus = $tickets | Group-Object status | ForEach-Object { @{ status = $_.Name; count = $_.Count } }
        return @{
            total = $tickets.Count
            by_status = $byStatus
            pending = @($tickets | Where-Object { $_.status -in @("RECEIVED","DIAGNOSED","QUOTED","APPROVED","REPAIRING","QC") }).Count
            ready = @($tickets | Where-Object { $_.status -eq "READY" }).Count
            delivered = @($tickets | Where-Object { $_.status -eq "DELIVERED" }).Count
        }
    }
}

function Invoke-REPAIREngine {
    Write-REPAIRLog "========== REPAIR Engine v4.0 ==========" "ACTION"
    Write-REPAIRLog "Action: $Action | Ticket: $TicketNo -> $NewStatus" "INFO"

    $mgr = [TicketManager]::new($DBPath)
    $result = $null

    switch ($Action.ToLower()) {
        "create" {
            $result = $mgr.CreateTicket($TicketData)
            Write-REPAIRLog "Created $($result.ticket_no) for $($result.customer_id)" "SUCCESS"
        }
        "update" {
            $result = $mgr.UpdateStatus($TicketNo, $NewStatus, $TicketData.notes)
            Write-REPAIRLog "Status $($result.from) -> $($result.to)" "SUCCESS"
        }
        "list" {
            $result = $mgr.ListTickets($NewStatus)
            Write-REPAIRLog "Found $($result.Count) tickets (filter: $NewStatus)" "INFO"
        }
        "stats" {
            $result = $mgr.GetStats()
            Write-REPAIRLog "Stats: Total $($result.total) | Pending $($result.pending) | Ready $($result.ready)" "INFO"
        }
        default {
            $result = $mgr.GetStats()
            Write-REPAIRLog "Status: Total $($result.total) tickets" "INFO"
        }
    }

    $outPath = "C:\NetworkMaintenance\Data\repair_results.json"
    @{ engine = "REPAIR"; version = "4.0"; timestamp = $Timestamp; action = $Action; result = $result } | ConvertTo-Json -Depth 10 | Set-Content $outPath -Force
    Write-REPAIRLog "Results -> $outPath" "SUCCESS"
    return $result
}

Invoke-REPAIREngine
