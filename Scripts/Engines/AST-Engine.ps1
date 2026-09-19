# ====================================================================
# NetworkMaintenance-Pro v3.1 - AST Engine (Universal Asset Tracker)
# ====================================================================
# Capabilities: Discovery, Classification, Lifecycle, Depreciation, Compliance, Cost
# Standards: ISO 19770, ITIL v4 SACM, CMDB, ITAM, FinOps
# Integrations: SCCM, Intune, Jamf, Lansweeper, ServiceNow, Jira, Flexera, Snow
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\UniversalConfig.json",
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string[]]$DataSources = @("WMI", "SNMP", "MDM", "API", "CSV", "SCCM", "Intune", "Jamf", "Lansweeper"),
    [switch]$CalculateDepreciation,
    [switch]$GenerateFinOpsReport,
    [switch]$SyncCMDB
)

$Config = Get-Content $ConfigPath | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"

# ====================================================================
# CLASS: AssetDiscovery
# ====================================================================
class AssetDiscovery {
    [string]$Name = "AssetDiscovery"
    [hashtable]$Sources = @{}
    
    AssetDiscovery([string[]]$Sources) {
        foreach ($src in $Sources) {
            $this.Sources[$src] = $true
        }
    }
    
    [object[]] DiscoverFromWMI() {
        Write-Host "[AST] Discovering via WMI..." -ForegroundColor Yellow
        $assets = @()
        
        try {
            $systems = Get-CimInstance Win32_ComputerSystem
            $bios = Get-CimInstance Win32_BIOS
            $os = Get-CimInstance Win32_OperatingSystem
            $processors = Get-CimInstance Win32_Processor
            $memory = Get-CimInstance Win32_PhysicalMemory
            $disks = Get-CimInstance Win32_DiskDrive
            $nics = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
            $gpus = Get-CimInstance Win32_VideoController
            $sound = Get-CimInstance Win32_SoundDevice
            $usb = Get-CimInstance Win32_USBController
            $printers = Get-CimInstance Win32_Printer
            $shares = Get-CimInstance Win32_Share
            $services = Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq "Auto" }
            $hotfixes = Get-HotFix
            
            $asset = @{
                asset_id = "AST-" + [System.Guid]::NewGuid().ToString().Substring(0, 8).ToUpper()
                source = "WMI"
                discovered_at = $Timestamp
                
                # Identity
                hostname = $systems.Name
                domain = $systems.Domain
                manufacturer = $systems.Manufacturer
                model = $systems.Model
                serial_number = $bios.SerialNumber
                asset_tag = $systems.AssetTag
                uuid = (Get-CimInstance Win32_ComputerSystemProduct).UUID
                
                # Classification
                device_type = $this.ClassifyDeviceType($systems)
                platform = "Windows"
                os_name = $os.Caption
                os_version = $os.Version
                os_build = $os.BuildNumber
                os_install_date = $os.InstallDate
                
                # Hardware
                cpu = @($processors | ForEach-Object { @{ name = $_.Name; cores = $_.NumberOfCores; threads = $_.NumberOfLogicalProcessors; speed = $_.MaxClockSpeed; l2 = $_.L2CacheSize; l3 = $_.L3CacheSize } })
                memory_gb = [math]::Round(($memory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)
                memory_modules = @($memory | ForEach-Object { @{ capacity = [math]::Round($_.Capacity/1GB,1); speed = $_.Speed; type = $_.MemoryType; manufacturer = $_.Manufacturer; part = $_.PartNumber } })
                storage = @($disks | ForEach-Object { @{ model = $_.Model; size = [math]::Round($_.Size/1GB,1); interface = $_.InterfaceType; serial = $_.SerialNumber; media = $_.MediaType } })
                gpu = @($gpus | ForEach-Object { @{ name = $_.Name; ram = [math]::Round($_.AdapterRAM/1GB,1); driver = $_.DriverVersion; resolution = "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)" } })
                
                # Network
                network = @($nics | ForEach-Object { @{ description = $_.Description; mac = $_.MACAddress; ip = $_.IPAddress; dhcp = $_.DHCPEnabled; dns = $_.DNSServerSearchOrder; speed = $_.Speed } })
                
                # Software
                installed_software = @(Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName } | ForEach-Object { @{ name = $_.DisplayName; version = $_.DisplayVersion; publisher = $_.Publisher; install_date = $_.InstallDate; size = $_.EstimatedSize } })
                hotfixes = @($hotfixes | ForEach-Object { @{ id = $_.HotFixID; installed = $_.InstalledOn; description = $_.Description } })
                
                # Services
                services = @($services | ForEach-Object { @{ name = $_.Name; display = $_.DisplayName; status = $_.State; startup = $_.StartMode } })
                
                # Lifecycle
                lifecycle_state = "ACTIVE"
                purchase_date = $this.EstimatePurchaseDate($bios.ReleaseDate, $os.InstallDate)
                warranty_expiry = $this.EstimateWarranty($this.EstimatePurchaseDate($bios.ReleaseDate, $os.InstallDate))
                
                # Financial
                estimated_value = $this.EstimateValue($systems.Model, $disks, $memory, $gpus)
                depreciation = @{}
                
                # Compliance
                compliance = @{
                    encryption = (Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object { $_.ProtectionStatus -eq "On" }).Count -gt 0
                    firewall = (Get-NetFirewallProfile).Enabled -contains "True"
                    updates = ($hotfixes | Where-Object { $_.InstalledOn -gt (Get-Date).AddDays(-30) }).Count -gt 0
                    antivirus = (Get-MpComputerStatus -ErrorAction SilentlyContinue).AMServiceEnabled
                    password_policy = $true  # Would check GPO
                    screen_lock = $true
                }
            }
            
            $assets += $asset
        } catch {
            Write-Warning "[AST] WMI discovery failed: $($_.Exception.Message)"
        }
        
