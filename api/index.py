"""
Elias Pro v5.0 — Vercel Python Bridge (api/index.py)
=====================================================
Cloned from: G:\System_Optimizer_Pro_X_2026\UAME\api\index.py
Adapted for: Elias Pro — Universal Maintenance Suite
Purpose: Vercel Serverless bridge to PowerShell engines via JSON files
         Works on any device (Vercel Edge) — no Windows required
         Falls back to JSON mock, upgrades to real DB when available
"""

import json
import os
from pathlib import Path
from datetime import datetime, timezone

# Vercel Python handler
try:
    from http.server import BaseHTTPRequestHandler
except ImportError:
    pass

DATA_PATH = Path(__file__).parent.parent / "Data"
CONFIG_PATH = Path(__file__).parent.parent / "Config" / "EnterpriseConfig.json"

# ── LRU Cache with TTL (30s) for API efficiency ──
_cache = {}
_cache_ttl = 30  # seconds

def load_json_cached(name, ttl=30):
    import time
    key = name
    now = time.time()
    if key in _cache:
        data, ts = _cache[key]
        if now - ts < ttl:
            return data
    data = load_json(name)
    _cache[key] = (data, now)
    return data

def invalidate_cache(name=None):
    if name:
        _cache.pop(name, None)
    else:
        _cache.clear()

def load_json(name):
    p = DATA_PATH / name
    if p.exists():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except:
            return []
    return []

def save_json(name, data):
    p = DATA_PATH / name
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    invalidate_cache(name)

