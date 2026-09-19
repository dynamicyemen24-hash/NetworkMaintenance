# ====================================================================
# NetworkMaintenance-Pro v3.1 - IVT Engine (Inventory Engine)
# ====================================================================
# Methodology: Multi-Protocol Discovery + CMDB + Relationship Mapping
# Standards: ITIL v4 Configuration Management, CMDB Best Practices
# ====================================================================

param(
    [string]$ConfigPath = "C:\NetworkMaintenance\Config\UniversalConfig.json",
    [string]$DataPath = "C:\NetworkMaintenance\Data",
    [string[]]$DiscoveryMethods = @("WMI", "SNMP", "SSH", "REST", "MDM", "ADB"),
    [string[]]$TargetNetworks = @("192.168.0.0/24", "10.0.0.0/8"),
    [switch]$DeepScan,
    [switch]$UpdateRelationships
)

$Config = Get-Content $ConfigPath | ConvertFrom-Json
$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"

# ====================================================================
# CLASS: DiscoveryEngine
# ====================================================================
class DiscoveryEngine {
    [string]$Name = "DiscoveryEngine"
    [string]$Version = "3.1"
    [hashtable]$DiscoveredDevices = @{}
    [int]$ScanCount = 0
    
    DiscoveryEngine([string[]]$Methods) {
        $this.Methods = $Methods
    }
    
    [object[]] DiscoverViaWMI([string]$Target) {
        $devices = @()
        try {
            $wmi = Get-WmiObject -ComputerName $Target -Class Win32_ComputerSystem -ErrorAction Stop
            $bios = Get-WmiObject -ComputerName $Target -Class Win32_BIOS
            $os = Get-WmiObject -ComputerName $Target -Class Win32_OperatingSystem
            $network = Get-WmiObject -ComputerName $Target -Class Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled}
            $disk = Get-WmiObject -ComputerName $Target -Class Win32_LogicalDisk
            $processor = Get-WmiObject -ComputerName $Target -Class Win32_Processor
            $memory = Get-WmiObject -ComputerName $Target -Class Win32_PhysicalMemory
            
            $macs = $network | ForEach-Object { $_.MACAddress } | Where-Object { $_ }
            $ips = $network | ForEach-Object { $_.IPAddress } | Where-Object { $_ } | ForEach-Object { $_ -join "," }
            
            $device = @{
                device_id = "wmi_" + [System.Guid]::NewGuid().ToString().Substring(0,8)
                hostname = $wmi.Name
                fqdn = $wmi.Name + "." + $wmi.Domain
                device_type = $this.ClassifyDeviceType($wmi)
                platform = "Windows"
                manufacturer = $wmi.Manufacturer
                model = $wmi.Model
                serial_number = $bios.SerialNumber
                asset_tag = $wmi.AssetTag
                mac_addresses = ($macs | ConvertTo-Json)
                ip_addresses = ($ips | ConvertTo-Json)
                os_version = $os.Caption + " " + $os.Version
                os_build = $os.BuildNumber
                cpu_info = @($processor | ForEach-Object { @{ name = $_.Name; cores = $_.NumberOfLogicalProcessors; speed = $_.MaxClockSpeed } }) | ConvertTo-Json
                memory_gb = [math]::Round(($memory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)
                disk_info = @($disk | ForEach-Object { @{ drive = $_.DeviceID; size = [math]::Round($_.Size/1GB,1); free = [math]::Round($_.FreeSpace/1GB,1) } }) | ConvertTo-Json
                last_inventory = $Timestamp
                tags = @("wmi", "auto-discovered") | ConvertTo-Json
            }
            $devices += $device
        } catch {
            Write-Warning "WMI discovery failed for $Target: $($_.Exception.Message)"
        }
        return $devices
    }
    
    [string] ClassifyDeviceType([object]$wmi) {
        $type = $wmi.PCSystemType
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
    
    [object[]] DiscoverViaSNMP([string]$Target, [string]$Community = "public") {
        $devices = @()
        # Simplified SNMP discovery - would use Net-SNMP or SharpSNMP in production
        Write-Host "[SNMP] Scanning $Target..." -ForegroundColor Yellow
        return $devices
    }
    
    [object[]] DiscoverViaSSH([string]$Target, [string]$Credential) {
        $devices = @()
        Write-Host "[SSH] Scanning $Target..." -ForegroundColor Yellow
        return $devices
    }
    
    [object[]] DiscoverViaMDM([string]$MDMServer, [string]$Token) {
        $devices = @()
        Write-Host "[MDM] Querying $MDMServer..." -ForegroundColor Yellow
        return $devices
    }
    
    [object[]] DiscoverViaADB([string]$Target) {
        $devices = @()
        Write-Host "[ADB] Scanning $Target..." -ForegroundColor Yellow
        return $devices
    }
}

# ====================================================================
# CLASS: ClassificationEngine
# ====================================================================
class ClassificationEngine {
    [string]$Name = "ClassificationEngine"
    [hashtable]$Rules = @{}
    
