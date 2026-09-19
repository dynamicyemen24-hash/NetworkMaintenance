# NetworkMaintenance-Pro v3.0.0 - Enterprise API Documentation
# ====================================================================
# Protocol: RESTful over HTTPS (TLS 1.3)
# Authentication: Bearer Token with JWT
# Rate Limiting: 60 requests/minute, 10 burst
# Base URL: http://127.0.0.1:8080/api/v1
# ====================================================================

## AUTHENTICATION
# POST /api/v1/auth/token
# Returns: {"token": "jwt_token", "expires_in": 3600, "role": "Admin"}

## HEALTH CHECK
# GET /api/v1/health
# Returns: System health status with SLA information
# Response:
# {
#   "status": "OPERATIONAL",
#   "uptime_seconds": 86400,
#   "health_score": 85,
#   "sla_status": "MET",
#   "error_budget_remaining": 45.2,
#   "last_check": "2026-09-10T16:00:00Z",
#   "components": {
#     "diagnostic": "HEALTHY",
#     "optimization": "HEALTHY",
#     "healing": "HEALTHY",
#     "monitoring": "HEALTHY"
#   }
# }

## DIAGNOSTICS
# GET /api/v1/diagnostics
# Query Parameters:
#   - interface (optional): Filter by interface name
#   - since (optional): ISO 8601 timestamp for time range
#   - limit (optional): Number of results (default 100)
# Returns: Comprehensive diagnostic results
# Response:
# {
#   "diagnostic_id": "diag_20260910_001",
#   "timestamp": "2026-09-10T16:00:00Z",
#   "status": "COMPLETED",
#   "summary": {
#     "latency_avg": 947.8,
#     "latency_status": "CRITICAL",
#     "dns_status": "HEALTHY",
#     "tcp_status": "WARNING",
#     "adapter_status": "WARNING"
#   },
#   "details": { ... },
#   "recommendations": [ ... ],
#   "confidence_score": 0.92,
#   "anomaly_detected": true,
#   "root_cause_analysis": { ... }
# }

# POST /api/v1/diagnostics/scan
# Trigger an on-demand diagnostic scan
# Returns: Diagnostic task ID

# GET /api/v1/diagnostics/{id}
# Get results of a specific diagnostic scan

# GET /api/v1/diagnostics/{id}/report
# Download full diagnostic report (PDF/HTML/JSON)

## METRICS
# GET /api/v1/metrics
# Returns: Current network metrics
# Response:
# {
#   "timestamp": "2026-09-10T16:00:00Z",
#   "metrics": {
#     "latency": { "avg": 947.8, "min": 130, "max": 2683, "stddev": 748 },
#     "jitter": 45.2,
#     "packet_loss": 0.0,
#     "throughput": { "in": 45.2, "out": 32.1 },
#     "dns": { "resolution_ms": 23, "server": "1.1.1.1" },
#     "tcp": { "connections": 100, "established": 45 },
#     "health_score": 35,
#     "anomaly_score": 0.87
#   }
# }

# GET /api/v1/metrics/history
# Query Parameters: from, to, interface, metric_type
# Returns: Historical metrics (time-series)

# GET /api/v1/metrics/baseline
# Returns: Current performance baselines

# POST /api/v1/metrics/baseline/update
# Update performance baselines (auto-learning)

# GET /api/v1/metrics/anomalies
# Returns: Detected anomalies with ML confidence scores

## OPTIMIZATION
# GET /api/v1/optimization/status
# Current optimization status and applied changes

# POST /api/v1/optimization/apply
# Body: { "components": ["tcp", "dns", "adapters"], "dry_run": false }
# Apply optimizations with approval workflow

# POST /api/v1/optimization/rollback
# Rollback last optimization

# GET /api/v1/optimization/history
# History of all optimization actions

# GET /api/v1/optimization/recommendations
# AI-driven optimization recommendations

## ALERTS & INCIDENTS (ITIL v4)
# GET /api/v1/alerts
# Query Parameters: status, severity, category
# Returns: Active alerts

# GET /api/v1/alerts/{id}
# Get specific alert details

# POST /api/v1/alerts/{id}/acknowledge
# Acknowledge an alert

# POST /api/v1/alerts/{id}/resolve
# Resolve an alert with resolution notes

# POST /api/v1/alerts/{id}/escalate
# Escalate alert to next level

# GET /api/v1/incidents
# List all incidents

# POST /api/v1/incidents
# Create a new incident

## SLA TRACKING
# GET /api/v1/sla
# Current SLA status and error budgets

# GET /api/v1/sla/history
# Historical SLA performance

# GET /api/v1/sla/prediction
# Predicted SLA compliance for next 7 days

## LOGS
# GET /api/v1/logs
# Query Parameters: level, source, since, limit
# Returns: Filtered log entries

# GET /api/v1/logs/stream
# WebSocket stream of real-time log entries

## CONFIGURATION
# GET /api/v1/config
# Get all configuration

# PUT /api/v1/config/{key}
# Update configuration value

# GET /api/v1/config/drift
# Get configuration drift report

# POST /api/v1/config/apply
# Apply desired state configuration

## REPORTS
# GET /api/v1/reports
# List available reports

# POST /api/v1/reports/generate
# Generate a new report
# Body: { "type": "health", "format": "html", "period": "7d" }

# GET /api/v1/reports/{id}
# Download a report

# GET /api/v1/reports/schedule
# Scheduled report configuration

## WEBSOCKETS
# ws://127.0.0.1:8080/api/v1/stream
# Real-time metrics stream
# Events: metric_update, alert_new, optimization_applied, anomaly_detected

## WEBHOOKS
# POST /api/v1/webhooks/register
# Register a webhook endpoint for alerts

# Error Responses:
# {
#   "error": {
#     "code": "LATENCY_CRITICAL",
#     "message": "Latency exceeds critical threshold",
#     "details": "Average latency 947.8ms exceeds 500ms threshold",
#     "severity": "CRITICAL",
#     "timestamp": "2026-09-10T16:00:00Z",
#     "request_id": "req_xyz123"
#   }
# }