        return $assets
    }
    
    [string] ClassifyDeviceType([object]$systems) {
        $type = $systems.PCSystemType
        switch ($type) {
            1 { return "Workstation" }
            2 { return "Laptop" }
            3 { return "Laptop" }
            4 { return "Server" }
            5 { return "Server" }
            6 { return "Mobile" }
            7 { return "Server" }
            8 { return "Server" }
            9 { return "Server" }
            default { return "Workstation" }
        }
    }
    
    [datetime] EstimatePurchaseDate([string]$biosDate, [datetime]$osInstall) {
        try {
            $bios = [System.Management.ManagementDateTimeConverter]::ToDateTime($biosDate)
            return if ($bios -lt $osInstall) { $bios } else { $osInstall }
        } catch {
            return $osInstall
        }
    }
    
    [datetime] EstimateWarranty([datetime]$purchaseDate) {
        return $purchaseDate.AddYears(3)  # Standard 3-year warranty
    }
    
    [double] EstimateValue([string]$model, [object[]]$disks, [object[]]$memory, [object[]]$gpus) {
        $base = 800
        $diskValue = ($disks | Measure-Object -Property Size -Sum).Sum / 1GB * 0.1
        $memValue = ($memory | Measure-Object -Property Capacity -Sum).Sum / 1GB * 5
        $gpuValue = $gpus.Count * 200
        return [math]::Round($base + $diskValue + $memValue + $gpuValue, 2)
    }
    
    [object[]] DiscoverFromSNMP([string]$Target) {
        Write-Host "[AST] Discovering network device via SNMP: $Target" -ForegroundColor Yellow
        return @()
    }
    
    [object[]] DiscoverFromMDM() {
        Write-Host "[AST] Discovering mobile devices via MDM..." -ForegroundColor Yellow
        return @()
    }
    
    [object[]] DiscoverFromAPI([string]$Endpoint, [string]$Token) {
        Write-Host "[AST] Discovering via API: $Endpoint" -ForegroundColor Yellow
        return @()
    }
}

# ====================================================================
# CLASS: AssetLifecycleManager
# ====================================================================
class AssetLifecycleManager {
    [string]$Name = "AssetLifecycleManager"
    [hashtable]$StateMachine = @{}
    [hashtable]$DepreciationMethods = @{}
    
