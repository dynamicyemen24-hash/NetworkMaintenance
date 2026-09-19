# Elias Pro — Changelog

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

## v4.8.0 (2026-09-18)
- PWA command center, deep diagnostics, self-probe ELIAS-P-2026.
- Watchdog self-heal, NM-NET-STD-001, Vercel production URL.
