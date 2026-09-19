/* =====================================================================
   الياس برو — المحلل الذكي (elias-cog) v4.4
   محرك تقييم أنظمة فرعية + توليد نتائج/إجراءات عربية +
   تنبؤ خطي/EMA + كشف شذوذ (z-score) — يعمل محليًا بالكامل
   ===================================================================== */
(function () {
  'use strict';

  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
  const valid = (v) => v !== null && v !== undefined && Number.isFinite(+v);

  /* ---------- الشبكة ---------- */
  function networkScore(net) {
    if (!net || net.present === false && !net.dns_ms) return { score: null, findings: [] };
    let s = 100;
    const f = [];
    const gw = +net.gw_loss || 0;
    const wan = +net.wan_loss || 0;
    const dns = +net.dns_ms || 0;
    const conflicts = +net.conflicts || 0;
    const bounces = +net.bounces || 0;

    if (gw > 0) {
      s -= Math.min(40, gw);
      f.push({ sev: gw > 40 ? 'high' : 'medium', text: 'فقدان حزم نحو البوابة ' + gw + '%', action: 'تحقق من كابل/قناة Wi-Fi وتعطل مسار 192.168.0.1' });
    }
    if (dns > 60) {
      s -= Math.min(20, (dns - 60) / 4);
      f.push({ sev: dns > 200 ? 'high' : 'low', text: 'زمن استعلام DNS ' + dns + 'ms', action: 'راجع DNS-Over-HTTPS ضمن المعيار NM-NET-STD-001' });
    }
    if (wan > 25) {
      s -= Math.min(15, (wan - 25) / 6);
      f.push({ sev: 'medium', text: 'تذبذب الواجهة العامة WAN ' + wan + '%', action: 'اضطراب من جهة المزوّد — لا تحرك إعدادات الجهاز؛ ارصد عبر الحارس' });
    }
    if (conflicts > 0) {
      s -= Math.min(45, conflicts * 15);
      f.push({ sev: 'high', text: 'تعارض عنوان IP (' + conflicts + ' حدث خلال 24 ساعة)', action: 'ثبّت العنوان الثابت 192.168.0.150 وأزل جهاز المتعارض على الشبكة' });
    }
    if (bounces > 5) {
      s -= Math.min(10, (bounces - 5) * 2);
      f.push({ sev: 'low', text: bounces + ' انقطاع WLAN خلال 24 ساعة', action: 'تحقق من ضبط نقطة الوصول DyGs (تحميل/تداخل قنوات)' });
    }
    return { score: clamp(Math.round(s), 0, 100), findings: f };
  }

  /* ---------- البطارية ---------- */
  function batteryScore(bat) {
    if (!bat || bat.present === false) return { score: null, findings: [] };
    const h = valid(bat.health_pct) ? +bat.health_pct : null;
    const f = [];
    if (h === null) f.push({ sev: 'low', text: 'صحة الشحن غير متاحة لهذا الجهاز', action: 'قارن السعة الفعلية بالتصميمية عبر إعدادات Windows' });
    if (valid(h)) {
      if (h < 50) f.push({ sev: 'high', text: 'البطارية تدهورت إلى ' + h + '% من السعة التصميمية', action: 'استبدال البطارية واستخدام الأصلية' });
      else if (h < 70) f.push({ sev: 'medium', text: 'صحة البطارية ' + h + '% — ضمن مرحلة التقدم في العمر', action: 'قلّل دورات الشحن المتكررة، وتجنّب التفريغ العميق، وتوقّع الاستبدال قريبًا' });
    }
    if (valid(bat.level_pct) && +bat.level_pct < 20) f.push({ sev: 'low', text: 'شحن منخفض (' + bat.level_pct + '%)', action: 'أعد الشحن واستخدم وضع السير' });
    if (valid(bat.temp_c) && +bat.temp_c > 45) f.push({ sev: 'high', text: 'حرارة حجر البطارية ' + bat.temp_c + '°C', action: 'أوقف الشحن حتى تبرد — خطر تضخم/تلف' });
    return { score: valid(h) ? clamp(Math.round(h), 0, 100) : null, findings: f };
  }

  /* ---------- التخزين ---------- */
  function storageScore(disks) {
    const list = (Array.isArray(disks) ? disks : (disks ? [disks] : [])).filter(Boolean);
    if (!list.length) return { score: null, findings: [], max_wear: null, unhealthy: 0 };
    let worst = 0;
    let unhealthy = 0;
    for (const d of list) {
      if (valid(d.wear_pct)) worst = Math.max(worst, +d.wear_pct);
      if (d.health && d.health !== 'Healthy' && d.health !== 'OK') unhealthy++;
    }
    const f = [];
    if (unhealthy > 0) {
      f.push({ sev: 'high', text: unhealthy + ' قرص لم يعد سليمًا ("' + list.find(d => d.health && d.health !== 'Healthy' && d.health !== 'OK').health + '")', action: 'انسخ احتياطيًا فوريًا واستبدل القرص' });
    }
    if (worst >= 90) f.push({ sev: 'high', text: 'اهتراء قرص ' + worst + '% — قرب نهاية العمر', action: 'استبدال + نسخ احتياطي قبل الفقد' });
    else if (worst >= 70) f.push({ sev: 'medium', text: 'اهتراء قرص ' + worst + '%', action: 'راقب الحالة بانتظام وجهّز استبدالًا مسبقًا' });
    const base = unhealthy > 0 ? 15 : worst;
    return { score: clamp(Math.round(100 - base), 0, 100), findings: f, max_wear: worst, unhealthy: unhealthy };
  }

  /* ---------- المعالج ---------- */
  function cpuScore(device, thermal) {
    const load = valid(device && device.cpu_load) ? +device.cpu_load : null;
    const temp = thermal && thermal.summary;
    const f = [];
    let s = 100;
    if (valid(load)) {
      if (load > 85) { s -= clamp((load - 85) * 1.6, 5, 30); f.push({ sev: 'high', text: 'حمل المعالج عالٍ ' + load + '%', action: 'راجع العمليات الأكثر استهلاكًا وأغلق ما لا يلزم' }); }
      else if (load > 60) { s -= clamp((load - 60), 0, 15); f.push({ sev: 'medium', text: 'حمل معالجة مرتفع ' + load + '%', action: 'راقب DPC/فيروسات أو مهام خلفية' }); }
    }
    if (valid(temp)) {
      if (temp > 90) { s -= clamp((temp - 90) * 2, 10, 30); f.push({ sev: 'high', text: 'درجة وحدة المعالجة ' + temp + '°C', action: 'تنظيف المروحة ومزيل الحرارة وإعادة معجون حراري' }); }
      else if (temp > 80) { s -= 10; f.push({ sev: 'medium', text: 'حرارة ' + temp + '°C', action: 'تحقق من دخول أبواب التهوية وتجفيف المعجون' }); }
    } else if (valid(load)) {
      f.push({ sev: 'low', text: 'حرارة المعالج غير معروضة عبر ACPI لهذا الجهاز', action: 'استخدم أداة مراقبة حرارية خارجية عند الحمولة العالية' });
    }
    return { score: valid(load) ? clamp(Math.round(s), 0, 100) : null, findings: f };
  }

  /* ---------- الذاكرة ---------- */
  function ramScore(device) {
    const p = valid(device && device.used_ram_pct) ? +device.used_ram_pct : null;
    if (p === null) return { score: null, findings: [] };
    const f = [];
    if (p > 90) f.push({ sev: 'high', text: 'استهلاك الذاكرة ' + p + '%', action: 'أغلق التطبيقات الثقيلة أو رقّ الذاكرة لتجنب التبادل' });
    else if (p > 75) f.push({ sev: 'medium', text: 'ضغط ذاكرة ' + p + '%', action: 'راجع الجلسات المفتوحة وتطبيقات الخلفية' });
    return { score: clamp(Math.round(100 - p), 0, 100), findings: f };
  }

  /* ---------- التجميع ---------- */
  function evaluate(snap) {
    const dev = snap && snap.device;
    const net = snap && snap.network;
    const bat = snap && snap.battery;
    const disks = snap && snap.storage;
    const th = snap && snap.thermal;
    if (!dev) return { overall: null, subs: {}, findings: [], computed: false };

    const n = networkScore(net);
    const b = batteryScore(bat);
    const s = storageScore(disks);
    const c = cpuScore(dev, th);
    const r = ramScore(dev);

    const subs = {
      network: n.score, battery: b.score, storage: s.score, cpu: c.score, ram: r.score
    };

    const weights = { network: 0.22, storage: 0.25, battery: 0.18, cpu: 0.15, ram: 0.20 };
    let wsum = 0, acc = 0;
    for (const k of Object.keys(weights)) {
      if (valid(subs[k])) { acc += subs[k] * weights[k]; wsum += weights[k]; }
    }
    const overall = wsum ? Math.round(acc / wsum) : null;

    const findings = [
      ...n.findings.map(x => Object.assign({ area: 'network' }, x)),
      ...s.findings.map(x => Object.assign({ area: 'storage' }, x)),
      ...b.findings.map(x => Object.assign({ area: 'battery' }, x)),
      ...c.findings.map(x => Object.assign({ area: 'cpu' }, x)),
      ...r.findings.map(x => Object.assign({ area: 'ram' }, x))
    ];
    findings.sort((a, b) => (b.sev === 'high' ? 2 : b.sev === 'medium' ? 1 : 0) - (a.sev === 'high' ? 2 : a.sev === 'medium' ? 1 : 0));

    return { overall, subs, findings, computed: true };
  }

  /* ---------- التنبؤ (انحدار خطي + EMA) ---------- */
  function trend(series, horizon) {
    horizon = horizon || 8;
    const x = series.map((v, i) => i);
    const y = series.slice();
    const n = y.length;
    if (n < 3) return { enough: false, last: y.length ? y[y.length - 1] : null, forecast: [], anomalies: [] };

    const mx = x.reduce((a, b) => a + b, 0) / n;
    const my = y.reduce((a, b) => a + b, 0) / n;
    let sxy = 0, sxx = 0, dss = 0;
    for (let i = 0; i < n; i++) {
      sxy += (x[i] - mx) * (y[i] - my);
      sxx += (x[i] - mx) * (x[i] - mx);
      dss += (y[i] - my) * (y[i] - my);
    }
    const slope = sxx ? sxy / sxx : 0;
    const intercept = my - slope * mx;
    const sse = dss - (sxx ? (sxy * sxy) / sxx : 0);
    const r2 = dss ? clamp(1 - sse / dss, 0, 1) : 1;

    // تنعيم EMA للتصوير
    const alpha = 0.35;
    const ema = [];
    let prev = y[0];
    y.forEach((v, i) => { prev = alpha * v + (1 - alpha) * prev; ema.push(prev); });

    // شذوذ z-score على البقايا
    const resid = y.map((v, i) => v - (intercept + slope * i));
    const rm = resid.reduce((a, b) => a + b, 0) / n;
    const rstd = Math.sqrt(resid.reduce((a, b) => a + (b - rm) * (b - rm), 0) / n) || 1;
    const anomalies = [];
    resid.forEach((v, i) => {
      const z = (v - rm) / rstd;
      if (Math.abs(z) > 2.5) anomalies.push({ i, z: +z.toFixed(2), value: y[i] });
    });

    const forecast = [];
    for (let h = 1; h <= horizon; h++) {
      const v = intercept + slope * (n - 1 + h);
      forecast.push(Math.round(clamp(v, 0, 100000) * 10) / 10);
    }

    return { enough: true, slope: +slope.toFixed(3), intercept: +intercept.toFixed(1), r2: +r2.toFixed(2), last: y[y.length - 1], mean: +my.toFixed(1), std: +Math.sqrt(dss / n).toFixed(2), ema, forecast, anomalies };
  }

  /* ---------- التسميات العربية ---------- */
  /* ---------- تقييم استكشاف الجهاز الحالي (probe) ---------- */
  const FF_AR = { mobile: 'هاتف ذكي', tablet: 'جهاز لوحي', desktop: 'حاسوب مكتبي' };

  function probeScore(probe) {
    if (!probe || typeof probe.score !== 'number') return { score: null, coverage: 0, level: '—', findings: [], profile: '—', fingerprint: null };
    const f = [];
    const p = probe;
    const ff = FF_AR[p.client && p.client.formFactor] || 'جهاز';
    let memLabel = 'غير محدد';
    if (p.hardware.deviceMemory) memLabel = p.hardware.deviceMemory >= 8 ? p.hardware.deviceMemory + 'GB' : (p.hardware.deviceMemory < 4 ? p.hardware.deviceMemory + 'GB (محدود)' : p.hardware.deviceMemory + 'GB');

    if (p.power) {
      if (p.power.level !== null && p.power.level < 20) f.push({ sev: 'medium', area: 'power', text: 'طاقة الجهاز منخفضة (' + p.power.level + '%)', action: 'اشحن الجهاز قبل عمليات التشخيص الطويلة أو فعّل توفير الطاقة' });
      if (p.power.level !== null && p.power.level <= 100 && p.power.level >= 97 && !p.power.charging) { /* لا ملاحظة */ }
    }
    if (p.network) {
      const et = p.network.effectiveType;
      const dl = p.network.downlinkMbps;
      if (et && (et === '2g' || et === '3g' || (dl !== null && dl < 2))) f.push({ sev: 'medium', area: 'network', text: 'اتصال شبكة محدود (' + (et || ('~' + dl + 'Mbps')) + ')', action: 'استخدم Wi-Fi ثابتًا لفحوصات أثقل أو تحميل التطبيقات' });
      if (p.network.saveData) f.push({ sev: 'low', area: 'network', text: 'وضع توفير البيانات مفعل', action: 'قد تُرجَّأ التحديثات الخلفية — عطّل save-data إن أردت دقة أعلى' });
    }
    if (p.hardware.deviceMemory && p.hardware.deviceMemory < 4) f.push({ sev: 'medium', area: 'hardware', text: 'ذاكرة الجهاز محدودة (' + p.hardware.deviceMemory + 'GB)', action: 'أغلق التطبيقات الخلفية قبل الفحوصات الثقيلة' });
    if (p.storage && p.storage.usedPct !== null && p.storage.usedPct > 85) f.push({ sev: 'high', area: 'storage', text: 'مساحة تخزين المتصفح ممتلئة تقريبًا (' + p.storage.usedPct + '%)', action: 'نظّف بيانات الموقع/المتصفح لتحسين الاستقرار' });
    if (p.performance && p.performance.cpuBench && p.performance.cpuBench.opsPerMs && p.performance.cpuBench.opsPerMs < 90000) f.push({ sev: 'low', area: 'performance', text: 'أداء معالج مقاس تقريبيًا ضمن النطاق العادي البطيء', action: 'تفقد العمليات الثقيلة على الجهاز قبل الاختبارات' });
    if (!p.hardware.webgl) f.push({ sev: 'low', area: 'hardware', text: 'تسريع WebGL معطّل أو غير متاح', action: 'فعّل التسريع في إعدادات المتصفح للحصول على بيانات GPU' });

    const profile = ff + ' · ' + (p.client.os || '—') + ' · ذاكرة ' + memLabel + ' · ' +
      (p.hardware.concurrency ? 'متعدد الأنوية ' + p.hardware.concurrency + ' خيط' : '') + ' · ' +
      (p.hardware.gpu && p.hardware.gpu.renderer ? (p.hardware.gpu.type + ' / ' + p.hardware.gpu.renderer.slice(0, 46)) : 'GPU غير مكشوف');
    return {
      score: p.score,
      coverage: p.coveragePct,
      level: p.level,
      findings: f,
      profile: profile.replace(/\s+/g, ' '),
      fingerprint: p.fingerprint,
      categories: p.coverage || {},
      method: p.method
    };
  }

  const AREAS = { network: 'الشبكة', storage: 'التخزين', battery: 'البطارية', cpu: 'المعالج', ram: 'الذاكرة', power: 'الطاقة', hardware: 'العتاد', performance: 'الأداء' };
  const SEV = { high: 'حرج', medium: 'انتباه', low: 'ملاحظة' };

  window.EliasCog = { evaluate, trend, probeScore, networkScore, batteryScore, storageScore, cpuScore, ramScore, AREAS, SEV, FF_AR };
})();