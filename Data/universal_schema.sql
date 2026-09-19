-- ====================================================================
-- NetworkMaintenance-Pro v3.1 - Universal Database Schema
-- CMDB + Device Inventory + Multi-Platform Support
-- ====================================================================

-- DEVICE INVENTORY (CMDB)
CREATE TABLE IF NOT EXISTS devices (
    device_id TEXT PRIMARY KEY,
    hostname TEXT,
    fqdn TEXT,
    device_type TEXT NOT NULL,  -- Workstation, Laptop, Mobile, Server, Network, IoT, Embedded, Peripheral
    platform TEXT NOT NULL,      -- Windows, Linux, macOS, Android, iOS, NetworkOS, IoT-OS, Firmware
    manufacturer TEXT,
    model TEXT,
    serial_number TEXT UNIQUE,
    asset_tag TEXT UNIQUE,
    mac_addresses TEXT,          -- JSON array
    ip_addresses TEXT,           -- JSON array
    location_id TEXT,
    owner_id TEXT,
    department TEXT,
    cost_center TEXT,
    purchase_date DATE,
    warranty_expiry DATE,
    lifecycle_state TEXT DEFAULT 'ACTIVE',  -- PROCUREMENT, ACTIVE, MAINTENANCE, DECOMMISSIONED, DISPOSED
    compliance_status TEXT DEFAULT 'UNKNOWN',
    last_seen DATETIME,
    last_inventory DATETIME,
    tags TEXT,                   -- JSON
    custom_fields TEXT,          -- JSON
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_devices_type ON devices(device_type);
CREATE INDEX IF NOT EXISTS idx_devices_platform ON devices(platform);
CREATE INDEX IF NOT EXISTS idx_devices_location ON devices(location_id);
CREATE INDEX IF NOT EXISTS idx_devices_state ON devices(lifecycle_state);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen);

-- DEVICE RELATIONSHIPS (Topology)
CREATE TABLE IF NOT EXISTS device_relationships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_device_id TEXT NOT NULL,
    target_device_id TEXT NOT NULL,
    relationship_type TEXT NOT NULL,  -- CONNECTED_TO, MANAGED_BY, DEPENDS_ON, HOSTS, VIRTUALIZES, BACKS_UP
    interface_source TEXT,
    interface_target TEXT,
    metadata TEXT,                   -- JSON
    discovered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    verified BOOLEAN DEFAULT 0,
    FOREIGN KEY (source_device_id) REFERENCES devices(device_id),
    FOREIGN KEY (target_device_id) REFERENCES devices(device_id)
);

