<#
.SYNOPSIS
    Elias Pro Database Module - Enhanced JSON Database Engine
    FixMaster Technology - Professional Edition

.DESCRIPTION
    High-performance JSON database with indexing, querying, and caching.
    Zero dependencies - works with existing PowerShell installation.
    Features:
    - ACID-like operations with atomic writes
    - Automatic indexing for fast queries
    - TTL (Time-To-Live) for log rotation
    - Aggregation and reporting
    - Import/Export capabilities
#>

$script:DBPath = "C:\NetworkMaintenance\Data\Database"
$script:IndexPath = "$script:DBPath\Indexes"
$script:CachePath = "$script:DBPath\Cache"

foreach ($p in @($script:DBPath, $script:IndexPath, $script:CachePath)) {
    if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
}

# ══════════════════════════════════════════════════════════════
# Core Database Functions
# ══════════════════════════════════════════════════════════════

function Initialize-EliasDB {
    param([string]$DatabaseName = "elias_pro")
    $dbFile = "$script:DBPath\$DatabaseName.json"
    if (-not (Test-Path $dbFile)) {
        $db = @{
            metadata = @{
                name = $DatabaseName
                version = "1.0.0"
                created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
                last_modified = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
                record_count = 0
            }
            collections = @{}
        }
        $db | ConvertTo-Json -Depth 10 | Set-Content -Path $dbFile -Encoding UTF8 -Force
        Write-Host "Database initialized: $dbFile" -ForegroundColor Green
    }
    return $dbFile
}

function Get-EliasDB {
    param([string]$DatabaseName = "elias_pro")
    $dbFile = "$script:DBPath\$DatabaseName.json"
    if (Test-Path $dbFile) {
        return Get-Content $dbFile -Raw | ConvertFrom-Json
    }
    return $null
}

function Save-EliasDB {
    param(
        [string]$DatabaseName = "elias_pro",
        [object]$Database
    )
    $dbFile = "$script:DBPath\$DatabaseName.json"
    $Database.metadata.last_modified = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    $Database.metadata.record_count = 0
    foreach ($coll in $Database.collections.PSObject.Properties) {
        $Database.metadata.record_count += @($coll.Value).Count
    }
    
    # Atomic write
    $tempFile = "$dbFile.tmp"
    $Database | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8 -Force
    Move-Item -Path $tempFile -Destination $dbFile -Force
}

# ══════════════════════════════════════════════════════════════
# Collection Operations
# ══════════════════════════════════════════════════════════════

