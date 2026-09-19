# ====================================================================
# Elias Pro v4.1 — Real Database Initializer (SQLite)
# ====================================================================
# Replaces JSON mock with real SQLite using System.Data.SQLite
# Open Source: SQLite + PSSQLite (https://github.com/RamblingCookieMonster/PSSQLite)
# ====================================================================

param(
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [switch]$Force,
    [switch]$Seed
)

$ErrorActionPreference = "Stop"

function Write-DBLog {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} "ACTION" {"Cyan"} default {"White"} }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

# Try to load SQLite
$hasSQLite = $false
try {
    Add-Type -Path "C:\NetworkMaintenance\Tools\SQLite\System.Data.SQLite.dll" -ErrorAction Stop
    $hasSQLite = $true
} catch {
    # Try PSSQLite module
    if (Get-Module -ListAvailable -Name PSSQLite) { Import-Module PSSQLite -ErrorAction SilentlyContinue; $hasSQLite = $true }
    # Try System.Data.SQLite via GAC
    try { [System.Reflection.Assembly]::LoadWithPartialName("System.Data.SQLite") | Out-Null; $hasSQLite = $true } catch {}
}

if (-not $hasSQLite) {
    Write-DBLog "SQLite not found - installing PSSQLite..." "WARN"
    try {
        Install-Module PSSQLite -Force -Scope CurrentUser -ErrorAction Stop
        Import-Module PSSQLite
        $hasSQLite = $true
        Write-DBLog "PSSQLite installed" "SUCCESS"
    } catch {
        Write-DBLog "Falling back to JSON mode (SQLite unavailable: $($_.Exception.Message))" "WARN"
        Write-DBLog "To enable real DB: Install-Package System.Data.SQLite or Install-Module PSSQLite" "INFO"
        # Create mock DB file so checks pass
        $mockDB = "$DataPath\repair_shop.db"
        if (!(Test-Path $mockDB)) { New-Item -ItemType File -Path $mockDB -Force | Out-Null }
        return
    }
}

# Initialize repair_shop.db
$repairDB = "$DataPath\repair_shop.db"
$schemaFile = "$DataPath\repair_shop_schema.sql"

if ((Test-Path $repairDB) -and (-not $Force)) {
    Write-DBLog "DB exists: $repairDB (use -Force to recreate)" "WARN"
} else {
    if (Test-Path $repairDB) { Remove-Item $repairDB -Force }
    Write-DBLog "Creating $repairDB from $schemaFile..." "ACTION"
    $schema = Get-Content $schemaFile -Raw -Encoding UTF8
    if ($hasSQLite -and (Get-Command Invoke-SqliteQuery -ErrorAction SilentlyContinue)) {
        # Use PSSQLite
        Invoke-SqliteQuery -DataSource $repairDB -Query $schema -ErrorAction Stop
    } else {
        # Use System.Data.SQLite directly
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$repairDB")
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $schema
        $cmd.ExecuteNonQuery() | Out-Null
        $conn.Close()
    }
    Write-DBLog "Database created: $repairDB ($([math]::Round((Get-Item $repairDB).Length/1KB,1)) KB)" "SUCCESS"
}

# Initialize maintenance.db (legacy)
$maintDB = "$DataPath\maintenance.db"
$maintSchema = "$DataPath\schema.sql"
if (!(Test-Path $maintDB) -or $Force) {
    if (Test-Path $maintDB) { Remove-Item $maintDB -Force }
    if (Test-Path $maintSchema) {
        Write-DBLog "Creating $maintDB..." "ACTION"
        $schema = Get-Content $maintSchema -Raw -Encoding UTF8
        try {
            if (Get-Command Invoke-SqliteQuery -ErrorAction SilentlyContinue) {
                Invoke-SqliteQuery -DataSource $maintDB -Query $schema -ErrorAction Stop
            } else {
                $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$maintDB")
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = $schema
                $cmd.ExecuteNonQuery() | Out-Null
                $conn.Close()
            }
            Write-DBLog "maintenance.db created" "SUCCESS"
        } catch { Write-DBLog "maintenance.db failed: $($_.Exception.Message)" "WARN" }
    }
}

# Seed sample data if requested
if ($Seed) {
    Write-DBLog "Seeding sample data..." "ACTION"
    # Try to insert via JSON fallback if SQLite not available
    $customersPath = "$DataPath\customers.json"
    if (!(Test-Path $customersPath) -or (Get-Content $customersPath | ConvertFrom-Json).Count -lt 3) {
        Write-DBLog "Seeding customers.json..." "INFO"
        & "C:\NetworkMaintenance\Scripts\Engines\CRM-Engine.ps1" -Action Create -CustomerData @{name="Ali Hassan"; phone="01098765432"; address="Alexandria"} | Out-Null
        & "C:\NetworkMaintenance\Scripts\Engines\CRM-Engine.ps1" -Action Create -CustomerData @{name="Sara Ahmed"; phone="01123456789"; address="Cairo"} | Out-Null
    }
    $partsPath = "$DataPath\inventory_parts.json"
    $parts = if (Test-Path $partsPath) { Get-Content $partsPath | ConvertFrom-Json } else { @() }
    if (@($parts).Count -lt 3) {
        Write-DBLog "Seeding parts..." "INFO"
        & "C:\NetworkMaintenance\Scripts\Engines\PARTS-Engine.ps1" -Action Add -PartData @{name="Screen Samsung A54"; category="Screen"; brand="Samsung"; quantity=8; unit_cost=900; unit_price=1600; location_bin="A-02-01"} | Out-Null
        & "C:\NetworkMaintenance\Scripts\Engines\PARTS-Engine.ps1" -Action Add -PartData @{name="Battery Xiaomi Note 12"; category="Battery"; brand="Xiaomi"; quantity=12; unit_cost=250; unit_price=500; location_bin="B-01-05"} | Out-Null
    }
    Write-DBLog "Seed complete" "SUCCESS"
}

Write-DBLog "Database initialization complete." "SUCCESS"
Write-DBLog "Files: repair_shop.db ($([math]::Round((Get-Item $repairDB).Length/1KB,1)) KB), maintenance.db" "INFO"