def json_response(handler, data, status=200):
    body = json.dumps(data, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    handler.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Subscription-Key")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)

# Vercel entry point
class handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Subscription-Key")
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]

        # Health — works without DB
        if path in ("/api/v1/health", "/api/health", "/health"):
            # Try to load SCE/HDR health if available
            health_score = 72
            hdr_score = 70
            try:
                sce = load_json("sce_results.json")
                if isinstance(sce, dict) and sce.get("health", {}).get("score"):
                    health_score = sce["health"]["score"]
            except:
                pass
            json_response(self, {
                "status": "OPERATIONAL",
                "version": "5.0.0",
                "name": "Elias Pro",
                "name_ar": "الياس برو",
                "health_score": health_score,
                "hdr_score": hdr_score,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "platform": "vercel-python-bridge",
                "message": "Works on any device — Vercel Edge"
            })
            return

        # Shop stats
        if path == "/api/v1/shop/stats":
            tickets = load_json("tickets.json")
            if not isinstance(tickets, list):
                tickets = [tickets] if tickets else []
            invoices = load_json("invoices.json")
            if not isinstance(invoices, list):
                invoices = [invoices] if invoices else []
            customers = load_json("customers.json")
            if not isinstance(customers, list):
                customers = [customers] if customers else []
            parts = load_json("inventory_parts.json")
            if not isinstance(parts, list):
                parts = [parts] if parts else []
            total_sales = sum(float(x.get("total", 0)) for x in invoices if isinstance(x, dict))
            json_response(self, {
                "tickets_total": len(tickets),
                "tickets_pending": len([t for t in tickets if isinstance(t, dict) and t.get("status") in ("RECEIVED","DIAGNOSED","QUOTED","APPROVED","REPAIRING","QC")]),
                "tickets_ready": len([t for t in tickets if isinstance(t, dict) and t.get("status") == "READY"]),
                "customers_total": len(customers),
                "inventory_total": len(parts),
                "inventory_low": len([p for p in parts if isinstance(p, dict) and int(p.get("quantity", 0)) <= int(p.get("min_quantity", 2))]),
                "total_sales": round(total_sales, 2),
                "invoices_total": len(invoices),
                "platform": "vercel"
            })
            return

        # Tickets — with pagination & search (q, status, page, limit)
        if path.startswith("/api/v1/shop/tickets"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            q = qs.get("q", [""])[0].lower()
            status = qs.get("status", [""])[0]
            page = int(qs.get("page", ["1"])[0])
            limit = min(int(qs.get("limit", ["20"])[0]), 100)
            tickets = load_json_cached("tickets.json", ttl=30)
            if not isinstance(tickets, list):
                tickets = [tickets] if tickets else []
            # Filter
            filtered = tickets
            if q:
                filtered = [t for t in filtered if isinstance(t, dict) and (q in str(t.get("ticket_no","")).lower() or q in str(t.get("reported_issue","")).lower() or q in str(t.get("brand","")).lower())]
            if status:
                filtered = [t for t in filtered if isinstance(t, dict) and t.get("status") == status]
            # Pagination
            total = len(filtered)
            start = (page-1)*limit
            paginated = filtered[start:start+limit]
            # ETag
            import hashlib
            etag = hashlib.md5(json.dumps(paginated, sort_keys=True).encode()).hexdigest()[:8]
            if self.headers.get("If-None-Match") == etag:
                self.send_response(304)
                self.end_headers()
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("X-Total-Count", str(total))
            self.send_header("X-Page", str(page))
            self.send_header("X-Total-Pages", str((total+limit-1)//limit))
            self.send_header("ETag", etag)
            self.send_header("Cache-Control", "public, max-age=30")
            self.end_headers()
            self.wfile.write(json.dumps(paginated, ensure_ascii=False).encode("utf-8"))
            return

        # Customers
        if path == "/api/v1/shop/customers":
            json_response(self, load_json("customers.json"))
            return

        # Inventory
        if path == "/api/v1/shop/inventory":
            json_response(self, load_json("inventory_parts.json"))
            return
        if path == "/api/v1/shop/inventory/lowstock":
            parts = load_json("inventory_parts.json")
            if not isinstance(parts, list):
                parts = []
            low = [p for p in parts if isinstance(p, dict) and int(p.get("quantity", 0)) <= int(p.get("min_quantity", 2))]
            json_response(self, low)
            return

        # Invoices
        if path == "/api/v1/shop/invoices":
            json_response(self, load_json("invoices.json"))
            return

        # Config
        if path == "/api/v1/config":
            try:
                cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
                json_response(self, cfg)
            except:
                json_response(self, {"error": "config not found"}, 404)
            return

        # Device snapshot/history (mirrors Pode Device-Diagnostics for deep.html)
        if path in ("/api/v1/device/snapshot", "/api/v1/history"):
            snap = load_json("device-snapshot.json") if (DATA_PATH / "device-snapshot.json").exists() else load_json("device-history.json")
            # history file lives in Data/device-history.json on Windows host
            hist_path = DATA_PATH / "device-history.json"
            if path == "/api/v1/history" and hist_path.exists():
                try:
                    snap = json.loads(hist_path.read_text(encoding="utf-8"))
                except:
                    pass
            json_response(self, snap if snap else {"status": "no-data", "message": "Run Scripts/Device-DeepDiagnostics.ps1 on Windows host"})
            return
        if path in ("/api/v1/device/facts", "/api/v1/device/storage", "/api/v1/device/battery",
                    "/api/v1/device/thermal", "/api/v1/device/processes", "/api/v1/mobile/adb"):
            json_response(self, {"status": "host-only", "message": "Requires Windows host with Pode API", "path": path})
            return

        # Logs (light index — full logs require Windows host)
        if path == "/api/v1/logs":
            json_response(self, load_json("production_errors.json") if (DATA_PATH / "production_errors.json").exists() else [])
            return

        # Subscription plans
        if path == "/api/v1/subscription/plans":
            json_response(self, [
                {"id": "free", "name": "Free", "price": 0, "currency": "EGP", "engines": ["HDR"], "devices": 1, "features": ["تشخيص أساسي"]},
                {"id": "pro", "name": "Pro", "price": 299, "currency": "EGP", "period": "month", "engines": ["HDR","BATT","STORAGE","STRESS","NETDIAG"], "devices": 5, "features": ["كل التشخيصات","تقارير PDF","دعم فني"]},
                {"id": "enterprise", "name": "Enterprise", "price": 999, "currency": "EGP", "period": "month", "engines": ["all"], "devices": 20, "features": ["كل المحركات","White-label","API كامل","PWA"]}
            ])
            return

        # Fallback — serve frontend
        json_response(self, {"error": "Not found", "path": path}, 404)

    def do_POST(self):
        path = self.path.split("?")[0]
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            data = json.loads(body) if body else {}
        except:
            data = {}

        # Create ticket
        if path == "/api/v1/shop/tickets":
            if not data.get("customer_id") or not data.get("reported_issue"):
                json_response(self, {"error": "customer_id and reported_issue required"}, 400)
                return
            tickets = load_json("tickets.json")
            if not isinstance(tickets, list):
                tickets = [tickets] if tickets else []
            new_ticket = {
                "ticket_id": __import__("uuid").uuid4().hex,
                "ticket_no": f"TKT-{datetime.now().strftime('%Y-%m')}-{__import__('random').randint(1000,9999)}",
                "customer_id": data["customer_id"],
                "device_type": data.get("device_type", "Mobile"),
                "brand": data.get("brand", ""),
                "model": data.get("model", ""),
                "reported_issue": data["reported_issue"],
                "status": "RECEIVED",
                "created_at": datetime.now(timezone.utc).isoformat()
            }
            tickets.append(new_ticket)
            save_json("tickets.json", tickets)
            json_response(self, new_ticket, 201)
            return

        # Create customer
        if path == "/api/v1/shop/customers":
            customers = load_json("customers.json")
            if not isinstance(customers, list):
                customers = [customers] if customers else []
            new_customer = {
                "customer_id": __import__("uuid").uuid4().hex,
                "customer_no": f"CUST-{datetime.now().year}-{__import__('random').randint(10000,99999)}",
                "name": data.get("name", "Unknown"),
                "phone": data.get("phone", ""),
                "address": data.get("address", ""),
                "created_at": datetime.now(timezone.utc).isoformat()
            }
            customers.append(new_customer)
            save_json("customers.json", customers)
            json_response(self, new_customer, 201)
            return

        # Auth login (demo JWT — mirrors Pode; production needs real verify)
        if path == "/api/v1/auth/login":
            import base64
            if data.get("username") == "admin" and data.get("password") == "admin123":
                payload = base64.b64encode(json.dumps({"user": "admin", "role": "Admin"}).encode()).decode()
                json_response(self, {"token": payload, "user": {"username": "admin", "role": "Admin"}})
            else:
                json_response(self, {"error": "Invalid credentials"}, 401)
            return

        # Diagnostics
        if path == "/api/v1/shop/diagnostics":
            # Mock HDR result — in production, would call PowerShell or Python diagnostic
            json_response(self, {
                "engine": "HDR",
                "version": "5.0",
                "device_type": data.get("device_type", "Auto"),
                "overall_score": 72,
                "overall_status": "GOOD",
                "battery": {"health_percent": 67, "status": "FAIR"},
                "storage": {"health_percent": 95, "used_percent": 45},
                "ai_recommendation": "Device in good condition",
                "platform": "vercel-python"
            })
            return

        # Clean
        if path == "/api/v1/clean":
            json_response(self, {
                "engine": "SCE",
                "version": "5.0",
                "dry_run": data.get("dryRun", True),
                "summary": {"total_freed_mb": 0, "total_deleted": 0},
                "message": "SCE DryRun on Vercel — real cleaning requires Windows host"
            })
            return

        # Subscription webhook (Stripe)
        if path == "/api/v1/subscription/webhook":
            # Verify Stripe signature in production
            json_response(self, {"received": True, "event": data.get("type", "unknown")})
            return

        # Subscription checkout
        if path == "/api/v1/subscription/checkout":
            plan = data.get("plan", "pro")
            prices = {"free": 0, "pro": 299, "enterprise": 999}
            json_response(self, {
                "checkout_url": f"https://checkout.stripe.com/pay/{plan}",
                "plan": plan,
                "price": prices.get(plan, 299),
                "currency": "EGP",
                "message": "Integrate Stripe: https://stripe.com/docs/checkout/quickstart"
            })
            return

        json_response(self, {"error": "Not found", "path": path}, 404)

    def do_PUT(self):
        # Ticket status update
        if "/api/v1/shop/tickets/" in self.path and "/status" in self.path:
            parts = self.path.split("?")[0].split("/")
            # /api/v1/shop/tickets/{ticketNo}/status -> index 5
            ticket_no = parts[5] if len(parts) > 5 else ""
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length > 0 else b"{}"
            try:
                data = json.loads(body) if body else {}
            except:
                data = {}
            tickets = load_json("tickets.json")
            if not isinstance(tickets, list):
                tickets = [tickets] if tickets else []
            updated = None
            for t in tickets:
                if isinstance(t, dict) and t.get("ticket_no") == ticket_no:
                    if data.get("status"):
                        t["status"] = data["status"]
                    updated = t
                    break
            if updated:
                save_json("tickets.json", tickets)
                json_response(self, updated)
            else:
                json_response(self, {"ticket_no": ticket_no, "status": data.get("status", "updated"), "platform": "vercel"})
            return
        json_response(self, {"error": "Not found"}, 404)
