# ====================================================================
# Elias Pro v5.0 — Production Dockerfile (PowerShell Backend)
# ====================================================================
# Base: Windows Server Core with PowerShell 7 + Python for ML
# For Linux: use mcr.microsoft.com/powershell:7.4-ubuntu-22.04
# ====================================================================

# ── Stage 1: Frontend Builder (Vercel-like) ──
FROM node:20-alpine AS frontend-builder
WORKDIR /app
COPY Dashboard/ ./Dashboard/
COPY Branding/ ./Branding/
# No build needed — static HTML, but we can minify
RUN npm install -g html-minifier-terser 2>/dev/null || true

# ── Stage 2: PowerShell Backend ──
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

LABEL maintainer="FixMaster Technology <support@eliaspro.local>"
LABEL version="5.0.0"
LABEL description="Elias Pro — Universal Maintenance Suite"

# System deps (smartctl, iperf3, nmap, sqlite)
RUN apt-get update && apt-get install -y \
    smartmontools \
    iperf3 \
    nmap \
    sqlite3 \
    curl \
    python3 \
    python3-pip \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# PowerShell modules
RUN pwsh -Command "Install-Module PSSQLite -Force -Scope AllUsers; Install-Module Pode -Force -Scope AllUsers" || true

# Python deps for ML (optional)
RUN pip3 install fastapi uvicorn pydantic sqlalchemy --quiet || true

WORKDIR /app

# Copy full project
COPY . .

# Copy frontend
COPY --from=frontend-builder /app/Dashboard ./Dashboard
COPY --from=frontend-builder /app/Branding ./Branding

# Expose ports (REST only — GraphQL/WS disabled in v5.0)
EXPOSE 8080

# Health check (aligned with compose: 120s)
HEALTHCHECK --interval=120s --timeout=5s --start-period=60s --retries=2 \
    CMD pwsh -Command "try { Invoke-RestMethod http://127.0.0.1:8080/api/v1/health -TimeoutSec 5 | Out-Null; exit 0 } catch { exit 1 }"

# Entrypoint — same as System_Optimizer entrypoint.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["pwsh", "-File", "API/Server-Pode.ps1", "-Port", "8080", "-EnableSwagger"]
