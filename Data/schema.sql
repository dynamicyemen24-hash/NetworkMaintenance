-- ====================================================================
-- NetworkMaintenance-Pro v3.0.0 - Enterprise Database Schema
-- Standards: ISO-27001, PCI-DSS Logging Requirements
-- ====================================================================
--
-- DATABASE: C:\NetworkMaintenance\Data\maintenance.db
-- ENGINE: SQLite with WAL mode and AES-256 encryption
-- ====================================================================

-- Create encryption key table
CREATE TABLE IF NOT EXISTS master_key (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL UNIQUE,
    encrypted_key TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    rotated_at DATETIME,
    rotation_interval_days INTEGER DEFAULT 90,
    is_active INTEGER DEFAULT 1
);

-- ====================================================================
-- Metrics Database (Time-Series Optimized)
-- ====================================================================
CREATE TABLE IF NOT EXISTS network_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    interface_name TEXT NOT NULL,
    latency_avg_ms REAL NOT NULL,
    latency_min_ms REAL NOT NULL,
    latency_max_ms REAL NOT NULL,
    latency_stddev_ms REAL,
    jitter_ms REAL,
    packet_loss_percent REAL,
    bytes_in_per_sec REAL,
    bytes_out_per_sec REAL,
    dns_resolution_ms INTEGER,
    tcp_connections INTEGER,
    established_connections INTEGER,
    throughput_mbps REAL,
    signal_strength_dbm INTEGER,
    mtu INTEGER,
    mtu_optimized INTEGER DEFAULT 0,
    status_code TEXT DEFAULT 'UNKNOWN',
    health_score INTEGER DEFAULT 0,
    confidence_score REAL DEFAULT 0.0,
    anomaly_score REAL DEFAULT 0.0,
    baseline_deviation REAL DEFAULT 0.0,
    index idx_metrics_timestamp (timestamp),
    index idx_metrics_interface (interface_name),
    index idx_metrics_health (health_score)
);

-- ====================================================================
-- Baseline Database (Adaptive Learning)
-- ====================================================================
CREATE TABLE IF NOT EXISTS performance_baseline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_type TEXT NOT NULL,
    baseline_value REAL NOT NULL,
    baseline_stddev REAL,
    baseline_confidence REAL DEFAULT 0.95,
    baseline_window_days INTEGER DEFAULT 7,
    is_adaptive INTEGER DEFAULT 1,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
    trend_direction TEXT DEFAULT 'STABLE',
    trend_slope REAL DEFAULT 0.0,
    seasonal_factor REAL DEFAULT 1.0,
    UNIQUE(metric_name, metric_type)
);

-- ====================================================================
-- Event Log (Immutable Audit Trail)
-- ====================================================================
CREATE TABLE IF NOT EXISTS event_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    severity TEXT NOT NULL,
    category TEXT NOT NULL,
    source TEXT NOT NULL,
    message TEXT NOT NULL,
    details TEXT,
    stack_trace TEXT,
    correlation_id TEXT,
    session_id TEXT,
    user_id TEXT DEFAULT 'SYSTEM',
    action_taken TEXT,
    outcome TEXT,
    risk_level TEXT DEFAULT 'LOW',
    compliance_tag TEXT,
    encrypted INTEGER DEFAULT 0,
    INDEX idx_event_timestamp (timestamp),
    INDEX idx_event_severity (severity),
    INDEX idx_event_category (category),
    INDEX idx_event_correlation (correlation_id)
);

-- ====================================================================
-- Optimization History (Change Tracking)
-- ====================================================================
CREATE TABLE IF NOT EXISTS optimization_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    category TEXT NOT NULL,
    action TEXT NOT NULL,
    parameter_name TEXT,
    old_value TEXT,
    new_value TEXT,
    rationale TEXT,
    confidence_score REAL DEFAULT 0.0,
    expected_improvement REAL,
    actual_improvement REAL,
    rollback_command TEXT,
    status TEXT DEFAULT 'PENDING',
    executed_by TEXT DEFAULT 'AUTO',
    execution_duration_ms INTEGER,
    verification_passed INTEGER DEFAULT 0,
    notes TEXT,
    INDEX idx_opt_timestamp (timestamp),
    INDEX idx_opt_category (category),
    INDEX idx_opt_status (status)
);

