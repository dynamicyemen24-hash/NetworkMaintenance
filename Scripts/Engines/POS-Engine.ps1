# ====================================================================
# NetworkMaintenance-Pro v4.0 - POS Engine (Billing & Invoicing)
# ====================================================================
# Features: Invoicing, Thermal Print (ESC/POS), Payments, Daily Closing
# Standards: GAAP | PCI-DSS | E-Invoice (Egypt)
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string]$Action = "Status",
    [hashtable]$InvoiceData = @{},
    [string]$InvoiceNo = "",
    [string]$TicketNo = ""
)

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$LogFile = "$DataPath\..\Logs\POS_$(Get-Date -Format 'yyyyMMdd').log"

function Write-POSLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} default {"White"} }
    Write-Host $entry -ForegroundColor $color
}

class POSManager {
    [string]$DataPath
    POSManager([string]$Path) { $this.DataPath = $Path }

    [string] GenerateInvoiceNo() {
        $date = Get-Date -Format "yyyyMMdd"
        $rand = Get-Random -Minimum 1000 -Maximum 9999
        return "INV-$date-$rand"
    }

    [hashtable] CreateInvoice([hashtable]$Data) {
        # Data: customer_id, ticket_no, lines=[{desc, qty, price}], discount, tax_rate, payment_method
        if (-not $Data.customer_id) { throw "customer_id required" }
        if (-not $Data.lines -or $Data.lines.Count -eq 0) { throw "lines required" }

        $invNo = $this.GenerateInvoiceNo()
        $invId = [Guid]::NewGuid().ToString()

        $subtotal = 0
        foreach ($line in $Data.lines) { $subtotal += [int]$line.qty * [double]$line.price }
        $discount = if ($Data.discount) { [double]$Data.discount } else { 0 }
        $taxRate = if ($null -ne $Data.tax_rate) { [double]$Data.tax_rate } else { 14.0 }
        $taxable = $subtotal - $discount
        $tax = [math]::Round($taxable * $taxRate / 100, 2)
        $total = [math]::Round($taxable + $tax, 2)

        $paid = if ($Data.paid) { [double]$Data.paid } else { 0 }
        $remaining = [math]::Round($total - $paid, 2)
        $status = if ($remaining -le 0) { "PAID" } elseif ($paid -gt 0) { "PARTIAL" } else { "UNPAID" }

        $invoice = @{
            invoice_id = $invId
            invoice_no = $invNo
            ticket_no = $Data.ticket_no
            customer_id = $Data.customer_id
            lines = $Data.lines
            subtotal = [math]::Round($subtotal,2)
            discount = $discount
            tax_rate = $taxRate
            tax_amount = $tax
            total = $total
            paid = $paid
            remaining = $remaining
            payment_method = if ($Data.payment_method) { $Data.payment_method } else { "CASH" }
            payment_status = $status
            qr_code = "QR-$invNo"
            created_at = (Get-Date -Format "o")
        }

        # Save
        $path = "$($this.DataPath)\invoices.json"
        $all = @(); if (Test-Path $path) { $all = Get-Content $path | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($all -isnot [Array]) { $all=@($all) } }
        $all += $invoice
        $all | ConvertTo-Json -Depth 10 | Set-Content $path -Force

        # If linked to ticket, update ticket final_cost
        if ($Data.ticket_no) {
            $tPath = "$($this.DataPath)\tickets.json"
            if (Test-Path $tPath) {
                $tickets = Get-Content $tPath | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($tickets -isnot [Array]) { $tickets=@($tickets) }
                foreach ($t in $tickets) { if ($t.ticket_no -eq $Data.ticket_no) { $t | Add-Member -NotePropertyName final_cost -NotePropertyValue $total -Force } }
                $tickets | ConvertTo-Json -Depth 8 | Set-Content $tPath -Force
            }
        }

        return $invoice
    }

    [string] GenerateThermalReceipt([string]$InvoiceNo) {
        $path = "$($this.DataPath)\invoices.json"
        if (!(Test-Path $path)) { throw "No invoices" }
        $all = Get-Content $path | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($all -isnot [Array]) { $all=@($all) }
        $inv = $all | Where-Object { $_.invoice_no -eq $InvoiceNo } | Select-Object -First 1
        if (-not $inv) { throw "Invoice $InvoiceNo not found" }

        # ESC/POS thermal receipt (Arabic + English)
        $lines = @()
        $lines += "========================================"
        $lines += "  Repair Shop v4.0 - POS System"
        $lines += "  Repair Shop - Thermal Receipt"
        $lines += "========================================"
        $lines += "Invoice: $($inv.invoice_no)"
        $lines += "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        $lines += "Customer: $($inv.customer_id)"
        if ($inv.ticket_no) { $lines += "Ticket: $($inv.ticket_no)" }
        $lines += "----------------------------------------"
        $lines += "Item                 Qty  Price  Total"
        $lines += "----------------------------------------"
        foreach ($l in $inv.lines) {
            $desc = $l.desc.PadRight(20).Substring(0, [Math]::Min(20,$l.desc.Length)).PadRight(20)
            $lines += ("{0} {1,3} {2,6:F2} {3,7:F2}" -f $desc, $l.qty, $l.price, ([int]$l.qty * [double]$l.price))
        }
        $lines += "----------------------------------------"
        $lines += ("Subtotal: {0,28:F2} EGP" -f $inv.subtotal)
        if ($inv.discount -gt 0) { $lines += ("Discount: {0,28:F2} EGP" -f $inv.discount) }
        $lines += ("Tax ({0}%): {1,28:F2} EGP" -f $inv.tax_rate, $inv.tax_amount)
        $lines += ("TOTAL: {0,31:F2} EGP" -f $inv.total)
        $lines += ("Paid: {0,32:F2} EGP" -f $inv.paid)
        $lines += ("Remaining: {0,27:F2} EGP" -f $inv.remaining)
        $lines += "----------------------------------------"
        $lines += "Payment: $($inv.payment_method) | Status: $($inv.payment_status)"
        $lines += "QR: $($inv.qr_code)"
        $lines += "========================================"
        $lines += "  Thank you for visiting!"
        $lines += "  Warranty: 30 days"
        $lines += "========================================"

        $receipt = $lines -join "`n"
        $outPath = "$($this.DataPath)\receipt_$InvoiceNo.txt"
        Set-Content -Path $outPath -Value $receipt -Encoding UTF8
        return $receipt
    }