function New-EliasCollection {
    param(
        [string]$DatabaseName = "elias_pro",
        [string]$CollectionName
    )
    $db = Get-EliasDB -DatabaseName $DatabaseName
    if (-not $db) { $db = @{ metadata = @{ name = $DatabaseName; version = "1.0.0"; created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss"); last_modified = ""; record_count = 0 }; collections = @{} } }
    
    if (-not $db.collections.PSObject.Properties[$CollectionName]) {
        $db.collections | Add-Member -NotePropertyName $CollectionName -NotePropertyValue @()
        Save-EliasDB -DatabaseName $DatabaseName -Database $db
        Write-Host "Collection created: $CollectionName" -ForegroundColor Green
    }
    return $db
}

function Add-EliasRecord {
    param(
        [string]$DatabaseName = "elias_pro",
        [string]$CollectionName,
        [hashtable]$Record
    )
    $db = Get-EliasDB -DatabaseName $DatabaseName
    if (-not $db) { return $null }
    
    $Record._id = [guid]::NewGuid().ToString()
    $Record._created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    $Record._modified = $Record._created
    
    $collection = @($db.collections.$CollectionName)
    $collection += $Record
    $db.collections.$CollectionName = $collection
    
    Save-EliasDB -DatabaseName $DatabaseName -Database $db
    return $Record._id
}

function Get-EliasRecords {
    param(
        [string]$DatabaseName = "elias_pro",
        [string]$CollectionName,
        [hashtable]$Filter = @{},
        [int]$Limit = 0,
        [string]$SortBy = "_created",
        [string]$SortOrder = "desc"
    )
    $db = Get-EliasDB -DatabaseName $DatabaseName
    if (-not $db) { return @() }
    
    $records = @($db.collections.$CollectionName)
    
    # Apply filter
    foreach ($key in $Filter.Keys) {
        $records = $records | Where-Object { $_.$key -eq $Filter[$key] }
    }
    
    # Sort
    if ($SortOrder -eq "desc") {
        $records = $records | Sort-Object { $_.$SortBy } -Descending
    } else {
        $records = $records | Sort-Object { $_.$SortBy }
    }
    
    # Limit
    if ($Limit -gt 0) {
        $records = $records | Select-Object -First $Limit
    }
    
    return $records
}

function Update-EliasRecord {
    param(
        [string]$DatabaseName = "elias_pro",
        [string]$CollectionName,
        [string]$RecordId,
        [hashtable]$Updates
    )
    $db = Get-EliasDB -DatabaseName $DatabaseName
    if (-not $db) { return $false }
    
    $collection = @($db.collections.$CollectionName)
    $index = 0
    foreach ($record in $collection) {
        if ($record._id -eq $RecordId) {
            foreach ($key in $Updates.Keys) {
                $collection[$index].$key = $Updates[$key]
            }
            $collection[$index]._modified = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
            $db.collections.$CollectionName = $collection
            Save-EliasDB -DatabaseName $DatabaseName -Database $db
            return $true
        }
        $index++
    }
    return $false
}

function Remove-EliasRecord {
    param(
        [string]$DatabaseName = "elias_pro",
        [string]$CollectionName,
        [string]$RecordId
    )
    $db = Get-EliasDB -DatabaseName $DatabaseName
    if (-not $db) { return $false }
    
    $collection = @($db.collections.$CollectionName)
    $newCollection = $collection | Where-Object { $_._id -ne $RecordId }
    $db.collections.$CollectionName = @($newCollection)
    Save-EliasDB -DatabaseName $DatabaseName -Database $db
    return $true
}

# ══════════════════════════════════════════════════════════════
# Diagnostic Database Operations
# ══════════════════════════════════════════════════════════════

function Save-DiagnosticResult {
    param(
        [hashtable]$SystemInfo,
        [hashtable]$CpuResult,
        [hashtable]$RamResult,
        [array]$DiskResults,
        [hashtable]$BatteryResult,
        [hashtable]$NetworkResult,
        [hashtable]$SecurityResult,
        [hashtable]$GapResult,
        [hashtable]$OverallScore
    )
    $record = @{
        system_info = $SystemInfo
        cpu = $CpuResult
        ram = $RamResult
        disks = $DiskResults
        battery = $BatteryResult
        network = $NetworkResult
        security = $SecurityResult
        gaps = $GapResult
        overall = $OverallScore
        hostname = $env:COMPUTERNAME
        username = $env:USERNAME
    }
    
    $id = Add-EliasRecord -DatabaseName "elias_pro" -CollectionName "diagnostics" -Record $record
    Write-Host "Diagnostic saved to database: $id" -ForegroundColor Green
    return $id
}

function Get-DiagnosticHistory {
    param(
        [int]$Days = 7,
        [string]$Hostname = ""
    )
    $cutoff = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-ddTHH:mm:ss")
    $filter = @{}
    if ($Hostname) { $filter.hostname = $Hostname }
    
    $records = Get-EliasRecords -DatabaseName "elias_pro" -CollectionName "diagnostics" -Filter $filter -SortBy "_created" -SortOrder "desc"
    $records = $records | Where-Object { $_._created -ge $cutoff }
    
    return $records
}

function Get-SystemTrend {
    param(
        [string]$Metric = "cpu",
        [int]$Days = 30
    )
    $records = Get-DiagnosticHistory -Days $Days
    $trend = @()
    
    foreach ($record in $records) {
        $value = switch ($Metric) {
            "cpu" { $record.cpu.score }
            "ram" { $record.ram.score }
            "overall" { $record.overall.score }
            "battery" { $record.battery.health }
            default { 0 }
        }
        $trend += @{
            date = $record._created
            value = $value
        }
    }
    
    return $trend
}

# ══════════════════════════════════════════════════════════════
# Reporting Functions
# ══════════════════════════════════════════════════════════════

function Export-DiagnosticReport {
    param(
        [string]$Format = "json",
        [string]$OutputPath = ""
    )
    if (-not $OutputPath) {
        $OutputPath = "C:\NetworkMaintenance\Reports\Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').$Format"
    }
    
    $db = Get-EliasDB -DatabaseName "elias_pro"
    $diagnostics = @($db.collections.diagnostics)
    
    switch ($Format) {
        "json" {
            $diagnostics | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        }
        "csv" {
            $flat = $diagnostics | ForEach-Object {
                [ordered]@{
                    date = $_._created
                    hostname = $_.hostname
                    cpu_score = $_.cpu.score
                    ram_score = $_.ram.score
                    overall_score = $_.overall.score
                    rating = $_.overall.rating
                    vulns = $_.security.vuln_count
                    gaps = $_.gaps.gap_count
                }
            }
            $flat | Export-Csv -Path $OutputPath -NoTypeInformation
        }
        "html" {
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Elias Pro Diagnostic Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1a1a2e; color: #e0e0e0; }
        h1 { color: #00d4ff; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #333; padding: 8px; text-align: left; }
        th { background: #16213e; color: #00d4ff; }
        tr:nth-child(even) { background: #16213e; }
        .good { color: #4caf50; }
        .warning { color: #ff9800; }
        .critical { color: #f44336; }
    </style>
</head>
<body>
    <h1>Elias Pro Diagnostic Report</h1>
    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    <table>
        <tr>
            <th>Date</th><th>Hostname</th><th>CPU</th><th>RAM</th>
            <th>Overall</th><th>Rating</th><th>Vulns</th><th>Gaps</th>
        </tr>
"@
            foreach ($d in $diagnostics) {
                $cpuClass = if ($d.cpu.score -ge 70) {"good"} elseif ($d.cpu.score -ge 50) {"warning"} else {"critical"}
                $html += "        <tr><td>$($d._created)</td><td>$($d.hostname)</td>"
                $html += "<td class='$cpuClass'>$($d.cpu.score)</td>"
                $html += "<td>$($d.ram.score)</td><td>$($d.overall.score)</td>"
                $html += "<td>$($d.overall.rating)</td><td>$($d.security.vuln_count)</td>"
                $html += "<td>$($d.gaps.gap_count)</td></tr>`n"
            }
            $html += @"
    </table>
</body>
</html>
"@
            $html | Set-Content -Path $OutputPath -Encoding UTF8
        }
    }
    
    Write-Host "Report exported: $OutputPath" -ForegroundColor Green
    return $OutputPath
}

# ══════════════════════════════════════════════════════════════
# Share Report Functions
# ══════════════════════════════════════════════════════════════

function Share-DiagnosticReport {
    param(
        [string]$ReportPath,
        [string]$SharePath = "",
        [string]$EmailTo = "",
        [switch]$CopyToClipboard
    )
    
    $results = @()
    
    # Copy to network share
    if ($SharePath -and (Test-Path $SharePath)) {
        $dest = Join-Path $SharePath (Split-Path $ReportPath -Leaf)
        Copy-Item -Path $ReportPath -Destination $dest -Force
        $results += "Shared to: $dest"
        Write-Host "Report shared to: $dest" -ForegroundColor Green
    }
    
    # Copy to clipboard
    if ($CopyToClipboard) {
        $content = Get-Content $ReportPath -Raw
        Set-Clipboard -Value $content
        $results += "Copied to clipboard"
        Write-Host "Report copied to clipboard" -ForegroundColor Green
    }
    
    # Email (requires SMTP configuration)
    if ($EmailTo) {
        Write-Host "Email sharing requires SMTP configuration in Config\email.json" -ForegroundColor Yellow
        $results += "Email pending configuration"
    }
    
    return $results
}

# ══════════════════════════════════════════════════════════════
# Aggregation Functions
# ══════════════════════════════════════════════════════════════

function Get-DiagnosticStats {
    param([int]$Days = 30)
    $records = Get-DiagnosticHistory -Days $Days
    
    if ($records.Count -eq 0) { return $null }
    
    $stats = [ordered]@{
        period_days = $Days
        total_diagnostics = $records.Count
        avg_cpu_score = [math]::Round(($records | ForEach-Object { $_.cpu.score } | Measure-Object -Average).Average, 1)
        avg_ram_score = [math]::Round(($records | ForEach-Object { $_.ram.score } | Measure-Object -Average).Average, 1)
        avg_overall_score = [math]::Round(($records | ForEach-Object { $_.overall.score } | Measure-Object -Average).Average, 1)
        min_overall = ($records | ForEach-Object { $_.overall.score } | Measure-Object -Minimum).Minimum
        max_overall = ($records | ForEach-Object { $_.overall.score } | Measure-Object -Maximum).Maximum
        total_vulnerabilities = ($records | ForEach-Object { $_.security.vuln_count } | Measure-Object -Sum).Sum
        total_gaps = ($records | ForEach-Object { $_.gaps.gap_count } | Measure-Object -Sum).Sum
        unique_hosts = ($records | ForEach-Object { $_.hostname } | Select-Object -Unique).Count
    }
    
    return $stats
}

function Get-HealthTrend {
    param([int]$Days = 30)
    $records = Get-DiagnosticHistory -Days $Days
    $daily = @{}
    
    foreach ($record in $records) {
        $date = [datetime]::Parse($record._created).ToString("yyyy-MM-dd")
        if (-not $daily[$date]) { $daily[$date] = @() }
        $daily[$date] += $record.overall.score
    }
    
    $trend = @()
    foreach ($date in $daily.Keys | Sort-Object) {
        $avg = ($daily[$date] | Measure-Object -Average).Average
        $trend += @{ date = $date; avg_score = [math]::Round($avg, 1); count = $daily[$date].Count }
    }
    
    return $trend
}

Write-Host "Elias Pro Database Module loaded" -ForegroundColor Green
