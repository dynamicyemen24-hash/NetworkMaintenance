# الياس برو | Elias Pro v5.0.0 — Universal Maintenance Suite

<div align="center">
<img src="Branding/banner.png" alt="Elias Pro Banner" width="800"/>

**FixMaster Technology — Professional Edition**

*صيانة فنية خالصة — Maintenance Only — للشبكات والموبايل والكمبيوتر والإلكترونيات*

[![Version](https://img.shields.io/badge/version-5.0.0-blue)]() [![Engines](https://img.shields.io/badge/engines-32-success)]() [![Open Source](https://img.shields.io/badge/open%20source-18%20projects-orange)]() [![License](https://img.shields.io/badge/license-Proprietary-red)]()
</div>

---

## 📦 التنزيل والتثبيت المعياري

### الطريقة 1: المثبت التلقائي (موصى به)
```powershell
# PowerShell كمسؤول (Administrator)
irm https://raw.githubusercontent.com/anomalyco/opencode/main/install.ps1 | iex
# أو محلياً:
powershell -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Dist\install.ps1"
```

### الطريقة 2: ZIP مباشر
1. حمّل `Elias-Pro-v5.0.0.zip` من `Dist/` أو من صفحة الإصدارات
2. فك الضغط إلى `C:\EliasPro` (أو `C:\NetworkMaintenance` للتوافق)
3. شغّل `Start.bat` كمسؤول

### الطريقة 3: winget / choco (قريباً)
```powershell
winget install FixMaster.EliasPro
choco install Elias-Pro
```

### المتطلبات
- Windows 10 1809+ / Windows 11
- PowerShell 5.1+
- 4GB RAM (8GB مستحسن) / 500MB مساحة
- صلاحيات Administrator للتشخيص الكامل

---

## 🚀 التشغيل السريع

```powershell
# القائمة التفاعلية
.\Start.bat

# أو مباشر:
.\Run.ps1 full              # صيانة كاملة (IT + Shop)
.\Run.ps1 shop              # ورشة الصيانة فقط
.\Run.ps1 diagnostics       # تشخيص الشبكة
.\Run.ps1 clean -DryRun     # تنظيف آمن (معاينة)
.\Scripts\Engines\HDR-Engine.ps1 -DeviceType Auto
.\Scripts\Engines\BATT-Engine.ps1 -DeviceType Auto
.\Scripts\Engines\STORAGE-Engine.ps1 -Benchmark
.\Scripts\Tools\OpenSourceToolkit.ps1 -InstallGuide

# Dashboard
start Dashboard\shop.html    # واجهة المحل (عربي)
start Dashboard\index.html   # شبكة IT

# API
.\API\Server.ps1 -Port 8080  # http://127.0.0.1:8080/api/v1/shop/stats
```

---

## 🔧 المحركات (29)

| الفئة | المحركات | الوصف |
|---|---|---|
| **شبكات IT** | DAX, OCE, HEAL, PREDICT, NET | تشخيص إحصائي/Bayesian/ML + تحسين TCP + تنبؤ ARIMA/LSTM |
| **صيانة النظام** | SCE | تنظيف آمن Whitelist (لا إعادة تحميل) |
| **تشخيص الهاردوير** | HDR, BATT, STORAGE, STRESS, NETDIAG, RECOVERY, HWD | بطارية/powercfg، تخزين SMART/smartctl، ضغط CPU/RAM، شبكة iperf3/mtr، استعادة TestDisk |
| **ورشة** | REPAIR, CRM, PARTS | تذاكر `TKT-*`، عملاء، مخزون `SKU-*` باركود EAN13 |
| **مؤسسي** | AST, MDM, IOT, FW, DR, CICD, ML, RPT, STR, XPL | أصول، موبايل، إنترنت أشياء، فيرموير، نسخ احتياطي |

**مفتوح المصدر:** smartctl, ADB, scrcpy, libimobiledevice, OpenHardwareMonitor, CrystalDiskInfo, memtest86+, stress-ng, iperf3, nmap, Wireshark, WinMTR, BleachBit, TestDisk...

---

## 📊 لوحات التحكم

- `Dashboard/app.html` — 🗂️ **غرفة تحكم الصيانة** (Command Center): نظرة عامة، صحة الشبكة، مطابقة المعيار، سجل الحارس، إجراءات الصيانة + PWA كامل بواجهة عربية RTL (نقطة بدء `manifest.json`).
- `Dashboard/index.html` — صفحة العميل (طلب صيانة + تتبع) مع رابط دخول الغرفة.
- `Dashboard/tech/shop.html` — POS ورشة (تبويبات، باركود EAN13، عربي RTL، إيصال حراري).
- `Dashboard/tech/index-pro.html` — لوحة Tabler للمشغلين.

### 🗂️ غرفة تحكم الصيانة (Dashboard/app.html)

- **نظام تصميم موحّد عربي RTL** بلا اعتماد خارجي: `Dashboard/assets/css/elias-core.css` (توكينز ألوان، ثيم ليلي/نهاري تلقائي + تبديل يدوي، تخطيطات، مؤشرات، جداول، تنبيهات، توست، هيكل تحميل، استجابة جوال وأدوات وصول AA).
- **نواة مشتركة** `Dashboard/assets/js/elias-core.js`: جلب بمهلة/إعادة محاولة، محوّلات بنية تقارير المنظومة، مقاييس SVG خفيفة (حلقة + منحنى) بلا مكتبات، نسخ/تنزيل تقارير، تنسيق عربي.
- **مصادر البيانات الحية** (محلية بدون API): `Reports/net-health-last.json` و`NetworkStandard-Compliance.json` و`NetworkHealth.log` مع تنبيهات `NETWORK_(WAN_)?ALERT.txt`، وتحديث تلقائي كل 60 ثانية + زر تحديث يدوي، وتغذية مزدوجة من `/api/v1/health` عند توفر خادم Pode.
- **PWA**: `manifest.json` سليم الترميز (عربية + RTL + اختصارات) و`service-worker.js` v4.8.0 (شلًّا دون اتصال، تخزين مداول للتقارير ولقطات التشخيص، إشعارات مُجهزة).

### 🩺 التشخيص العميق (Dashboard/deep.html)

وحدة تشخيص حقيقي للكمبيوتر والموبايل بذكاء محلل، بلا اعتماد على خادم:

- **محرك التوليد** `Scripts/Device-DeepDiagnostics.ps1`: ينفذ لقطة عبر `API/Modules/Device-Diagnostics.ps1` (WMI/SMART/`powercfg /batteryreport`/adb) إلى `Reports/device-snapshot.json` + `Data/device-history.json` (سجل 120 نقطة).
  - `powershell -ExecutionPolicy Bypass -File Scripts\Device-DeepDiagnostics.ps1` — لقطة فورية.
  - أضف `-Schedule` لجدولة لقطة كل 30 دقيقة بصلاحية SYSTEM (مهمة `NMS-DeviceSnapshot`).
- **الصلاحيات الواقعية**: صحة البطارية عبر تقرير powercfg الأصلي بدون إدارة (قيم حقيقية: سعة تصميمية/كاملة/نسبة الصحة)، بينما عدادات SMART الحساسة تُرجع `null` في الجلسة غير الإدارية وتُعرض "يتطلب إداريًا".
- **المحلل الذكي** `Dashboard/assets/js/elias-cog.js`: نقاط لكل نظام فرعي (شبكة/تخزين/بطارية/معالج/ذاكرة) بترجيح، نتائج وإجراءات عربية، تنبؤ بانحدار خطي (slope/r² + 8 توقعات)، تنعيم EMA، وكشف شذوذ z-score.
- **الرسوم**: Chart.js مستضاف محليًا (`assets/vendor/chart.umd.min.js`) مع سقوط تلقائي لمنحنى SVG خفيف عند تعذر تحميله.
- **الأقسام**: فحص شامل (حلقة + نتائج)، عتاد الكمبيوتر (حقائق WMI + بطارية + أقراص SMART + أهم العمليات بقياس عيّنتين)، موبايل Android (adb: الطراز/البطارية/الحرارة/التخزين + دليل تثبيت)، التطور والتنبؤ (رسوم + سجل + تصدير).
- **التشغيل**: صفحة مستقلة عبر فتح `deep.html` مباشرة أو من `app.html` → رابط "التشخيص العميق"؛ Pode اختياري (مسارات `/api/v1/device/*` معدة مسبقًا في `API/Server-Pode.ps1`).
- التشغيل: افتح `http://localhost:8080/Dashboard/app.html` (عبر خادم Pode) أو بفتح الملف مباشرة — تهبط الأرقام بأناقة عند غياب التقارير.

### 🚀 الاستكشاف الذاتي المنهجي (قسم "جهازك الآن")

- **المستكشف الذاتي** `Dashboard/assets/js/elias-probe.js`: منهجية معيارية عالمية ELIAS-P-2026 (مستوحاة من بروفايلات الطب الشرعي NIST 800-183) — يستكشف ذاتيًا الجهاز/الموبايل الذي تُفتح به الصفحة بلا أي تثبيت: 8 فئات (الجهاز، الشاشة، الهاردوير، الطاقة، الشبكة، الأداء، الوسائط، التخزين) مع نسبة تغطية، درجة استكشاف، بصمة جهاز FNV-1a (مشاركة للمقارنة بين الخبراء)، كشف GPU عبر WebGL، تقدير refresh rate، microbench للمعالج، بطارية عبر `getBattery`، حالة الشبكة عبر `navigator.connection`، أجهزة طرفية، مستشعرات، وحصة التخزين.
- النتائج: حلقة درجة الاستكشاف + KPI (التغطية/البصمة/رابط المشاركة) + مصفوفة تغطية لكل فئة + نتائج وإجراءات عربية + أزرار (إعادة الفحص/نسخ الرابط/تصدير JSON/طباعة).

---

## 🌐 النشر للعملاء

### الرابط العام (Production)
- **الإصدار الاحترافي v5.0.0 منشورًا**: `https://elias-pro.vercel.app`
  - التشخيص العميق + الاستكشاف الذاتي: `https://elias-pro.vercel.app/deep.html`
  - غرفة التحكم: `https://elias-pro.vercel.app/app.html`
- شارك الرابط مع أي عميل أينما كان — القسم "جهازك الآن" يعمل فورًا من الجوال أو الكمبيوتر بلا تثبيت (عربية RTL).
- ملاحظة: لقطات التشخيص المحلية (powershell/adb) تظهر بالأرقام الكاملة عند فتح الرابط داخليًا أو عبر خادم المشاركة المحلي.

### المشاركة الداخلية (LAN)
``` powershell
powershell -ExecutionPolicy Bypass -File Share\Publish-Dashboard.ps1
# ثم شارك: http://<your-lan-ip>:8081/Dashboard/deep.html
```
- خادم مشاركة خالص بلا اعتماد (TcpListener): منفذ 8081، قوائم URLs تلقائية، `-Firewall` لسبق قاعدة UAC.
- أو من `Start.bat` → الخيار [14] "Publish Customer Link".

### حزمة التوزيع
- `Dist/Elias-Pro-v5.0.0.zip` + مجموع التحقق `Dist/SHA256SUMS-500`.

---

## 🔐 الأمان

Zero-Trust | AES-256-GCM | TLS 1.3 | ITIL v4 | ISO 27001 | RBAC | Audit Log

---

## 📦 الحزمة الإنتاجية

```
Dist/Elias-Pro-v5.0.0.zip
├── Branding/icon.ico + logo.png + banner.png
├── VERSION + manifest.json + SHA256SUMS
├── install.ps1 + uninstall.ps1
├── Start.bat + Run.ps1 + Enterprise-Main.ps1
├── Scripts/Engines/ (29)
├── Scripts/Tools/OpenSourceToolkit.ps1
├── Dashboard/shop.html
└── Data/repair_shop_schema.sql
```

---

## 🔗 معيار الموثوقية الذاتي (NM-NET-STD-001)

منظومة شبكة معيارية ذاتية الشفاء لكل جهاز (SysAdmin / Zero-Touch):

- **المعيار:** `Config/network-standard.json` — IP ثابت خالٍ من التعارض + DNS-Over-HTTPS + NCSI-off + حالة الخدمات + حدود Delivery Optimization.
- **التطبيق:** `Scripts/Apply-NetworkStandard.ps1` (Idempotent) → `Reports/NetworkStandard-Compliance.json`.
- **الحراسة الذاتية:** `Scripts/Network-Reliability-Watchdog.ps1` يفحص كل 5 دقائق + عند الحدث (تعارض IP 4199 / إنعاش الرابط 4003) كـ SYSTEM، ويصلح الانحراف تلقائيًا.
- **المراقبة:** `Reports/net-health-last.json` + `Reports/NetworkHealth.log` + تنبيهات `Reports/NETWORK_WAN_ALERT.txt`.
- **التوثيق والاسترجاع:** `Docs/Network-Standard.md` (SOP + Rollback).
- التشغيل: `Scripts/Register-NetworkReliabilityTasks.ps1` — إعادة تشغيل سريع: `Scripts/Bootstrap-NetworkStandard.ps1`.

---

## 🆘 الدعم

- الوثائق: `README.md` + `Runbooks/EnterpriseRunbook.md`
- المشاكل: https://github.com/anomalyco/opencode/issues
- الإصدار: `VERSION` — Build 20260919

---

*FixMaster Technology — الياس برو v5.0.0 Professional Edition*