    ClassificationEngine() {
        $this.Rules = @{
            "Workstation" = @("PCSystemType:1", "Chassis:Desktop", "FormFactor:Tower")
            "Laptop" = @("PCSystemType:2", "PCSystemType:3", "Chassis:Portable", "Battery:Present")
            "Server" = @("PCSystemType:4", "PCSystemType:5", "Chassis:RackMount", "Chassis:Blade")
            "Mobile" = @("Platform:Android", "Platform:iOS", "MDM:Enrolled")
            "Network" = @("SNMP:sysObjectID:1.3.6.1.4.1.9", "Vendor:Cisco", "Vendor:Juniper")
            "IoT" = @("Protocol:MQTT", "Protocol:CoAP", "Protocol:LoRaWAN")
        }
    }
    
    [string] Classify([hashtable]$device) {
        $scores = @{}
        foreach ($category in $this.Rules.Keys) {
            $score = 0
            foreach ($rule in $this.Rules[$category]) {
                $parts = $rule -split ":"
                $key = $parts[0]
                $value = $parts[1]
                if ($device.ContainsKey($key) -and $device[$key] -like "*$value*") {
                    $score++
                }
            }
            $scores[$category] = $score
        }
        return ($scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
    }
}

# ====================================================================
# CLASS: RelationshipMapper
# ====================================================================
class RelationshipMapper {
    [string]$Name = "RelationshipMapper"
    [object[]]$Relationships = @()
    
    [object[]] MapNetworkTopology([object[]]$devices) {
        $relationships = @()
        
        # Map by MAC/IP adjacency
        foreach ($device in $devices) {
            $macs = $device.mac_addresses | ConvertFrom-Json
            $ips = $device.ip_addresses | ConvertFrom-Json
            
            foreach ($other in $devices) {
                if ($device.device_id -eq $other.device_id) { continue }
                
                $otherMacs = $other.mac_addresses | ConvertFrom-Json
                $otherIps = $other.ip_addresses | ConvertFrom-Json
                
                # Check for same subnet (Layer 2 adjacency)
                foreach ($ip in $ips) {
                    foreach ($oip in $otherIps) {
                        if ($this.IsSameSubnet($ip, $oip)) {
                            $relationships += @{
                                source = $device.device_id
                                target = $other.device_id
                                type = "CONNECTED_TO"
                                layer = 2
                                confidence = 0.8
                                discovered_at = $Timestamp
                            }
                        }
                    }
                }
            }
        }
        
        return $relationships
    }
    
    [bool] IsSameSubnet([string]$ip1, [string]$ip2) {
        try {
            $ip1Parts = $ip1 -split "\."
            $ip2Parts = $ip2 -split "\."
            return ($ip1Parts[0] -eq $ip2Parts[0] -and $ip1Parts[1] -eq $ip2Parts[1] -and $ip1Parts[2] -eq $ip2Parts[2])
        } catch {
            return $false
        }
    }
    
    [object[]] MapManagementRelationships([object[]]$devices) {
        $relationships = @()
        
        # MDM -> Mobile devices
        $mdmServers = $devices | Where-Object { $_.device_type -eq "MDM" }
        $mobileDevices = $devices | Where-Object { $_.device_type -eq "Mobile" }
        
        foreach ($mdm in $mdmServers) {
            foreach ($mobile in $mobileDevices) {
                $relationships += @{
                    source = $mdm.device_id
                    target = $mobile.device_id
                    type = "MANAGES"
                    protocol = "MDM"
                    confidence = 0.95
                }
            }
        }
        
        # Network equipment -> Interfaces
        $networkDevices = $devices | Where-Object { $_.device_type -eq "Network" }
        foreach ($net in $networkDevices) {
            $interfaces = $net.interfaces | ConvertFrom-Json
            foreach ($iface in $interfaces) {
                # Find connected device by MAC
                $connected = $devices | Where-Object { 
                    $macs = $_.mac_addresses | ConvertFrom-Json
                    $macs -contains $iface.mac_address
                }
                if ($connected) {
                    $relationships += @{
                        source = $net.device_id
                        target = $connected.device_id
                        type = "CONNECTED_TO"
                        layer = 2
                        source_interface = $iface.name
                        confidence = 0.9
                    }
                }
            }
        }
        
        return $relationships
    }
}

# ====================================================================
# CLASS: LifecycleTracker
# ====================================================================
class LifecycleTracker {
    [string]$Name = "LifecycleTracker"
    [hashtable]$StateTransitions = @{}
    
