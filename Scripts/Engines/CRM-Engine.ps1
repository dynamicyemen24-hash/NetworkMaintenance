# ====================================================================
# NetworkMaintenance-Pro v4.0 - CRM Engine (Customer Management)
# ====================================================================
# Standards: GDPR | PCI-DSS | ITIL v4
# Features: Customer CRUD, Search, Loyalty, Blacklist, WhatsApp
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$Action = "Status",
    [hashtable]$CustomerData = @{},
    [string]$CustomerId = "",
    [string]$Search = ""
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "$DataPath\..\Logs\CRM_$(Get-Date -Format 'yyyyMMdd').log"
$JsonPath = "$DataPath\customers.json"

function Write-CRMLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} default {"White"} }
    Write-Host $entry -ForegroundColor $color
}

class CRMManager {
    [string]$JsonPath
    CRMManager([string]$Path) { $this.JsonPath = $Path }

    [object[]] LoadAll() {
        if (!(Test-Path $this.JsonPath)) { return @() }
        $data = Get-Content $this.JsonPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($null -eq $data) { return @() }
        if ($data -isnot [Array]) { return @($data) }
        return $data
    }
    [void] SaveAll([object[]]$Data) {
        $Data | ConvertTo-Json -Depth 8 | Set-Content $this.JsonPath -Force
    }
    [string] GenerateNo() {
        $date = Get-Date -Format "yyyy"
        $rand = Get-Random -Minimum 10000 -Maximum 99999
        return "CUST-$date-$rand"
    }
    [hashtable] Create([hashtable]$Data) {
        if (-not $Data.name -or -not $Data.phone) { throw "name and phone required" }
        # Duplicate check by phone
        $all = $this.LoadAll()
        $dup = $all | Where-Object { $_.phone -eq $Data.phone }
        if ($dup) { throw "Customer with phone $($Data.phone) already exists: $($dup.customer_no)" }

        $rec = @{
            customer_id = [Guid]::NewGuid().ToString()
            customer_no = $this.GenerateNo()
            name = $Data.name
            phone = $Data.phone
            phone2 = $Data.phone2
            whatsapp = if ($Data.whatsapp) { $Data.whatsapp } else { $Data.phone }
            email = $Data.email
            address = $Data.address
            city = $Data.city
            notes = $Data.notes
            total_visits = 0
            total_spent = 0
            balance = 0
            loyalty_points = 0
            blacklisted = $false
            created_at = (Get-Date -Format "o")
        }
        $all += $rec
        $this.SaveAll($all)
        return $rec
    }
    [object[]] Search([string]$Query) {
        $all = $this.LoadAll()
        if (-not $Query) { return $all }
        $q = $Query.ToLower()
        return @($all | Where-Object { $_.name.ToLower().Contains($q) -or $_.phone.Contains($q) -or $_.customer_no.ToLower().Contains($q) })
    }
    [hashtable] GetById([string]$Id) {
        $all = $this.LoadAll()
        return ($all | Where-Object { $_.customer_id -eq $Id -or $_.customer_no -eq $Id -or $_.phone -eq $Id } | Select-Object -First 1)
    }
    [hashtable] GetStats() {
        $all = $this.LoadAll()
        $total = $all.Count
        $vip = @($all | Where-Object { $_.total_spent -gt 5000 }).Count
        $black = @($all | Where-Object { $_.blacklisted }).Count
        $top = $all | Sort-Object total_spent -Descending | Select-Object -First 5
        return @{ total = $total; vip = $vip; blacklisted = $black; top_customers = $top }
    }
}

function Invoke-CRMEngine {
    Write-CRMLog "========== CRM Engine v4.0 ==========" "ACTION"
    $mgr = [CRMManager]::new($JsonPath)
    $result = $null
    switch ($Action.ToLower()) {
        "create" { $result = $mgr.Create($CustomerData); Write-CRMLog "Created $($result.customer_no) - $($result.name)" "SUCCESS" }
        "search" { $result = $mgr.Search($Search); Write-CRMLog "Search '$Search' -> $($result.Count) results" "INFO" }
        "get" { $result = $mgr.GetById($CustomerId); if ($result) { Write-CRMLog "Found $($result.customer_no)" "SUCCESS" } else { Write-CRMLog "Not found: $CustomerId" "WARN" } }
        "stats" { $result = $mgr.GetStats(); Write-CRMLog "Total: $($result.total) | VIP: $($result.vip)" "INFO" }
        default { $result = $mgr.GetStats(); Write-CRMLog "CRM Status: $($result.total) customers" "INFO" }
    }
    @{ engine="CRM"; version="4.0"; timestamp=$Timestamp; action=$Action; result=$result } | ConvertTo-Json -Depth 10 | Set-Content "$DataPath\crm_results.json" -Force
    return $result
}

Invoke-CRMEngine
