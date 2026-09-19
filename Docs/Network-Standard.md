# NM-NET-STD-001 — Network Reliability & Performance Standard

**Owner:** NMS   **Version:** 1.0   **Reviewed:** 2026-09-18
**Machine:** DESKTOP-VU55LB7   **Primary NIC:** Intel Wireless-AC 9260 / "Wi-Fi"

This document defines the enforceable, self-healing network baseline. It is not a one-time
fix: every item is re-verified continuously by a SYSTEM watchdog and re-applied if it drifts.

---

## 1. Objectives & Scope

| # | Objective | Metric (SLA) |
|---|-----------|--------------|
| 1 | Stable address (no IP churn / conflicts) | 0 × `Tcpip 4199` in 24 h |
| 2 | Reliable WLAN (no auto-recovery bounces) | ≤ 2 WLAN bounces in 24 h |
| 3 | Fast, encrypted DNS | resolve `one.one.one.one` via 1.1.1.1 ≤ 500 ms (light, no telemetry) |
| 4 | Lossless end-to-end connectivity | WAN loss ≤ 15 % (cellular ceiling), gateway ≤ 5 % |
| 5 | Predictable latency | WAN latency ≤ 1000 ms avg |

References: RFC 1122 (host), RFC 2863 (interface), RFC 6106/8484 (DNS / DoH),
RFC 3168 (ECN), ISO 9001 spirit — *plan → do → check → act* (watchdog = check/act).

## 2. Architecture

```
                        +------------------ Internet (cellular uplink "DyGs", lossy) ------------------+
                        |                                                                               |
   [NM-NET-STD-001] == enforces ==>  Wi-Fi (static 192.168.0.150, DNS DoH 1.1.1.1/8.8.8.8, NCSI off)
        |                                                                                              |
        +--- Apply-NetworkStandard.ps1   (idempotent enforcer, on drift)                               |
        +--- Network-Reliability-Watchdog.ps1 (probe SLA + config every 5 min)                         |
        +--- Event responders: Tcpip 4199 -> instant heal ; WLAN 4003 -> instant heal                 |
        +--- Reports\* : compliance JSON + health log (audit trail)                                     |
```

## 3. Enforced Baseline

- **IP policy:** static `192.168.0.150` on SSID `DyGs`; automatic DHCP fallback on any other SSID.
  *Why:* `192.168.0.100` was repeatedly claimed (`Tcpip 4199`) causing address churn, WLAN
  recovery loops, internet stalls and agent failures. Static removes the DHCP collision surface.
- **DNS:** `1.1.1.1` + `8.8.8.8` with **DoH** templates (`cloudflare-dns.com`, `dns.google`) —
  encrypted, ISP-tamper-proof, survived the earlier 5.7 s → 17 ms regression.
- **NCSI active probing:** **off.** Prevents Windows from recycling the interface every time
  the fragile uplink blips (kills the `WLAN 4003` auto-recovery loop).
- **TCP:** `autotuning=normal`, `ecn=enabled`, `timestamps=enabled`, `nonsackrttresiliency=disabled`, `initialrto=1500`.
- **Wi-Fi NIC:** power saving / EEE / U-APSD disabled; roaming aggressiveness = Highest;
  unused "Wi-Fi Direct Virtual Adapter"s disabled (smaller driver surface).
- **Services:** telemetry & consumer stack disabled (DiagTrack, WSearch, DoSvc, Wpn*,
  CDPSvc, whesvc, InventorySvc, lfsvc, RetailDemo, MapsBroker, Polybase SQLPBENGINE/SQLPBDMS);
  `MSSQLSERVER` → Manual (started on demand; the NMS repo itself uses SQLite only).
- **Internet-hungry tasks:** OneDrive / Office auto-update tasks disabled.
- **Delivery Optimization:** background ≤ 20 % (protects the small uplink).

## 4. Monitoring & Self-Healing (Check → Act)

| Trigger | Who | Action |
|---------|-----|--------|
| Config drift (IP/DNS/DoH/NCSI/services/tasks) | Watchdog (5 min) | re-run `Apply-NetworkStandard.ps1` |
| WAN loss > 15 % or DNS > 500 ms | Watchdog | `flushdns` + adapter reset once |
| `Tcpip 4199` conflict event | `NMS-NetConflict-Response` | instant watchdog run |
| `WLAN 4003` limited-connectivity event | `NMS-NetLinkRecovery-Response` | instant watchdog run |
| Sustained failure (≥ 12 consecutive failures) | Watchdog | stop auto-heal, write `Reports\NETWORK_ALERT.txt` |

Audit files: `Reports\NetworkStandard-Compliance.json`, `Reports\net-health-last.json`,
`Reports\NetworkHealth.log`.

## 5. Standard Operating Procedure (SOP)

1. **Touch nothing first:** read `Reports\net-health-last.json` + `Reports\NetworkHealth.log`
   (last 50 lines) to check whether the system is PASSing or in alert.
2. **If alert:** open `Reports\NETWORK_ALERT.txt`; it records the exact drift/SLA failures.
3. **Repair:** `powershell -File Scripts\Apply-NetworkStandard.ps1` (UAC) — idempotent,
   only touches what drifted.
4. **Re-seed tasks** (after image rebuild): `Scripts\Register-NetworkReliabilityTasks.ps1`.
5. **Validate:** `Reports\NetworkStandard-Compliance.json` reports `COMPLIANT`.
6. **Escalate to the link itself** (router/hotspot/ISP): if local config is `COMPLIANT` yet
   WAN stays > 15 % loss → reboot the "DyGs" router/hotspot, check SIM/data quota/throttling,
   move to 5 GHz or wired. This is *outside* the host standard.

## 6. Rollback / Return-To-Config-Ahead

| Changed | Restore command |
|---------|-----------------|
| Static IP | `Remove-NetIPAddress -InterfaceAlias "Wi-Fi" -Confirm:$false; Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Dhcp Enabled` |
| Services | `sc.exe config <Name> start= auto` + `Start-Service <Name>` |
| Tasks | `Enable-ScheduledTask -TaskName "OneDrive Per-Machine Standalone Update Task"` |
| NCSI | `Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet" -Name EnableActiveProbing -Value 1` |
| Untrack tasks | `Unregister-ScheduledTask -TaskName "NMS-NetHealth-Watchdog" -Confirm:$false` (+ the two event responders) |

## 7. Change Log

| Date | Change |
|------|--------|
| 2026-09-18 | Standard created; static IP 192.168.0.150; DoH; NCSI off; services/tasks/DO throttling; watchdog + event responders installed. |