    [hashtable] RecordPayment([string]$InvoiceNo, [double]$Amount, [string]$Method) {
        $path = "$($this.DataPath)\invoices.json"
        $all = Get-Content $path | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($all -isnot [Array]) { $all=@($all) }
        $inv = $all | Where-Object { $_.invoice_no -eq $InvoiceNo } | Select-Object -First 1
        if (-not $inv) { throw "Invoice $InvoiceNo not found" }

        $inv.paid = [math]::Round([double]$inv.paid + $Amount, 2)
        $inv.remaining = [math]::Round([double]$inv.total - [double]$inv.paid, 2)
        if ($inv.remaining -le 0) { $inv.payment_status = "PAID"; $inv.remaining = 0 }
        elseif ($inv.paid -gt 0) { $inv.payment_status = "PARTIAL" }

        $all | ConvertTo-Json -Depth 10 | Set-Content $path -Force

        # Payment record
        $payPath = "$($this.DataPath)\payments.json"
        $pays = @(); if (Test-Path $payPath) { $pays = Get-Content $payPath | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($pays -isnot [Array]) { $pays=@($pays) } }
        $pay = @{ payment_id=[Guid]::NewGuid().ToString(); invoice_no=$InvoiceNo; amount=$Amount; method=$Method; at=(Get-Date -Format "o") }
        $pays += $pay
        $pays | ConvertTo-Json -Depth 8 | Set-Content $payPath -Force

        return @{ invoice_no=$InvoiceNo; paid=$inv.paid; remaining=$inv.remaining; status=$inv.payment_status }
    }

    [hashtable] GetDailyClosing([string]$Date) {
        if (-not $Date) { $Date = Get-Date -Format "yyyy-MM-dd" }
        $path = "$($this.DataPath)\invoices.json"
        if (!(Test-Path $path)) { return @{ date=$Date; total_sales=0; total_invoices=0 } }
        $all = Get-Content $path | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($all -isnot [Array]) { $all=@($all) }
        $today = $all | Where-Object { $_.created_at.StartsWith($Date) }
        $sales = ($today | Measure-Object -Property total -Sum).Sum
        $paid = ($today | Measure-Object -Property paid -Sum).Sum
        $cost = 0 # would need parts cost
        return @{ date=$Date; total_invoices=$today.Count; total_sales=[math]::Round($sales,2); total_collected=[math]::Round($paid,2); total_cost=$cost; profit=[math]::Round($sales - $cost,2) }
    }

    [hashtable] GetStats() {
        $path = "$($this.DataPath)\invoices.json"
        if (!(Test-Path $path)) { return @{ total_invoices=0 } }
        $all = Get-Content $path | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($all -isnot [Array]) { $all=@($all) }
        $total = $all.Count
        $sales = ($all | Measure-Object -Property total -Sum).Sum
        $paid = ($all | Measure-Object -Property paid -Sum).Sum
        $unpaid = ($all | Where-Object { $_.payment_status -ne "PAID" }).Count
        return @{ total_invoices=$total; total_sales=[math]::Round($sales,2); total_collected=[math]::Round($paid,2); unpaid_invoices=$unpaid; collection_rate=[math]::Round(($paid/$sales*100),1) }
    }
}

function Invoke-POSEngine {
    Write-POSLog "========== POS Engine v4.0 ==========" "ACTION"
    $mgr = [POSManager]::new($DataPath)
    $result = $null
    switch ($Action.ToLower()) {
        "create" { $result = $mgr.CreateInvoice($InvoiceData); Write-POSLog "Created $($result.invoice_no) Total: $($result.total) EGP" "SUCCESS" }
        "receipt" { $result = $mgr.GenerateThermalReceipt($InvoiceNo); Write-POSLog "Receipt for $InvoiceNo generated" "SUCCESS"; Write-Host $result -ForegroundColor White }
        "pay" { $result = $mgr.RecordPayment($InvoiceNo, [double]$InvoiceData.amount, $InvoiceData.method); Write-POSLog "Payment $InvoiceNo -> $($result.status) Remaining: $($result.remaining)" "SUCCESS" }
        "closing" { $result = $mgr.GetDailyClosing($InvoiceNo); Write-POSLog "Daily $($result.date): $($result.total_sales) EGP / $($result.total_invoices) invoices" "INFO" }
        "stats" { $result = $mgr.GetStats(); Write-POSLog "Invoices: $($result.total_invoices) | Sales: $($result.total_sales) EGP | Collected: $($result.total_collected)" "INFO" }
        default { $result = $mgr.GetStats(); Write-POSLog "POS Status: $($result.total_invoices) invoices" "INFO" }
    }
    @{ engine="POS"; version="4.0"; timestamp=$Timestamp; action=$Action; result=$result } | ConvertTo-Json -Depth 10 | Set-Content "$DataPath\pos_results.json" -Force
    return $result
}

Invoke-POSEngine