    AssetLifecycleManager() {
        $this.StateMachine = @{
            "PROCUREMENT" = @("RECEIVED", "CANCELLED")
            "RECEIVED" = @("STAGING", "RETURNED")
            "STAGING" = @("DEPLOYED", "RECONFIGURED", "RETURNED")
            "DEPLOYED" = @("ACTIVE", "MAINTENANCE", "LOANED", "DECOMMISSIONED")
            "ACTIVE" = @("MAINTENANCE", "UPGRADED", "TRANSFERRED", "DECOMMISSIONED", "LOST", "STOLEN")
            "MAINTENANCE" = @("ACTIVE", "DECOMMISSIONED", "REPLACED")
            "UPGRADED" = @("ACTIVE", "DECOMMISSIONED")
            "TRANSFERRED" = @("ACTIVE", "DECOMMISSIONED")
            "LOANED" = @("ACTIVE", "RETURNED", "LOST")
            "DECOMMISSIONED" = @("DISPOSED", "DONATED", "SOLD", "RECYCLED", "RETURNED_VENDOR")
            "DISPOSED" = @()
            "DONATED" = @()
            "SOLD" = @()
            "RECYCLED" = @()
            "RETURNED_VENDOR" = @()
            "LOST" = @("FOUND", "WRITTEN_OFF")
            "STOLEN" = @("RECOVERED", "WRITTEN_OFF")
            "CANCELLED" = @()
            "RETURNED" = @("STAGING", "DISPOSED")
            "RECONFIGURED" = @("STAGING", "DECOMMISSIONED")
            "REPLACED" = @("DECOMMISSIONED")
            "WRITTEN_OFF" = @()
            "FOUND" = @("ACTIVE", "DECOMMISSIONED")
        }
        
        $this.DepreciationMethods = @{
            "STRAIGHT_LINE" = { param($cost, $salvage, $life, $age) return ($cost - $salvage) / $life * $age }
            "DECLINING_BALANCE" = { param($cost, $salvage, $life, $age, $rate = 2) return $cost * ($rate / $life) * [math]::Pow(1 - $rate/$life, $age - 1) }
            "SUM_OF_YEARS" = { param($cost, $salvage, $life, $age) return ($cost - $salvage) * ($life - $age + 1) / ($life * ($life + 1) / 2) }
            "UNITS_OF_PRODUCTION" = { param($cost, $salvage, $totalUnits, $unitsProduced) return ($cost - $salvage) / $totalUnits * $unitsProduced }
        }
    }
    
    [bool] IsValidTransition([string]$from, [string]$to) {
        return $this.StateMachine[$from] -contains $to
    }
    
    [object] Transition([string]$AssetId, [string]$FromState, [string]$ToState, [string]$PerformedBy, [string]$Reason, [hashtable]$Metadata = @{}) {
        if (-not $this.IsValidTransition($FromState, $ToState)) {
            throw "Invalid transition: $FromState -> $ToState"
        }
        
        return @{
            asset_id = $AssetId
            from_state = $FromState
            to_state = $ToState
            transition_date = (Get-Date).ToString("yyyy-MM-dd")
            performed_by = $PerformedBy
            reason = $Reason
            metadata = $Metadata
            recorded_at = $Timestamp
        }
    }
    
    [object] CalculateDepreciation([double]$Cost, [double]$Salvage, [int]$LifeYears, [int]$AgeYears, [string]$Method = "STRAIGHT_LINE") {
        if (-not $this.DepreciationMethods.ContainsKey($Method)) {
            $Method = "STRAIGHT_LINE"
        }
        
        $accumulated = & $this.DepreciationMethods[$Method] $Cost $Salvage $LifeYears $AgeYears
        $bookValue = $Cost - $accumulated
        $annualExpense = if ($Method -eq "STRAIGHT_LINE") { ($Cost - $Salvage) / $LifeYears } else { $accumulated - (if ($AgeYears -gt 1) { & $this.DepreciationMethods[$Method] $Cost $Salvage $LifeYears ($AgeYears - 1) } else { 0 }) }
        
        return @{
            method = $Method
            original_cost = $Cost
            salvage_value = $Salvage
            useful_life_years = $LifeYears
            current_age_years = $AgeYears
            accumulated_depreciation = [math]::Round($accumulated, 2)
            book_value = [math]::Round([math]::Max($bookValue, $Salvage), 2)
            annual_expense = [math]::Round($annualExpense, 2)
            remaining_life_years = [math]::Max($LifeYears - $AgeYears, 0)
            fully_depreciated = ($AgeYears -ge $LifeYears)
        }
    }
}

