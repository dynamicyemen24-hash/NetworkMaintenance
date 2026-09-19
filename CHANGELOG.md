# Elias Pro — Changelog

## v5.1.0-Autonomous (2026-09-19) — Autonomous Self-Healing Release
- **OS-Health-Healer (new)**: autonomous Windows healing — CPU deprioritize, RAM trim, disk temp clean, dead-service restart, DNS flush, AC power plan; check-only by default, `-Enforce` for scheduled runs; max 6 actions/run with per-action cooldowns; never kills, never reboots.
- **Register-AutonomousSelfHeal (new)**: one-shot registrar for the 4-task SYSTEM fabric (network watchdog + OS healer every 30min + event responders for Tcpip 4199 / WLAN 4003) with baseline enforcement.
- **Self-heal bugfixes**: Apply-NetworkStandard + Fix-Network-Deep no longer abort on stale default-gateway route (remove route first, DHCP fallback so host never goes offline); WinPS 5.1-compatible probing (no PS7-only params).
- **Operator adaptation**: DNS order 8.8.8.8-first (1.1.1.1 filtered by operator), watchdog probes real HTTPS round-trip instead of filtered direct-IP :443.
- **Watchdog honesty**: LIVE failures vs HISTORY counters split — history alone no longer sustains DEGRADED/escalation; stale NETWORK_ALERT cleared; merged `system-health-last.json` for agents.
- Fixed package.json `watchdog` script (removed invalid flag); publish.ps1 now ships the self-heal scripts.
- **Module repair**: fixed blocking class errors in 4/5 enhanced modules (Reliability: script-scope vars + interpolation; Security: AesGcm→AES-256-CBC for WinPS 5.1 + missing return; Standardization: stray bracket + property/local collision + script-scope var) — all parse 0 errors, crypto round-trip verified live.
- **Deferred**: MaintenanceModule (36 class errors, needs rewrite — excluded from package/manifest/scripts until repaired); crypto labels corrected GCM→CBC; VERSION branding line restored.

## v5.0.0 (2026-09-19) — Final Release
- Unified version 5.0.0 across VERSION/manifest/package/API/installer/SW/Docker.
- API parity: Pode adds POST /auth/login, GET /subscription/plans, POST /subscription/checkout|webhook, tickets pagination (q/status/page/limit + X-Total-Count); Vercel bridge adds device/snapshot|history, device/* host-only, logs, POST /auth/login; fixed PUT ticketNo index bug.
- Fixed Dashboard dead links: download shop/index/docs/ZIP, login/pricing redirects to tech/*, checkout path /api/v1/*.
- Removed hardcoded admin/admin123 prefill (security hygiene).
- Service Worker v5.0.0: offline shell adds pricing/download/tech/shop/index-pro.
- Run.ps1: new modes batt/storage/stress/netdiag/backup/health (wires orphan engines).
- Perf: watchdog 5→30min, PingCount 20→4, health 30→300s, Docker healthcheck 120s, frontend poll 180s, API private no-cache, ETag on tickets.
- Security: HSTS + CSP + Permissions-Policy, API Cache private, install shortcut fixed.
- Docs: CHANGELOG/SECURITY/LICENSE added; README v5.0.

## v5.0.0-Enhanced (2026-09-19) — Module Enhancement Release
- **MaintenanceModule v5.0.0**: Core orchestrator with 32-engine registry, MaintenanceOrchestrator class, SecurityAuditEngine, ReliabilityWatchdog, EffectivenessTracker classes.
- **SecurityEnhancement v5.0.0**: Zero-Trust Engine (ABAC-RBAC-AC), AES-256-GCM Encryption Engine with AesGcm, RBAC Manager with 9 roles, Audit Trail Manager with immutable logging, Incident Response Manager with 5 P-levels, Compliance Validator for all frameworks.
- **ReliabilityModule v5.0.0**: Reliability Watchdog with circuit breaker, Network Standard Compliance (NM-NET-STD-001), Disaster Recovery Manager with RTO/RPO, High Availability Manager with health endpoints, Self-healing with rollback capability.
- **EffectivenessModule v5.0.0**: Metrics Collector with 16 KPIs, Real-Time Monitor with 6 alert channels, ML Prediction Engine (5 models), Report Generator with 6 formats, Performance Optimizer with 5 strategies.
- **StandardizationModule v5.0.0**: ITIL v4 Framework, ISO 27001 Framework, NIST CSF Framework, COBIT 2019 Framework, PCI DSS 3.2.1 Framework, SOC2 Type II Framework, ELIAS-P-2026 Standard.
- Added publish.ps1 for final package distribution with SHA256SUMS.
- Enhanced Enterprise-Main.ps1 with full orchestration support.
- Added 5 new modules under Modules/ directory.

## v4.8.0 (2026-09-18)
- PWA command center, deep diagnostics, self-probe ELIAS-P-2026.
- Watchdog self-heal, NM-NET-STD-001, Vercel production URL.
