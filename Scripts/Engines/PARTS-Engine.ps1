# ====================================================================
# NetworkMaintenance-Pro v4.0 - PARTS Engine (Inventory - Spare Parts)
# ====================================================================
# Features: Barcode/QR, Low Stock Alerts, Bin Location, Supplier Link
# Standards: ISO 27001 | ITIL v4
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$Action = "Status",
    [hashtable]$PartData = @{},
    [string]$SKU = "",
    [string]$Category = ""
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "$DataPath\..\Logs\PARTS_$(Get-Date -Format 'yyyyMMdd').log"
$JsonPath = "$DataPath\inventory_parts.json"

function Write-PARTSLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} default {"White"} }
    Write-Host $entry -ForegroundColor $color
}

class PartsManager {
    [string]$JsonPath
    PartsManager([string]$Path) { $this.JsonPath = $Path }
    [object[]] LoadAll() {
        if (!(Test-Path $this.JsonPath)) { return @() }
        $d = Get-Content $this.JsonPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($null -eq $d) { return @() }
        if ($d -isnot [Array]) { return @($d) }
        return $d
    }
    [void] SaveAll([object[]]$Data) { $Data | ConvertTo-Json -Depth 8 | Set-Content $this.JsonPath -Force }
    [string] GenerateSKU([string]$Category, [string]$Brand) {
        $cat = if ($Category) { $Category.Substring(0, [Math]::Min(3,$Category.Length)).ToUpper() } else { "GEN" }
        $br = if ($Brand) { $Brand.Substring(0, [Math]::Min(2,$Brand.Length)).ToUpper() } else { "GN" }
        $rand = Get-Random -Minimum 1000 -Maximum 9999
        return "SKU-$cat-$br-$rand"
    }
    [string] GenerateBarcode() {
        # EAN-13 mock: 622 prefix (Egypt) + 9 random + check digit
        $base = "622" + (Get-Random -Minimum 100000000 -Maximum 999999999).ToString()
        # Simple check digit
        $sum = 0; for ($i=0; $i -lt $base.Length; $i++) { $d=[int]$base[$i].ToString(); $sum += if ($i %2 -eq 0) { $d } else { $d*3 } }
        $check = (10 - ($sum %10)) %10
        return "$base$check"
    }
    [hashtable] AddPart([hashtable]$Data) {
        if (-not $Data.name) { throw "name required" }
        $all = $this.LoadAll()
        $sku = if ($Data.sku) { $Data.sku } else { $this.GenerateSKU($Data.category, $Data.brand) }
        if ($all | Where-Object { $_.sku -eq $sku }) { throw "SKU $sku already exists" }
        $rec = @{
            part_id = [Guid]::NewGuid().ToString()
            sku = $sku
            barcode = $this.GenerateBarcode()
            qr_code = "QR-$sku"
            name = $Data.name
            category = if ($Data.category) { $Data.category } else { "General" }
            brand = $Data.brand
            compatible_models = $Data.compatible_models
            location_bin = $Data.location_bin
            quantity = if ($null -ne $Data.quantity) { [int]$Data.quantity } else { 0 }
            min_quantity = if ($null -ne $Data.min_quantity) { [int]$Data.min_quantity } else { 2 }
            unit_cost = [double]$Data.unit_cost
            unit_price = [double]$Data.unit_price
            supplier_id = $Data.supplier_id
            is_original = [bool]$Data.is_original
            created_at = (Get-Date -Format "o")
        }
        $all += $rec
        $this.SaveAll($all)
        return $rec
    }
    [hashtable] AdjustStock([string]$SKU, [int]$Delta, [string]$Reason) {
        $all = $this.LoadAll()
        $part = $all | Where-Object { $_.sku -eq $SKU -or $_.barcode -eq $SKU } | Select-Object -First 1
        if (-not $part) { throw "Part not found: $SKU" }
        $part.quantity = [int]$part.quantity + $Delta
        if ($part.quantity -lt 0) { $part.quantity = 0 }
        $this.SaveAll($all)
        # Log movement
        $logPath = "C:\NetworkMaintenance\Data\stock_movements.json"
        $movs = @(); if (Test-Path $logPath) { $movs = Get-Content $logPath | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($movs -isnot [Array]) { $movs=@($movs) } }
        $movs += @{ sku=$SKU; delta=$Delta; reason=$Reason; new_qty=$part.quantity; at=(Get-Date -Format "o") }
        $movs | ConvertTo-Json -Depth 6 | Set-Content $logPath -Force
        return @{ sku=$SKU; new_quantity=$part.quantity; delta=$Delta }
    }
    [object[]] LowStock() {
        $all = $this.LoadAll()
        return @($all | Where-Object { [int]$_.quantity -le [int]$_.min_quantity })
    }
    [object[]] Search([string]$Cat) {
        $all = $this.LoadAll()
        if (-not $Cat) { return $all }
        return @($all | Where-Object { $_.category -eq $Cat -or $_.name.ToLower().Contains($Cat.ToLower()) -or $_.sku -eq $Cat })
    }
    [hashtable] GetStats() {
        $all = $this.LoadAll()
        $total = $all.Count
        $low = $this.LowStock().Count
        $totalValue = ($all | ForEach-Object { [int]$_.quantity * [double]$_.unit_cost } | Measure-Object -Sum).Sum
        $totalRetail = ($all | ForEach-Object { [int]$_.quantity * [double]$_.unit_price } | Measure-Object -Sum).Sum
        $byCat = $all | Group-Object category | ForEach-Object { @{ category=$_.Name; count=$_.Count } }
        return @{ total_parts=$total; low_stock=$low; total_cost_value=[math]::Round($totalValue,2); total_retail_value=[math]::Round($totalRetail,2); expected_profit=[math]::Round($totalRetail-$totalValue,2); by_category=$byCat }
    }
}

function Invoke-PARTSEngine {
    Write-PARTSLog "========== PARTS Engine v4.0 ==========" "ACTION"
    $mgr = [PartsManager]::new($JsonPath)
    $result = $null
    switch ($Action.ToLower()) {
        "add" { $result = $mgr.AddPart($PartData); Write-PARTSLog "Added $($result.sku) - $($result.name) Qty:$($result.quantity)" "SUCCESS" }
        "adjust" { $result = $mgr.AdjustStock($SKU, [int]$PartData.delta, $PartData.reason); Write-PARTSLog "Stock $SKU -> $($result.new_quantity) (delta $($result.delta))" "SUCCESS" }
        "lowstock" { $result = $mgr.LowStock(); Write-PARTSLog "Low stock: $($result.Count) items" "WARN" }
        "search" { $result = $mgr.Search($Category); Write-PARTSLog "Search '$Category' -> $($result.Count)" "INFO" }
        "stats" { $result = $mgr.GetStats(); Write-PARTSLog "Parts: $($result.total_parts) | Low: $($result.low_stock) | Value: $($result.total_retail_value) EGP" "INFO" }
        default { $result = $mgr.GetStats(); Write-PARTSLog "Inventory: $($result.total_parts) parts | Low: $($result.low_stock)" "INFO" }
    }
    @{ engine="PARTS"; version="4.0"; timestamp=$Timestamp; action=$Action; result=$result } | ConvertTo-Json -Depth 10 | Set-Content "$DataPath\parts_results.json" -Force
    return $result
}

Invoke-PARTSEngine