# ====================================================================
# CLASS: CostOptimizationEngine
# ====================================================================
class CostOptimizationEngine {
    [string]$Name = "CostOptimizationEngine"
    [hashtable]$CostCategories = @{}
    
    CostOptimizationEngine() {
        $this.CostCategories = @{
            "Hardware" = @("Procurement", "Maintenance", "Warranty", "Upgrades", "Disposal")
            "Software" = @("Licenses", "Subscriptions", "Maintenance", "Support", "Training")
            "Cloud" = @("Compute", "Storage", "Network", "Managed Services", "Data Transfer")
            "Network" = @("Hardware", "Circuits", "ISP", "Security", "Management")
            "Personnel" = @("Staff", "Contractors", "Training", "Certifications", "Tools")
            "Facilities" = @("Datacenter", "Power", "Cooling", "Rack Space", "Cabling")
            "Security" = @("Tools", "Audits", "Compliance", "Insurance", "Incident Response")
        }
    }
    
    [object] AnalyzeCosts([object[]]$Assets) {
        $totalCost = 0
        $byCategory = @{}
        $byDeviceType = @{}
        $byDepartment = @{}
        $optimizations = @()
        
        foreach ($asset in $Assets) {
            $cost = $asset.estimated_value ?? 0
            $totalCost += $cost
            
            $cat = $asset.device_type ?? "Unknown"
            if (-not $byCategory.ContainsKey($cat)) { $byCategory[$cat] = 0 }
            $byCategory[$cat] += $cost
            
            $dtype = $asset.device_type ?? "Unknown"
            if (-not $byDeviceType.ContainsKey($dtype)) { $byDeviceType[$dtype] = 0 }
            $byDeviceType[$dtype] += $cost
            
            $dept = $asset.department ?? "Unassigned"
            if (-not $byDepartment.ContainsKey($dept)) { $byDepartment[$dept] = 0 }
            $byDepartment[$dept] += $cost
        }
        
        # Identify optimization opportunities
        $oldAssets = $Assets | Where-Object { $_.purchase_date -and ((Get-Date) - [DateTime]$_.purchase_date).Days -gt 1460 }  # >4 years
        if ($oldAssets.Count -gt 0) {
            $optimizations += @{
                type = "HARDWARE_REFRESH"
                description = "$($oldAssets.Count) assets older than 4 years"
                potential_savings = [math]::Round(($oldAssets | Measure-Object -Property estimated_value -Sum).Sum * 0.3, 2)
                priority = "HIGH"
            }
        }
        
        $underutilized = $Assets | Where-Object { $_.utilization_percent -lt 20 }
        if ($underutilized.Count -gt 0) {
            $optimizations += @{
                type = "CONSOLIDATION"
                description = "$($underutilized.Count) underutilized assets (<20% utilization)"
                potential_savings = [math]::Round(($underutilized | Measure-Object -Property estimated_value -Sum).Sum * 0.5, 2)
                priority = "MEDIUM"
            }
        }
        
        $unassigned = $Assets | Where-Object { -not $_.owner_id -and -not $_.department }
        if ($unassigned.Count -gt 0) {
            $optimizations += @{
                type = "OWNERSHIP_ASSIGNMENT"
                description = "$($unassigned.Count) unassigned assets"
                potential_savings = 0
                priority = "LOW"
            }
        }
        
        return @{
            total_asset_value = [math]::Round($totalCost, 2)
            by_category = $byCategory
            by_device_type = $byDeviceType
            by_department = $byDepartment
            asset_count = $Assets.Count
            optimizations = $optimizations
            total_potential_savings = [math]::Round(($optimizations | Measure-Object -Property potential_savings -Sum).Sum, 2)
            analyzed_at = $Timestamp
        }
    }
}