    LifecycleTracker() {
        $this.StateTransitions = @{
            "PROCUREMENT" = @("ACTIVE")
            "ACTIVE" = @("MAINTENANCE", "DECOMMISSIONED")
            "MAINTENANCE" = @("ACTIVE", "DECOMMISSIONED")
            "DECOMMISSIONED" = @("DISPOSED", "RETURN")
            "DISPOSED" = @()
            "RETURN" = @("ACTIVE", "DISPOSED")
        }
    }
    
    [bool] IsValidTransition([string]$from, [string]$to) {
        return $this.StateTransitions[$from] -contains $to
    }
    
    [object] RecordTransition([string]$deviceId, [string]$from, [string]$to, [string]$performedBy, [string]$notes) {
        if (-not $this.IsValidTransition($from, $to)) {
            throw "Invalid lifecycle transition: $from -> $to"
        }
        
        return @{
            device_id = $deviceId
            from_state = $from
            to_state = $to
            transition_date = (Get-Date).ToString("yyyy-MM-dd")
            performed_by = $performedBy
            notes = $notes
            recorded_at = $Timestamp
        }
    }
}

# ====================================================================
# MAIN IVT ENGINE EXECUTION
# ====================================================================
function Invoke-IVTEngine {
    param(
        [string]$Mode = "FULL",
        [string[]]$Targets = @()
    )
    
    Write-Host "[IVT v3.1] Inventory Engine Starting..." -ForegroundColor Cyan
    
    # Initialize components
    $discovery = New-Object DiscoveryEngine($DiscoveryMethods)
    $classifier = New-Object ClassificationEngine
    $mapper = New-Object RelationshipMapper
    $lifecycle = New-Object LifecycleTracker
    
    $results = @{
        engine = "IVT"
        version = "3.1"
        timestamp = $Timestamp
        mode = $Mode
        discovered = @()
        classified = @()
        relationships = @()
        lifecycle_events = @()
        statistics = @{}
    }
    
    # Phase 1: Discovery
    Write-Host "[IVT] Phase 1: Multi-Protocol Discovery..." -ForegroundColor Yellow
    $allDiscovered = @()
    
    # Local WMI discovery
    $localDevices = $discovery.DiscoverViaWMI("localhost")
    $allDiscovered += $localDevices
    
    $results.discovered = $allDiscovered
    $results.statistics.total_discovered = $allDiscovered.Count
    
    # Phase 2: Classification
    Write-Host "[IVT] Phase 2: Intelligent Classification..." -ForegroundColor Yellow
    foreach ($device in $allDiscovered) {
        $classifiedType = $classifier.Classify($device)
        $device.device_type = $classifiedType
        $results.classified += @{
            device_id = $device.device_id
            classified_type = $classifiedType
            confidence = 0.85
        }
    }
    
    # Phase 3: Relationship Mapping
    if ($UpdateRelationships) {
        Write-Host "[IVT] Phase 3: Relationship Mapping..." -ForegroundColor Yellow
        $netRelations = $mapper.MapNetworkTopology($allDiscovered)
        $mgmtRelations = $mapper.MapManagementRelationships($allDiscovered)
        $results.relationships = $netRelations + $mgmtRelations
    }
    
    # Phase 4: Lifecycle Update
    Write-Host "[IVT] Phase 4: Lifecycle Tracking..." -ForegroundColor Yellow
    foreach ($device in $allDiscovered) {
        $event = $lifecycle.RecordTransition(
            $device.device_id,
            "UNKNOWN",
            $device.lifecycle_state ?? "ACTIVE",
            "IVT-Engine",
            "Auto-discovered and classified"
        )
        $results.lifecycle_events += $event
    }
    
    # Statistics
    $results.statistics.by_type = $allDiscovered | Group-Object device_type | ForEach-Object { @{ type = $_.Name; count = $_.Count } }
    $results.statistics.by_platform = $allDiscovered | Group-Object platform | ForEach-Object { @{ platform = $_.Name; count = $_.Count } }
    
    Write-Host "[IVT] Inventory Complete. Devices: $($results.statistics.total_discovered)" -ForegroundColor Green
    
    return $results
}

# Execute
$ivtResults = Invoke-IVTEngine -Mode "FULL"
$ivtResults | ConvertTo-Json -Depth 10 | Set-Content "C:\NetworkMaintenance\Data\ivt_results.json" -Force
Write-Host "[IVT] Results saved to C:\NetworkMaintenance\Data\ivt_results.json" -ForegroundColor Green