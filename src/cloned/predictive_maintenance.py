"""
UAME Predictive Maintenance Analytics Engine
Provides trend analysis, failure prediction, and anomaly detection
for enterprise equipment using statistical methods.
"""
import math
import sqlite3
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

from uame.infrastructure.database.real_production_db import get_db_connection


class PredictiveMaintenanceEngine:
    """
    Statistical predictive maintenance engine using:
    - Mean Time Between Failures (MTBF) analysis
    - Trend-based remaining useful life (RUL) estimation
    - Anomaly detection via z-score
    - Risk scoring based on multiple factors
    """

    def __init__(self):
        self._ensure_tables()

    def _ensure_tables(self):
        conn = get_db_connection()
        try:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS maintenance_predictions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    tenant_id TEXT NOT NULL,
                    asset_id TEXT NOT NULL,
                    prediction_type TEXT NOT NULL,
                    risk_score REAL,
                    predicted_date TEXT,
                    confidence REAL,
                    factors TEXT,
                    recommendation TEXT,
                    created_at TEXT NOT NULL DEFAULT (datetime('now'))
                );
                CREATE INDEX IF NOT EXISTS idx_pred_tenant_asset ON maintenance_predictions(tenant_id, asset_id);

                CREATE TABLE IF NOT EXISTS equipment_telemetry (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    tenant_id TEXT NOT NULL,
                    asset_id TEXT NOT NULL,
                    metric_name TEXT NOT NULL,
                    metric_value REAL,
                    recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
                );
                CREATE INDEX IF NOT EXISTS idx_tel_tenant_asset ON equipment_telemetry(tenant_id, asset_id);
            """)
            conn.commit()
        finally:
            conn.close()

    def record_telemetry(self, tenant_id: str, asset_id: str, metrics: Dict[str, float]) -> None:
        """Record equipment telemetry readings for trend analysis."""
        conn = get_db_connection()
        try:
            now = datetime.now(timezone.utc).isoformat()
            for name, value in metrics.items():
                conn.execute(
                    """INSERT INTO equipment_telemetry (tenant_id, asset_id, metric_name, metric_value, recorded_at)
                       VALUES (?,?,?,?,?)""",
                    (tenant_id, asset_id, name, value, now),
                )
            conn.commit()
        finally:
            conn.close()

    def calculate_mtbf(self, tenant_id: str, asset_id: str) -> Optional[Dict[str, Any]]:
        """Calculate Mean Time Between Failures from incident history."""
        conn = get_db_connection()
        try:
            incidents = conn.execute("""
                SELECT performed_at FROM enterprise_maintenance_logs
                WHERE tenant_id = ? AND asset_id = ? AND action = 'incident'
                ORDER BY performed_at ASC
            """, (tenant_id, asset_id)).fetchall()

            if len(incidents) < 2:
                return {"mtbf_hours": None, "incident_count": len(incidents),
                        "note": "Insufficient incident data for MTBF calculation"}

            dates = [datetime.fromisoformat(r["performed_at"][:19]) for r in incidents]
            intervals = [(dates[i+1] - dates[i]).total_seconds() / 3600 for i in range(len(dates)-1)]
            avg_interval = sum(intervals) / len(intervals)

            return {
                "mtbf_hours": round(avg_interval, 1),
                "mtbf_days": round(avg_interval / 24, 1),
                "incident_count": len(incidents),
                "avg_interval_hours": round(avg_interval, 1),
                "std_dev_hours": round(math.sqrt(sum((x - avg_interval)**2 for x in intervals) / len(intervals)), 1),
                "reliability_score": max(0, min(100, 100 - (len(intervals) * 10))),
            }
        finally:
            conn.close()

    def analyze_trend(self, tenant_id: str, asset_id: str, metric_name: str, days: int = 90) -> Dict[str, Any]:
        """Analyze telemetry trend for a specific metric."""
        conn = get_db_connection()
        try:
            cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
            rows = conn.execute("""
                SELECT metric_value, recorded_at FROM equipment_telemetry
                WHERE tenant_id = ? AND asset_id = ? AND metric_name = ? AND recorded_at >= ?
                ORDER BY recorded_at ASC
            """, (tenant_id, asset_id, metric_name, cutoff)).fetchall()

            if len(rows) < 3:
                return {"trend": "insufficient_data", "data_points": len(rows)}

            values = [r["metric_value"] for r in rows]
            n = len(values)
            mean = sum(values) / n
            variance = sum((x - mean)**2 for x in values) / n
            std = math.sqrt(variance)

            x_vals = list(range(n))
            x_mean = sum(x_vals) / n
            slope_num = sum((x - x_mean) * (v - mean) for x, v in zip(x_vals, values))
            slope_den = sum((x - x_mean)**2 for x in x_vals)
            slope = slope_num / slope_den if slope_den > 0 else 0

            if std > 0:
                z_scores = [(v - mean) / std for v in values]
                anomalies = sum(1 for z in z_scores if abs(z) > 2.5)
            else:
                anomalies = 0

            if slope > 0.01:
                direction = "increasing"
            elif slope < -0.01:
                direction = "decreasing"
            else:
                direction = "stable"

            return {
                "metric": metric_name,
                "data_points": n,
                "mean": round(mean, 2),
                "std_dev": round(std, 2),
                "trend_slope": round(slope, 4),
                "trend_direction": direction,
                "anomalies_detected": anomalies,
                "min_value": round(min(values), 2),
                "max_value": round(max(values), 2),
                "latest_value": round(values[-1], 2),
                "volatility": round(std / mean * 100, 1) if mean > 0 else 0,
            }
        finally:
            conn.close()

    def calculate_risk_score(self, tenant_id: str, asset_id: str) -> Dict[str, Any]:
        """Calculate comprehensive risk score for an asset."""
        conn = get_db_connection()
        try:
            asset = conn.execute(
                "SELECT * FROM enterprise_assets WHERE tenant_id = ? AND asset_id = ?",
                (tenant_id, asset_id),
            ).fetchone()

            if not asset:
                return {"error": "Asset not found"}

            asset = dict(asset)
            today = date.today()
            risk_factors = []
            score = 0

            # Factor 1: Maintenance overdue (0-30 points)
            next_maint = asset.get("next_maintenance")
            if next_maint:
                days_overdue = (today - date.fromisoformat(next_maint[:10])).days
                if days_overdue > 0:
                    factor_score = min(30, days_overdue * 0.5)
                    score += factor_score
                    risk_factors.append({"factor": "maintenance_overdue", "days": days_overdue, "score": round(factor_score, 1)})

            # Factor 2: Calibration overdue (0-25 points)
            cal_due = asset.get("calibration_due")
            if cal_due and asset.get("sector") in ("hospital", "production_lab"):
                days_overdue = (today - date.fromisoformat(cal_due[:10])).days
                if days_overdue > 0:
                    factor_score = min(25, days_overdue * 0.3)
                    score += factor_score
                    risk_factors.append({"factor": "calibration_overdue", "days": days_overdue, "score": round(factor_score, 1)})

            # Factor 3: Incident frequency (0-25 points)
            incidents = conn.execute("""
                SELECT COUNT(*) as c FROM enterprise_maintenance_logs
                WHERE tenant_id = ? AND asset_id = ? AND action = 'incident'
                  AND performed_at >= date('now', '-1 year')
            """, (tenant_id, asset_id)).fetchone()["c"]
            if incidents > 0:
                factor_score = min(25, incidents * 5)
                score += factor_score
                risk_factors.append({"factor": "incident_frequency", "count": incidents, "score": round(factor_score, 1)})

            # Factor 4: Age-based depreciation (0-10 points)
            acq_date = asset.get("acquisition_date")
            if acq_date:
                age_years = (today - date.fromisoformat(acq_date[:10])).days / 365.25
                if age_years > 3:
                    factor_score = min(10, (age_years - 3) * 2)
                    score += factor_score
                    risk_factors.append({"factor": "asset_age", "years": round(age_years, 1), "score": round(factor_score, 1)})

            # Factor 5: Warranty status (bonus reduction)
            warranty = asset.get("warranty_until")
            if warranty and warranty[:10] >= today.isoformat():
                score = max(0, score - 10)
                risk_factors.append({"factor": "under_warranty", "score": -10})

            score = min(100, max(0, score))

            if score >= 75:
                risk_level = "critical"
                recommendation = "Immediate inspection required. Consider asset replacement."
            elif score >= 50:
                risk_level = "high"
                recommendation = "Schedule preventive maintenance within 7 days."
            elif score >= 25:
                risk_level = "medium"
                recommendation = "Monitor closely. Schedule maintenance within 30 days."
            else:
                risk_level = "low"
                recommendation = "Asset is in good condition. Continue routine maintenance."

            # Store prediction
            conn.execute(
                """INSERT INTO maintenance_predictions
                   (tenant_id, asset_id, prediction_type, risk_score, confidence, factors, recommendation)
                   VALUES (?,?,?,?,?,?,?)""",
                (tenant_id, asset_id, "risk_assessment", score, 0.85,
                 str(risk_factors), recommendation),
            )
            conn.commit()

            return {
                "asset_id": asset_id,
                "risk_score": round(score, 1),
                "risk_level": risk_level,
                "recommendation": recommendation,
                "factors": risk_factors,
                "analyzed_at": datetime.now(timezone.utc).isoformat(),
            }
        finally:
            conn.close()

    def predict_failure_date(self, tenant_id: str, asset_id: str) -> Dict[str, Any]:
        """Predict estimated failure date based on MTBF and trend analysis."""
        mtbf = self.calculate_mtbf(tenant_id, asset_id)
        risk = self.calculate_risk_score(tenant_id, asset_id)

        if not mtbf.get("mtbf_days"):
            return {
                "asset_id": asset_id,
                "predicted_failure_date": None,
                "confidence": 0.3,
                "note": "Insufficient data for prediction. Using risk-based estimation.",
                "estimated_days_to_failure": max(30, 365 - risk.get("risk_score", 0) * 3),
            }

        mtbf_days = mtbf["mtbf_days"]
        last_incident = None
        conn = get_db_connection()
        try:
            row = conn.execute("""
                SELECT performed_at FROM enterprise_maintenance_logs
                WHERE tenant_id = ? AND asset_id = ? AND action = 'incident'
                ORDER BY performed_at DESC LIMIT 1
            """, (tenant_id, asset_id)).fetchone()
            if row:
                last_incident = date.fromisoformat(row["performed_at"][:10])
        finally:
            conn.close()

        if last_incident:
            days_since = (date.today() - last_incident).days
            remaining = max(1, mtbf_days - days_since)
        else:
            remaining = mtbf_days

        risk_factor = 1.0 - (risk.get("risk_score", 0) / 100)
        adjusted_remaining = remaining * risk_factor
        predicted_date = date.today() + timedelta(days=int(adjusted_remaining))

        confidence = 0.5 + (mtbf.get("incident_count", 0) * 0.05)
        confidence = min(0.95, confidence)

        return {
            "asset_id": asset_id,
            "predicted_failure_date": predicted_date.isoformat(),
            "estimated_days_to_failure": round(adjusted_remaining),
            "mtbf_days": mtbf_days,
            "risk_adjusted": True,
            "confidence": round(confidence, 2),
            "factors_considered": ["mtbf", "risk_score", "last_incident"],
        }

    def get_fleet_health_overview(self, tenant_id: str) -> Dict[str, Any]:
        """Get predictive health overview for all assets in fleet."""
        conn = get_db_connection()
        try:
            assets = conn.execute(
                "SELECT asset_id FROM enterprise_assets WHERE tenant_id = ? AND status != 'retired'",
                (tenant_id,),
            ).fetchall()

            results = []
            for a in assets:
                risk = self.calculate_risk_score(tenant_id, a["asset_id"])
                results.append({
                    "asset_id": a["asset_id"],
                    "risk_score": risk.get("risk_score", 0),
                    "risk_level": risk.get("risk_level", "unknown"),
                })

            results.sort(key=lambda x: x["risk_score"], reverse=True)

            critical = sum(1 for r in results if r["risk_level"] == "critical")
            high = sum(1 for r in results if r["risk_level"] == "high")
            medium = sum(1 for r in results if r["risk_level"] == "medium")
            low = sum(1 for r in results if r["risk_level"] == "low")
            avg_score = sum(r["risk_score"] for r in results) / max(len(results), 1)

            return {
                "total_assets": len(results),
                "risk_distribution": {"critical": critical, "high": high, "medium": medium, "low": low},
                "average_risk_score": round(avg_score, 1),
                "top_risk_assets": results[:10],
                "health_index": round(max(0, 100 - avg_score), 1),
            }
        finally:
            conn.close()


predictive_engine = PredictiveMaintenanceEngine()