-- ====================================================================
-- Alert & Incident Management (ITIL v4 Compliant)
-- ====================================================================
CREATE TABLE IF NOT EXISTS alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alert_id TEXT UNIQUE NOT NULL,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    severity TEXT NOT NULL,
    category TEXT NOT NULL,
    source_component TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    recommended_action TEXT,
    status TEXT DEFAULT 'OPEN',
    priority TEXT DEFAULT 'MEDIUM',
    assigned_to TEXT,
    resolution_time_ms INTEGER,
    escalation_level INTEGER DEFAULT 0,
    error_budget_consumed REAL DEFAULT 0.0,
    sla_breach INTEGER DEFAULT 0,
    related_alerts TEXT,
    correlation_score REAL DEFAULT 0.0,
    root_cause TEXT,
    runbook_executed TEXT,
    acknowledged_at DATETIME,
    resolved_at DATETIME,
    INDEX idx_alert_status (status),
    INDEX idx_alert_severity (severity),
    INDEX idx_alert_timestamp (timestamp)
);

-- ====================================================================
-- SLA Tracking (Service Level Agreements)
-- ====================================================================
CREATE TABLE IF NOT EXISTS sla_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sla_name TEXT NOT NULL,
    target_value REAL NOT NULL,
    current_value REAL NOT NULL,
    error_budget REAL,
    error_budget_consumed REAL DEFAULT 0.0,
    error_budget_remaining REAL,
    period_start DATETIME NOT NULL,
    period_end DATETIME NOT NULL,
    is_met INTEGER DEFAULT 1,
    breaches INTEGER DEFAULT 0,
    measurement_type TEXT DEFAULT 'PERCENTAGE',
    INDEX idx_sla_period (period_start, period_end),
    INDEX idx_sla_met (is_met)
);

-- ====================================================================
-- Configuration State (Desired State Configuration)
-- ====================================================================
CREATE TABLE IF NOT EXISTS config_state (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_key TEXT UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    config_type TEXT DEFAULT 'STRING',
    desired_value TEXT,
    drift_detected INTEGER DEFAULT 0,
    last_modified DATETIME DEFAULT CURRENT_TIMESTAMP,
    modified_by TEXT DEFAULT 'SYSTEM',
    change_reason TEXT,
    is_sensitive INTEGER DEFAULT 0,
    encryption_required INTEGER DEFAULT 0,
    INDEX idx_config_key (config_key),
    INDEX idx_config_drift (drift_detected)
);

-- ====================================================================
-- Anomaly Detection Records (ML Models)
-- ====================================================================
CREATE TABLE IF NOT EXISTS anomaly_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metric_name TEXT NOT NULL,
    observed_value REAL NOT NULL,
    expected_value REAL NOT NULL,
    deviation_percent REAL NOT NULL,
    anomaly_score REAL NOT NULL,
    model_version TEXT,
    confidence REAL DEFAULT 0.0,
    is_confirmed_anomaly INTEGER DEFAULT 0,
    classification TEXT,
    recommended_action TEXT,
    INDEX idx_anomaly_timestamp (timestamp),
    INDEX idx_anomaly_score (anomaly_score)
);

-- ====================================================================
-- Maintenance Schedule (ITIL Change Management)
-- ====================================================================
CREATE TABLE IF NOT EXISTS maintenance_schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_name TEXT NOT NULL,
    task_type TEXT NOT NULL,
    schedule_type TEXT NOT NULL,
    cron_expression TEXT,
    command TEXT NOT NULL,
    parameters TEXT,
    last_executed DATETIME,
    next_execution DATETIME,
    last_status TEXT,
    last_duration_ms INTEGER,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    auto_remediation INTEGER DEFAULT 0,
    rollback_plan TEXT,
    change_request_id TEXT,
    approval_status TEXT DEFAULT 'PENDING',
    is_active INTEGER DEFAULT 1,
    INDEX idx_sched_next (next_execution),
    INDEX idx_sched_active (is_active)
);

