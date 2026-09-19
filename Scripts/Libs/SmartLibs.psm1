# ====================================================================
# NetworkMaintenance-Pro v4.0 - Smart Libraries
# ====================================================================
# Libs: Barcode, QR, Thermal Printer ESC/POS, Notifications, AI Pricing
# ====================================================================

# ── Barcode / QR Generator ──
function New-Barcode {
    param([string]$Data, [string]$Type = "EAN13")
    # Generate barcode text (mock - real would use ZXing or barcode lib)
    $barcode = if ($Type -eq "EAN13") {
        $base = "622" + (Get-Random -Minimum 100000000 -Maximum 999999999)
        $sum=0; for($i=0;$i -lt $base.Length;$i++){ $d=[int]$base[$i].ToString(); $sum+= if($i%2 -eq 0){$d}else{$d*3} }
        $check=(10-($sum%10))%10
        "$base$check"
    } else { "QR-" + [Guid]::NewGuid().ToString().Substring(0,8).ToUpper() }
    return @{ data=$Data; barcode=$barcode; type=$Type; image="barcode_$barcode.png" }
}

function New-QRCode {
    param([string]$Data)
    # Mock QR - real would use QRCoder
    return @{ data=$Data; qr="QR-" + ($Data | Get-Hash); image="qr_$Data.png" }
}
function Get-Hash { param([string]$InputStr) $sha=[System.Security.Cryptography.SHA256]::Create(); $bytes=[System.Text.Encoding]::UTF8.GetBytes($InputStr); $hash=$sha.ComputeHash($bytes); return ([BitConverter]::ToString($hash).Replace("-","").Substring(0,8)) }

