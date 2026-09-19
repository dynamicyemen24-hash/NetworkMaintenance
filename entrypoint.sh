#!/bin/bash
# ====================================================================
# Elias Pro — Entrypoint (cloned from System_Optimizer/entrypoint.sh)
# ====================================================================
set -e

echo "========================================"
echo "  Elias Pro v4.2 — Starting..."
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "========================================"

# Initialize database if needed
if [ ! -f "/app/Data/repair_shop.db" ] || [ ! -s "/app/Data/repair_shop.db" ]; then
  echo "[INIT] Initializing database..."
  pwsh -File /app/Scripts/Initialize-Database.ps1 -Seed || echo "[WARN] DB init fallback to JSON"
fi

# Check open source tools
echo "[TOOLS] Checking open source toolkit..."
pwsh -File /app/Scripts/Tools/OpenSourceToolkit.ps1 || true

# Start API in background if custom CMD not provided
if [ "$1" = "pwsh" ]; then
  exec "$@"
else
  # Default: start Pode API
  exec pwsh -File /app/API/Server-Pode.ps1 -Port 8080 -EnableSwagger
fi