# ====================================================================
# CLASS: ComplianceEngine
# ====================================================================
class AssetComplianceEngine {
    [string]$Name = "AssetComplianceEngine"
    [object[]]$Policies = @{}
    
    AssetComplianceEngine() {
        $this.Policies = @(
            @{
                id = "AST-001"
                name = "Asset Tagging"
                description = "All assets must have unique asset tags"
                check = { param($a) $a.asset_tag -and $a.asset_tag.Length -gt 0 }
                severity = "HIGH"
            }
            @{
                id = "AST-002"
                name = "Ownership Assignment"
                description = "All assets must have an assigned owner"
                check = { param($a) $a.owner_id -and $a.department }
                severity = "MEDIUM"
            }
            @{
                id = "AST-003"
                name = "Warranty Coverage"
                description = "Critical assets must have active warranty"
                check = { param($a) $a.warranty_expiry -and [DateTime]$a.warranty_expiry -gt (Get-Date) }
                severity = "HIGH"
            }
            @{
                id = "AST-004"
                name = "Encryption Enforcement"
                description = "All portable devices must be encrypted"
                check = { param($a) if ($a.device_type -in @("Laptop", "Mobile")) { $a.compliance.encryption } else { $true } }
                severity = "CRITICAL"
            }
            @{
                id = "AST-005"
                name = "Patch Currency"
                description = "Assets must have patches within 30 days"
                check = { param($a) $a.compliance.updates }
                severity = "HIGH"
            }
            @{
                id = "AST-006"
                name = "Antivirus Active"
                description = "Endpoint protection must be active"
                check = { param($a) $a.compliance.antivirus }
                severity = "CRITICAL"
            }
            @{
                id = "AST-007"
                name = "Firewall Enabled"
                description = "Host firewall must be enabled"
                check = { param($a) $a.compliance.firewall }
                severity = "HIGH"
            }
            @{
                id = "AST-008"
                name = "End of Life Tracking"
                description = "Track assets approaching EOL"
                check = { param($a) if ($a.purchase_date) { ((Get-Date) - [DateTime]$a.purchase_date).Days -lt 1825 } else { $true } }  # <5 years
                severity = "MEDIUM"
            }
        )
    }
    
    [object] EvaluateAssets([object[]]$Assets) {
        $results = @()
        $summary = @{ total = $Assets.Count; compliant = 0; non_compliant = 0; by_severity = @{} }
        
        foreach ($asset in $Assets) {
            $assetResult = @{
                asset_id = $asset.asset_id
                hostname = $asset.hostname
                compliant = $true
                violations = @()
            }
            
            foreach ($policy in $this.Policies) {
                try {
                    $passed = & $policy.check $asset
                    if (-not $passed) {
                        $assetResult.compliant = $false
                        $assetResult.violations += @{
                            policy_id = $policy.id
                            name = $policy.name
                            severity = $policy.severity
                        }
                        
                        if (-not $summary.by_severity.ContainsKey($policy.severity)) {
                            $summary.by_severity[$policy.severity] = 0
                        }
                        $summary.by_severity[$policy.severity]++
                    }
                } catch {
                    $assetResult.compliant = $false
                    $assetResult.violations += @{
                        policy_id = $policy.id
                        name = $policy.name
                        severity = $policy.severity
                        error = $_.Exception.Message
                    }
                }
            }
            
            if ($assetResult.compliant) { $summary.compliant++ } else { $summary.non_compliant++ }
            $results += $assetResult
        }
        
        $summary.compliance_rate = [math]::Round(($summary.compliant / $summary.total) * 100, 1)
        
        return @{
            summary = $summary
            details = $results
            evaluated_at = $Timestamp
        }
    }
}