-- MOBILE DEVICES (Extended)
CREATE TABLE IF NOT EXISTS mobile_devices (
    device_id TEXT PRIMARY KEY,
    udid TEXT UNIQUE,
    imei TEXT,
    imsi TEXT,
    phone_number TEXT,
    iccid TEXT,
    meid TEXT,
    os_version TEXT,
    build_number TEXT,
    security_patch_level TEXT,
    enrollment_type TEXT,          -- USER, DEVICE, ABM, ZT, KNOX
    ownership TEXT,                -- CORPORATE, BYOD, COPE, COBO
    management_state TEXT,         -- MANAGED, UNMANAGED, RETIRED, WIPE_PENDING
    supervision BOOLEAN DEFAULT 0,
    activation_lock BOOLEAN DEFAULT 0,
    passcode_compliant BOOLEAN,
    encryption_status TEXT,
    jailbreak_detected BOOLEAN DEFAULT 0,
    last_checkin DATETIME,
    last_push DATETIME,
    available_os_update TEXT,
    installed_profiles TEXT,       -- JSON array
    installed_apps TEXT,           -- JSON array
    restrictions TEXT,             -- JSON
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- NETWORK EQUIPMENT (Extended)
CREATE TABLE IF NOT EXISTS network_equipment (
    device_id TEXT PRIMARY KEY,
    vendor TEXT NOT NULL,
    model TEXT NOT NULL,
    os_type TEXT,                  -- IOS-XE, JunOS, EOS, RouterOS, FortiOS, PAN-OS, etc.
    os_version TEXT,
    serial_number TEXT,
    chassis_type TEXT,             -- CHASSIS, STACK, VIRTUAL_CHASSIS
    slot_count INTEGER,
    power_supply_count INTEGER,
    fan_count INTEGER,
    temperature_celsius REAL,
    cpu_utilization REAL,
    memory_utilization REAL,
    flash_utilization REAL,
    uptime_seconds INTEGER,
    config_register TEXT,
    boot_image TEXT,
    running_config_hash TEXT,
    startup_config_hash TEXT,
    config_sync_status TEXT,       -- IN_SYNC, OUT_OF_SYNC, UNKNOWN
    license_info TEXT,             -- JSON
    interfaces TEXT,               -- JSON array of interfaces
    neighbors TEXT,                -- JSON array (CDP/LLDP)
    routing_table_size INTEGER,
    bgp_peers INTEGER,
    ospf_neighbors INTEGER,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- INTERFACES (Network)
CREATE TABLE IF NOT EXISTS interfaces (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    type TEXT,                     -- PHYSICAL, VIRTUAL, SUBINTERFACE, LAG, VLAN, LOOPBACK, TUNNEL
    mac_address TEXT,
    ipv4_address TEXT,
    ipv4_netmask TEXT,
    ipv6_address TEXT,
    ipv6_prefix_length INTEGER,
    mtu INTEGER,
    speed_mbps INTEGER,
    duplex TEXT,                   -- FULL, HALF, AUTO
    status TEXT,                   -- UP, DOWN, ADMIN_DOWN, ERROR_DISABLED
    protocol_status TEXT,          -- UP, DOWN
    vlan_id INTEGER,
    trunk_vlans TEXT,              -- JSON array
    poe_enabled BOOLEAN DEFAULT 0,
    poe_power_watts REAL,
    errors_in INTEGER,
    errors_out INTEGER,
    discards_in INTEGER,
    discards_out INTEGER,
    utilization_in_percent REAL,
    utilization_out_percent REAL,
    last_change DATETIME,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- IoT DEVICES (Extended)
CREATE TABLE IF NOT EXISTS iot_devices (
    device_id TEXT PRIMARY KEY,
    device_class TEXT,             -- SENSOR, ACTUATOR, GATEWAY, CONTROLLER, EDGE_COMPUTE
    protocol TEXT,                 -- MQTT, CoAP, LoRaWAN, Zigbee, Thread, Matter, Modbus, OPC-UA
    firmware_version TEXT,
    hardware_version TEXT,
    certificate_serial TEXT,
    last_telemetry DATETIME,
    telemetry_frequency_seconds INTEGER,
    battery_level REAL,
    signal_strength_dbm INTEGER,
    connectivity_status TEXT,      -- ONLINE, OFFLINE, INTERMITTENT, PROVISIONING
    provisioning_state TEXT,       -- UNPROVISIONED, PROVISIONING, PROVISIONED, FAILED
    edge_gateway_id TEXT,
    data_format TEXT,              -- JSON, PROTOBUF, CBOR, CUSTOM
    encryption_enabled BOOLEAN DEFAULT 1,
    ota_update_supported BOOLEAN DEFAULT 1,
    tags TEXT,                     -- JSON
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- HARDWARE COMPONENTS
CREATE TABLE IF NOT EXISTS hardware_components (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    component_type TEXT NOT NULL,  -- CPU, MEMORY, STORAGE, GPU, NETWORK, BATTERY, MOTHERBOARD, PSU, FAN, DISPLAY
    manufacturer TEXT,
    model TEXT,
    serial_number TEXT,
    part_number TEXT,
    specifications TEXT,           -- JSON (cores, frequency, capacity, etc.)
    firmware_version TEXT,
    driver_version TEXT,
    status TEXT DEFAULT 'OK',      -- OK, DEGRADED, FAILING, FAILED, UNKNOWN
    health_score INTEGER DEFAULT 100,
    temperature_celsius REAL,
    power_consumption_watts REAL,
    install_date DATE,
    warranty_expiry DATE,
    smart_data TEXT,               -- JSON for storage SMART
    benchmarks TEXT,               -- JSON
    last_tested DATETIME,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- FIRMWARE INVENTORY
CREATE TABLE IF NOT EXISTS firmware_inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    component_type TEXT NOT NULL,
    current_version TEXT NOT NULL,
    latest_version TEXT,
    vendor TEXT,
    release_date DATE,
    severity TEXT,                 -- CRITICAL, HIGH, MEDIUM, LOW, NONE
    cve_list TEXT,                 -- JSON array
    description TEXT,
    download_url TEXT,
    checksum_sha256 TEXT,
    size_bytes INTEGER,
    requires_reboot BOOLEAN DEFAULT 0,
    supported_models TEXT,         -- JSON array
    superseded_by INTEGER,
    deployment_status TEXT DEFAULT 'PENDING',  -- PENDING, STAGED, DEPLOYING, DEPLOYED, FAILED, ROLLED_BACK
    deployed_at DATETIME,
    deployed_by TEXT,
    rollback_version TEXT,
    compliance BOOLEAN DEFAULT 0,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- VULNERABILITIES
CREATE TABLE IF NOT EXISTS vulnerabilities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cve_id TEXT UNIQUE,
    title TEXT,
    description TEXT,
    cvss_score REAL,
    cvss_vector TEXT,
    severity TEXT,                 -- CRITICAL, HIGH, MEDIUM, LOW, NONE
    published_date DATE,
    modified_date DATE,
    affected_products TEXT,        -- JSON
    affected_devices TEXT,         -- JSON (device_ids)
    exploit_available BOOLEAN DEFAULT 0,
    patch_available BOOLEAN DEFAULT 0,
    workaround TEXT,
    references TEXT,               -- JSON array
    risk_score REAL DEFAULT 0,
    status TEXT DEFAULT 'OPEN',    -- OPEN, IN_PROGRESS, MITIGATED, RESOLVED, ACCEPTED_RISK
    assigned_to TEXT,
    due_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- PATCH MANAGEMENT
CREATE TABLE IF NOT EXISTS patches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patch_id TEXT UNIQUE,
    title TEXT,
    description TEXT,
    vendor TEXT,
    product TEXT,
    version TEXT,
    classification TEXT,           -- SECURITY, CRITICAL, IMPORTANT, MODERATE, LOW, FEATURE
    severity TEXT,
    release_date DATE,
    kb_article TEXT,
    download_url TEXT,
    size_bytes INTEGER,
    requires_reboot BOOLEAN DEFAULT 0,
    supersedes TEXT,               -- JSON array of patch_ids
    superseded_by TEXT,
    applicable_devices TEXT,       -- JSON array of device_ids or queries
    deployment_status TEXT DEFAULT 'NOT_APPLICABLE',  -- NOT_APPLICABLE, APPLICABLE, DOWNLOADED, STAGED, INSTALLED, FAILED, NOT_INSTALLED
    installed_at DATETIME,
    installed_by TEXT,
    reboot_required BOOLEAN DEFAULT 0,
    compliance_deadline DATE
);

-- ASSET LIFECYCLE
CREATE TABLE IF NOT EXISTS asset_lifecycle (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    event_type TEXT NOT NULL,      -- PROCUREMENT, RECEIPT, DEPLOYMENT, TRANSFER, MAINTENANCE, UPGRADE, DECOMMISSION, DISPOSAL, RETURN, LOSS
    event_date DATE NOT NULL,
    performed_by TEXT,
    location_from TEXT,
    location_to TEXT,
    cost REAL,
    notes TEXT,
    documents TEXT,                -- JSON array of document references
    approved_by TEXT,
    approval_date DATE,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- SOFTWARE INVENTORY
CREATE TABLE IF NOT EXISTS software_inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    publisher TEXT,
    install_date DATE,
    install_location TEXT,
    size_bytes INTEGER,
    license_type TEXT,             -- FREWARE, SHAREWARE, COMMERCIAL, OPEN_SOURCE, SUBSCRIPTION, VOLUME
    license_key TEXT,
    license_expiry DATE,
    license_count INTEGER,
    used_count INTEGER,
    automatic_updates BOOLEAN DEFAULT 0,
    last_used DATETIME,
    is_approved BOOLEAN DEFAULT 1,
    vulnerability_count INTEGER DEFAULT 0,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- MONITORING METRICS (Time-series optimized)
CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_type TEXT NOT NULL,     -- GAUGE, COUNTER, HISTOGRAM, SUMMARY
    value REAL NOT NULL,
    unit TEXT,
    labels TEXT,                   -- JSON
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

CREATE INDEX IF NOT EXISTS idx_metrics_device_time ON metrics(device_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_metrics_name_time ON metrics(metric_name, timestamp);

-- ALERTS (ITIL v4)
CREATE TABLE IF NOT EXISTS alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alert_id TEXT UNIQUE NOT NULL,
    device_id TEXT,
    severity TEXT NOT NULL,        -- CRITICAL, HIGH, MEDIUM, LOW, INFO
    category TEXT NOT NULL,        -- PERFORMANCE, AVAILABILITY, SECURITY, CAPACITY, COMPLIANCE, CONFIGURATION
    title TEXT NOT NULL,
    description TEXT,
    source TEXT,
    metric_name TEXT,
    current_value REAL,
    threshold_value REAL,
    status TEXT DEFAULT 'OPEN',    -- OPEN, ACKNOWLEDGED, IN_PROGRESS, RESOLVED, CLOSED, SUPPRESSED
    priority TEXT DEFAULT 'MEDIUM', -- P1, P2, P3, P4, P5
    assigned_to TEXT,
    escalation_level INTEGER DEFAULT 0,
    sla_breach BOOLEAN DEFAULT 0,
    error_budget_consumed REAL DEFAULT 0,
    correlation_id TEXT,
    root_cause TEXT,
    resolution TEXT,
    acknowledged_at DATETIME,
    resolved_at DATETIME,
    closed_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- SLA TRACKING
CREATE TABLE IF NOT EXISTS sla_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sla_name TEXT NOT NULL,
    device_type TEXT,
    device_group TEXT,
    metric_name TEXT NOT NULL,
    target_value REAL NOT NULL,
    warning_threshold REAL,
    critical_threshold REAL,
    measurement_window TEXT,       -- 5m, 15m, 1h, 24h, 7d, 30d
    current_value REAL,
    error_budget REAL,
    error_budget_consumed REAL DEFAULT 0,
    period_start DATETIME NOT NULL,
    period_end DATETIME NOT NULL,
    is_met BOOLEAN DEFAULT 1,
    breaches INTEGER DEFAULT 0,
    availability_percent REAL,
    measurement_type TEXT DEFAULT 'PERCENTAGE'
);

-- BACKUP STATUS
CREATE TABLE IF NOT EXISTS backup_status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    backup_type TEXT,              -- FULL, INCREMENTAL, DIFFERENTIAL, SNAPSHOT, CONTINUOUS
    backup_target TEXT,            -- LOCAL, NETWORK, CLOUD, TAPE
    last_backup_start DATETIME,
    last_backup_end DATETIME,
    last_backup_status TEXT,       -- SUCCESS, FAILED, PARTIAL, RUNNING, SKIPPED
    last_backup_size_bytes INTEGER,
    last_backup_duration_seconds INTEGER,
    next_scheduled_backup DATETIME,
    rpo_minutes INTEGER,           -- Recovery Point Objective
    rto_minutes INTEGER,           -- Recovery Time Objective
    retention_days INTEGER,
    encryption_enabled BOOLEAN DEFAULT 1,
    verification_status TEXT,      -- VERIFIED, FAILED, PENDING, SKIPPED
    last_verified DATETIME,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- COMPLIANCE
CREATE TABLE IF NOT EXISTS compliance_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    check_id TEXT UNIQUE NOT NULL,
    framework TEXT NOT NULL,       -- ISO27001, NIST, PCI-DSS, HIPAA, GDPR, SOX, CIS
    control_id TEXT,
    title TEXT NOT NULL,
    description TEXT,
    device_id TEXT,
    device_group TEXT,
    status TEXT DEFAULT 'UNKNOWN', -- PASS, FAIL, WARNING, NOT_APPLICABLE, UNKNOWN
    evidence TEXT,
    remediation TEXT,
    severity TEXT DEFAULT 'MEDIUM',
    last_checked DATETIME,
    next_check DATETIME,
    checked_by TEXT,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

-- VIEWS
CREATE VIEW IF NOT EXISTS v_device_summary AS
SELECT
    device_type,
    platform,
    lifecycle_state,
    COUNT(*) as count,
    AVG(CASE WHEN compliance_status = 'COMPLIANT' THEN 1 ELSE 0 END) * 100 as compliance_rate
FROM devices
GROUP BY device_type, platform, lifecycle_state;

CREATE VIEW IF NOT EXISTS v_critical_alerts AS
SELECT * FROM alerts WHERE severity IN ('CRITICAL', 'HIGH') AND status IN ('OPEN', 'ACKNOWLEDGED');

CREATE VIEW IF NOT EXISTS v_firmware_outdated AS
SELECT * FROM firmware_inventory WHERE latest_version != current_version AND severity IN ('CRITICAL', 'HIGH');

CREATE VIEW IF NOT EXISTS v_devices_offline AS
SELECT * FROM devices WHERE last_seen < datetime('now', '-1 hour') AND lifecycle_state = 'ACTIVE';

CREATE VIEW IF NOT EXISTS v_mobile_compliance AS
SELECT * FROM mobile_devices WHERE passcode_compliant = 0 OR encryption_status != 'ENCRYPTED' OR jailbreak_detected = 1;

-- TRIGGERS
CREATE TRIGGER IF NOT EXISTS trg_device_updated
AFTER UPDATE ON devices
BEGIN
    UPDATE devices SET updated_at = CURRENT_TIMESTAMP WHERE device_id = NEW.device_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_alert_audit
AFTER INSERT ON alerts
BEGIN
    INSERT INTO audit_log (event_type, resource_type, resource_id, action, details)
    VALUES ('ALERT_CREATED', 'DEVICE', NEW.device_id, NEW.title, json_object('severity', NEW.severity, 'category', NEW.category));
END;

-- AUDIT LOG
CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    event_type TEXT NOT NULL,
    resource_type TEXT,
    resource_id TEXT,
    action TEXT,
    user_id TEXT,
    source_ip TEXT,
    details TEXT,                  -- JSON
    risk_level TEXT DEFAULT 'LOW',
    compliance_tags TEXT           -- JSON
);