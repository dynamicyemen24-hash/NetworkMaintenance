# Elias Pro — Security Policy

- Supported: v5.0.x only.
- Auth: demo JWT (Base64, localStorage). Production must use HttpOnly cookies + server verify + rotation. Do not commit real passwords — demo admin/admin123 is local-only.
- RBAC matrix in Scripts/Engines/Security-Framework.ps1 must be enforced server-side (Test-Access) before exposing /shop /device /logs /config.
- CORS is `*` for demo. Restrict to https://elias-pro.vercel.app in production.
- TLS: Vercel provides HTTPS + HSTS. Windows Pode/LAN share are HTTP-only — do not expose without reverse proxy.
- Secrets: never commit Data/, Logs/, Config/encryption.key. Postgres password placeholder must come from env.
- Report issues: https://github.com/anomalyco/opencode/issues