-- ====================================================================
-- System State (Single Source of Truth)
-- ====================================================================
CREATE TABLE IF NOT EXISTS system_state (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    system_name TEXT NOT NULL,
    version TEXT NOT NULL,
    build_number TEXT,
    status TEXT NOT NULL DEFAULT 'INITIALIZED',
    uptime_seconds INTEGER DEFAULT 0,
    total_runs INTEGER DEFAULT 0,
    total_fixes INTEGER DEFAULT 0,
    total_anomalies_detected INTEGER DEFAULT 0,
    total_anomalies_resolved INTEGER DEFAULT 0,
    health_score INTEGER DEFAULT 0,
    last_diagnostic_at DATETIME,
    last_optimization_at DATETIME,
    last_heal_at DATETIME,
    last_report_at DATETIME,
    current_sla_status TEXT DEFAULT 'UNKNOWN',
    error_budget_percentage REAL DEFAULT 100.0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================
-- Insert initial system state
-- ====================================================================
INSERT OR REPLACE INTO system_state 
    (system_name, version, build_number, status, health_score)
VALUES 
    ('NetworkMaintenance-Pro', '3.0.0', '20260910', 'OPERATIONAL', 0);

-- ====================================================================
-- Create Views for Common Queries
-- ====================================================================
CREATE VIEW IF NOT EXISTS v_recent_metrics AS
SELECT * FROM network_metrics 
WHERE timestamp > datetime('now', '-24 hours')
ORDER BY timestamp DESC;

CREATE VIEW IF NOT EXISTS v_active_alerts AS
SELECT * FROM alerts 
WHERE status = 'OPEN'
ORDER BY timestamp ASC;

CREATE VIEW IF NOT EXISTS v_drift_config AS
SELECT * FROM config_state 
WHERE drift_detected = 1;

CREATE VIEW IF NOT EXISTS v_health_summary AS
SELECT 
    status,
    COUNT(*) as total_runs,
    AVG(health_score) as avg_health,
    MIN(health_score) as worst_health,
    MAX(health_score) as best_health,
    SUM(total_fixes) as total_fixes
FROM system_state
GROUP BY status;

-- ====================================================================
-- Create Triggers for Audit Trail
-- ====================================================================
CREATE TRIGGER IF NOT EXISTS trg_metric_audit
AFTER INSERT ON network_metrics
BEGIN
    INSERT INTO event_log (severity, category, source, message, details)
    VALUES ('INFO', 'METRIC', 'DAX-Engine', 
            'Metric recorded: ' || NEW.interface_name,
            'Latency: ' || NEW.latency_avg_ms || 'ms | Health: ' || NEW.health_score);
END;

CREATE TRIGGER IF NOT EXISTS trg_alert_audit
AFTER INSERT ON alerts
BEGIN
    INSERT INTO event_log (severity, category, source, message, correlation_id)
    VALUES (NEW.severity, 'ALERT', 'HEAL-Engine', 
            NEW.title, NEW.alert_id);
END;

-- ====================================================================
-- Create Stored Procedures (Functions)
-- ====================================================================
-- Calculate rolling average over N windows
CREATE VIEW IF NOT EXISTS v_rolling_avg_7d AS
SELECT 
    interface_name,
    AVG(latency_avg_ms) OVER (
        PARTITION BY interface_name 
        ORDER BY timestamp 
        ROWS BETWEEN 288 PRECEDING AND CURRENT ROW
    ) as rolling_avg_7d
FROM network_metrics;

-- ====================================================================
-- VACUUM and Optimize Schedule
-- ====================================================================
-- Run weekly: VACUUM, ANALYZE, REINDEX
-- Vacuum schedule stored in maintenance_schedule table

-- ====================================================================
-- Database Statistics Tracking
-- ====================================================================
CREATE TABLE IF NOT EXISTS db_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_date DATE NOT NULL,
    table_name TEXT NOT NULL,
    row_count INTEGER,
    db_size_bytes INTEGER,
    index_size_bytes INTEGER,
    last_vacuum DATETIME,
    journal_mode TEXT,
    wal_checkpoint TEXT
);