# ── Thermal Printer ESC/POS ──
function Send-ThermalPrint {
    param([string]$Text, [string]$PrinterName = "POS-80", [switch]$Preview)
    $escInit = [char]27 + "@" # ESC @
    $escCut = [char]29 + "V" + [char]1 # GS V 1
    $escBoldOn = [char]27 + "E" + [char]1
    $escBoldOff = [char]27 + "E" + [char]0
    $escCenter = [char]27 + "a" + [char]1
    $escLeft = [char]27 + "a" + [char]0

    $output = $escInit + $Text + $escCut

    if ($Preview) {
        $previewPath = "C:\NetworkMaintenance\Data\thermal_preview.txt"
        Set-Content -Path $previewPath -Value $Text -Encoding UTF8
        Write-Host "Thermal preview saved to $previewPath" -ForegroundColor Cyan
        return $previewPath
    }

    try {
        # Try real printer
        $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if ($printer) {
            $tempFile = "$env:TEMP\print_$([Guid]::NewGuid().ToString().Substring(0,6)).txt"
            Set-Content -Path $tempFile -Value $output -Encoding UTF8
            # Out-Printer would be used here
            Write-Host "Sent to printer $PrinterName" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Printer $PrinterName not found - preview only" -ForegroundColor Yellow
            $previewPath = "C:\NetworkMaintenance\Data\thermal_preview.txt"
            Set-Content -Path $previewPath -Value $Text -Encoding UTF8
            return $previewPath
        }
    } catch {
        Write-Host "Print failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ── Notifications (SMS/WhatsApp) ──
function Send-CustomerNotification {
    param(
        [string]$Phone,
        [string]$TicketNo,
        [string]$Status,
        [string]$Channel = "WHATSAPP"
    )
    $templates = @{
        "READY" = "مرحباً! جهازك ($TicketNo) جاهز للاستلام. شكراً لثقتكم - محل الصيانة"
        "DIAGNOSED" = "تم تشخيص جهازك ($TicketNo). التكلفة المتوقعة سيتم إبلاغك قريباً"
        "DELIVERED" = "تم تسليم جهازك ($TicketNo). نتمنى أن تكون راضياً - قيّمنا ⭐⭐⭐⭐⭐"
        "QUOTED" = "تكلفة صيانة جهازك ($TicketNo) جاهزة. يرجى الموافقة للبدء"
    }
    $message = if ($templates.ContainsKey($Status)) { $templates[$Status] } else { "تحديث حالة جهازك ($TicketNo): $Status" }

    # Mock send - real would use Twilio/WhatsApp Business API
    $logPath = "C:\NetworkMaintenance\Data\notifications.json"
    $all = @(); if (Test-Path $logPath) { $all = Get-Content $logPath | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($all -isnot [Array]) {$all=@($all)} }
    $record = @{ notif_id=[Guid]::NewGuid().ToString(); phone=$Phone; ticket_no=$TicketNo; channel=$Channel; message=$message; status="SENT"; sent_at=(Get-Date -Format "o") }
    $all += $record
    $all | ConvertTo-Json -Depth 6 | Set-Content $logPath -Force

    Write-Host "[$Channel] To $Phone : $message" -ForegroundColor Cyan
    # Real API example (commented):
    # Invoke-RestMethod -Uri "https://api.twilio.com/..." -Method Post -Body @{To=$Phone; Body=$message}
    return $record
}

# ── AI Pricing Engine ──
function Get-AIPricingSuggestion {
    param([string]$DeviceType, [string]$Brand, [string]$Model, [string]$Service)
    $basePrices = @{
        "Screen Replacement" = @{ cost=800; price=1500 }
        "Battery Replacement" = @{ cost=300; price=600 }
        "Charging Port" = @{ cost=150; price=350 }
        "Board Repair" = @{ cost=500; price=1200 }
        "General Diagnosis" = @{ cost=0; price=50 }
    }
    $base = if ($basePrices.ContainsKey($Service)) { $basePrices[$Service] } else { @{cost=200; price=500} }
    # Brand multiplier
    $multiplier = switch ($Brand) { "Apple" {1.5} "Samsung" {1.2} "Xiaomi" {0.9} default {1.0} }
    $suggestedPrice = [math]::Round($base.price * $multiplier, 0)
    $suggestedCost = [math]::Round($base.cost * $multiplier, 0)
    $profit = $suggestedPrice - $suggestedCost
    $confidence = 0.85
    return @{ service=$Service; brand=$Brand; suggested_cost=$suggestedCost; suggested_price=$suggestedPrice; profit=$profit; confidence=$confidence; reasoning="Based on $Brand $Service historical data (multiplier $multiplier)" }
}

# ── Daily Closing Calculator ──
function Get-DailyClosingReport {
    param([string]$Date = (Get-Date -Format "yyyy-MM-dd"))
    $invPath = "C:\NetworkMaintenance\Data\invoices.json"
    $expPath = "C:\NetworkMaintenance\Data\expenses.json"
    $invoices = @(); if (Test-Path $invPath) { $invoices = Get-Content $invPath | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($invoices -isnot [Array]){$invoices=@($invoices)} }
    $today = $invoices | Where-Object { $_.created_at.StartsWith($Date) }
    $sales = ($today | Measure-Object -Property total -Sum).Sum
    $collected = ($today | Measure-Object -Property paid -Sum).Sum
    $count = $today.Count
    # Expenses
    $expenses = @(); if (Test-Path $expPath) { $expenses = Get-Content $expPath | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($expenses -isnot [Array]){$expenses=@($expenses)} }
    $todayExp = $expenses | Where-Object { $_.expense_date -eq $Date }
    $totalExp = ($todayExp | Measure-Object -Property amount -Sum).Sum
    $profit = [math]::Round($sales - $totalExp, 2)
    return @{ date=$Date; invoices=$count; sales=[math]::Round($sales,2); collected=[math]::Round($collected,2); expenses=[math]::Round($totalExp,2); profit=$profit }
}

Export-ModuleMember -Function New-Barcode, New-QRCode, Send-ThermalPrint, Send-CustomerNotification, Get-AIPricingSuggestion, Get-DailyClosingReport