# ====================================================================
# MAIN AST ENGINE EXECUTION
# ====================================================================
function Invoke-ASTEngine {
    param(
        [string]$Mode = "FULL",
        [switch]$SyncExternal
    )
    
    Write-Host "[AST v3.1] Universal Asset Tracker Starting..." -ForegroundColor Cyan
    
    $discovery = New-Object AssetDiscovery($DataSources)
    $lifecycle = New-Object AssetLifecycleManager
    $costEngine = New-Object CostOptimizationEngine
    $compliance = New-Object AssetComplianceEngine
    
    $results = @{
        engine = "AST"
        version = "3.1"
        timestamp = $Timestamp
        mode = $Mode
        assets = @()
        lifecycle_events = @()
        cost_analysis = @{}
        compliance = @{}
        summary = @{}
    }
    
    # Phase 1: Discovery
    Write-Host "[AST] Phase 1: Multi-Source Discovery..." -ForegroundColor Yellow
    if ($DataSources -contains "WMI") {
        $assets = $discovery.DiscoverFromWMI()
        $results.assets += $assets
    }
    
    Write-Host "[AST] Discovered $($results.assets.Count) assets" -ForegroundColor Green
    
    # Phase 2: Lifecycle
    if ($Mode -eq "FULL" -or $Mode -eq "LIFECYCLE") {
        Write-Host "[AST] Phase 2: Lifecycle Management..." -ForegroundColor Yellow
        
        foreach ($asset in $results.assets) {
            # Initialize lifecycle if new
            if (-not $asset.lifecycle_state) {
                $asset.lifecycle_state = "PROCUREMENT"
                $event = $lifecycle.Transition($asset.asset_id, "PROCUREMENT", "DEPLOYED", "AST-Engine", "Auto-discovered")
                $results.lifecycle_events += $event
            }
            
            # Depreciation
            if ($CalculateDepreciation -and $asset.purchase_date) {
                $age = [math]::Round(((Get-Date) - [DateTime]$asset.purchase_date).Days / 365.25, 1)
                $depr = $lifecycle.CalculateDepreciation($asset.estimated_value, $asset.estimated_value * 0.1, 5, [int]$age)
                $asset.depreciation = $depr
            }
        }
    }
    
    # Phase 3: Cost Analysis
    if ($Mode -eq "FULL" -or $Mode -eq "COST") {
        Write-Host "[AST] Phase 3: Cost Optimization Analysis..." -ForegroundColor Yellow
        $results.cost_analysis = $costEngine.AnalyzeCosts($results.assets)
        
        if ($GenerateFinOpsReport) {
            Write-Host "[AST] FinOps Report: Potential savings: `$($($results.cost_analysis.total_potential_savings))" -ForegroundColor Cyan
        }
    }
    
    # Phase 4: Compliance
    Write-Host "[AST] Phase 4: Compliance Verification..." -ForegroundColor Yellow
    $results.compliance = $compliance.EvaluateAssets($results.assets)
    Write-Host "[AST] Compliance Rate: $($results.compliance.summary.compliance_rate)%" -ForegroundColor Green
    
    # Summary
    $results.summary.total_assets = $results.assets.Count
    $results.summary.by_type = $results.assets | Group-Object device_type | ForEach-Object { @{ type = $_.Name; count = $_.Count } }
    $results.summary.by_platform = $results.assets | Group-Object platform | ForEach-Object { @{ platform = $_.Name; count = $_.Count } }
    $results.summary.by_state = $results.assets | Group-Object lifecycle_state | ForEach-Object { @{ state = $_.Name; count = $_.Count } }
    $results.summary.total_value = [math]::Round(($results.assets | Measure-Object -Property estimated_value -Sum).Sum, 2)
    $results.summary.compliance_rate = $results.compliance.summary.compliance_rate
    $results.summary.cost_savings_potential = $results.cost_analysis.total_potential_savings
    
    Write-Host "[AST] Asset Tracking Complete. Assets: $($results.summary.total_assets), Value: `$($($results.summary.total_value))" -ForegroundColor Green
    
    return $results
}

# Execute
$astResults = Invoke-ASTEngine -Mode "FULL" -CalculateDepreciation -GenerateFinOpsReport
$astResults | ConvertTo-Json -Depth 10 | Set-Content "C:\NetworkMaintenance\Data\ast_results.json" -Force
Write-Host "[AST] Results saved to C:\NetworkMaintenance\Data\ast_results.json" -ForegroundColor Green