/* =====================================================================
   الياس برو — النواة المشتركة (elias-core)
   أدوات جلب بيانات الشبكة، الثيم، الرسوم، التنبيهات، والتحويلات
   الموافقة لبنية تقارير المنظومة NM-NET-STD-001 • v4.4
   ===================================================================== */
(function () {
  'use strict';

  /* ---------- أدوات DOM ---------- */
  const $  = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));

  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  /* ---------- تنسيق الأرقام بتجربة عربية (أرقام غربية + نصوص عربية) ---------- */
  const numFmt = new Intl.NumberFormat('ar-EG-u-nu-latn', { maximumFractionDigits: 1 });
  const intFmt = new Intl.NumberFormat('ar-EG-u-nu-latn', { maximumFractionDigits: 0 });
  const num = (v) => Number.isFinite(+v) ? numFmt.format(+v) : '—';
  const integer = (v) => Number.isFinite(+v) ? intFmt.format(+v) : '—';
  const pct = (v) => Number.isFinite(+v) ? num(v) + '%' : '—';

  /* ---------- الوقت ---------- */
  const fixTs = (t) => String(t || '').replace(' ', 'T');
  const fmtDT = new Intl.DateTimeFormat('ar-EG-u-nu-latn',
    { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  const fmtT = new Intl.DateTimeFormat('ar-EG-u-nu-latn', { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  const ts = (iso) => { const d = new Date(fixTs(iso)); return isNaN(d) ? '—' : fmtDT.format(d); };
  const nowTime = () => fmtT.format(new Date());

  const timeAgo = (iso) => {
    const d = new Date(fixTs(iso));
    if (isNaN(d)) return '';
    const s = Math.max(0, (Date.now() - d.getTime()) / 1000);
    if (s < 60) return 'الآن';
    if (s < 3600) return 'منذ ' + Math.floor(s / 60) + ' دقيقة';
    if (s < 86400) return 'منذ ' + Math.floor(s / 3600) + ' ساعة';
    return 'منذ ' + Math.floor(s / 86400) + ' يوم';
  };

  /* ---------- جلب مع مهلة وإعادة محاولة ---------- */
  async function fetchWith(url, { timeout = 6000, retries = 2, asJson = true, signal } = {}) {
    for (let i = 0; i <= retries; i++) {
      const ac = new AbortController();
      const timer = setTimeout(() => ac.abort(), timeout);
      const sig = (signal && window.AbortSignal && AbortSignal.any)
        ? AbortSignal.any([ac.signal, signal])
        : ac.signal;
      try {
        const res = await fetch(url, { signal: sig, headers: { Accept: 'application/json' } });
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return asJson ? await res.json() : await res.text();
      } catch (e) {
        if (i === retries) throw e;
      } finally {
        clearTimeout(timer);
      }
    }
  }
  const fetchJson = (url, o) => fetchWith(url, Object.assign({ asJson: true }, o));
  const fetchText = (url, o) => fetchWith(url, Object.assign({ asJson: false }, o));

  /* مسارات التقارير عند فتح الواجهة من مجلدات مختلفة */
  const REPORT_BASES = ['../Reports', 'Reports', '/Reports'];

  async function loadReport(name) {
    for (const base of REPORT_BASES) {
      try {
        const j = await fetchJson(base + '/' + name, { timeout: 4000, retries: 0 });
        if (j) return j;
      } catch (e) { /* جرّب المسار التالي */ }
    }
    return null;
  }

  async function loadAlert(name) {
    for (const base of REPORT_BASES) {
      try {
        const txt = await fetchText(base + '/' + name, { timeout: 4000, retries: 0 });
        if (txt) {
          const out = { count: null, alerts: [] };
          for (const ln of txt.split(/\r?\n/).filter(Boolean)) {
            const m = ln.match(/^count=(\d+)$/i);
            if (m) { out.count = +m[1]; continue; }
            const a = ln.match(/^alert=(.*)$/i);
            if (a) out.alerts.push(a[1]);
          }
          return out;
        }
      } catch (e) { /* جرّب المسار التالي */ }
    }
    return null;
  }

  /* ---------- محوّلات البيانات وفق بنية التقارير ---------- */
  function netHealthModel(j) {
    if (!j || typeof j !== 'object') return null;
    return {
      ts: j.timestamp,
      ssid: j.ssid,
      ipv4: j.ipv4,
      gwLoss: +j.gatewayLossPct || 0,
      wanLoss: +j.wanLossPct || 0,
      dnsMs: +j.dnsMs || 0,
      conflicts: +j.conflicts24h || 0,
      bounces: +j.wlanBounce24h || 0,
      drift: Array.isArray(j.drift) ? j.drift : [],
      sla: Array.isArray(j.slaFailures) ? j.slaFailures : [],
      status: (j.status || 'UNKNOWN').toUpperCase()
    };
  }

  function complianceModel(j) {
    if (!j || typeof j !== 'object') return null;
    const viol = Array.isArray(j.violations) ? j.violations : [];
    return {
      ts: j.timestamp,
      standard: j.standard,
      version: j.version,
      iface: j.interface,
      ssid: j.ssid,
      ipv4: j.ipv4,
      gwOk: !!j.gatewayReachable,
      dnsMs: +j.dnsLatencyMs || 0,
      applied: Array.isArray(j.changesApplied) ? j.changesApplied : [],
      violations: viol.map(v => (typeof v === 'object' && v)
        ? (v.message || v.detail || v.name || JSON.stringify(v)) : String(v)),
      status: (j.status || 'UNKNOWN').toUpperCase()
    };
  }

  /* سطر السجل: التاريخ \t SSID \t الحالة \t الفقد \t DNS \t التعارضات \t السبب */
  function parseLogLine(line) {
    const p = String(line || '').split('\t');
    if (p.length < 6) return null;
    return {
      ts: p[0],
      ssid: p[1] || '—',
      status: p[2].toUpperCase(),
      loss: +p[3] || 0,
      dnsMs: +String(p[4] || '').replace('ms', '') || 0,
      conflicts: +p[5] || 0,
      reason: p.slice(6).join('\t').trim() || undefined
    };
  }

  function parseLog(text) {
    return String(text || '')
      .split(/\r?\n/)
      .map(parseLogLine)
      .filter(Boolean);
  }

  /* ---------- مؤشر الصحة المركّب ---------- */
  function healthScore(net, comp) {
    let s = 100;
    const gw = Math.max(0, net && net.gwLoss || 0);
    const wan = Math.max(0, net && net.wanLoss || 0);
    const dns = (net && net.dnsMs) || 0;
    const conflicts = (net && net.conflicts) || 0;
    const bounces = (net && net.bounces) || 0;
    if (gw > 0) s -= gw;
    if (dns > 60) s -= Math.min(20, (dns - 60) / 4);
    if (wan > 15) s -= wan > 50 ? 12 : 6;
    if (conflicts > 0) s -= 15 * conflicts;
    if (bounces > 5) s -= Math.min(20, (bounces - 5) * 2);
    if (comp && comp.gwOk === false) s -= 40;
    if (net && net.status === 'CONFIG_DRIFT') s -= 12;
    return Math.max(0, Math.min(100, Math.round(s)));
  }

  const toneOf = (s) => s >= 85 ? 'ok' : s >= 60 ? 'warn' : 'bad';

  const STATUS_AR = {
    PASS: 'سليم',
    LINK_DEGRADED: 'تدهور الرابط',
    CONFIG_DRIFT: 'انحراف عن المعيار',
    FAIL: 'عطل',
    COMPLIANT: 'متوافق',
    NON_COMPLIANT: 'غير متوافق',
    UNKNOWN: 'غير محدد'
  };
  const statusAr = (s) => STATUS_AR[String(s || '').toUpperCase()] || String(s || '—');

  /* ---------- الرسوم (SVG خفيف بدون مكتبات) ---------- */
  function ring(holder, value, { size = 170, stroke = 13, min = 0, max = 100 } = {}) {
    if (!holder) return 0;
    const v = Math.max(min, Math.min(max, +value || 0));
    const frac = (max - min) ? (v - min) / (max - min) : 0;
    const r = (size - stroke) / 2;
    const c = 2 * Math.PI * r;
    holder.innerHTML = '<svg viewBox="0 0 ' + size + ' ' + size + '" aria-hidden="true">'
      + '<circle cx="' + (size / 2) + '" cy="' + (size / 2) + '" r="' + r + '" fill="none" stroke="var(--ring-track)" stroke-width="' + stroke + '"/>'
      + '<circle class="ring-arc" cx="' + (size / 2) + '" cy="' + (size / 2) + '" r="' + r + '" fill="none"'
      + ' stroke="var(--arc,var(--accent))" stroke-width="' + stroke + '" stroke-linecap="round"'
      + ' stroke-dasharray="' + c.toFixed(1) + '" stroke-dashoffset="' + (c * (1 - frac)).toFixed(1) + '"'
      + ' transform="rotate(-90 ' + (size / 2) + ' ' + (size / 2) + ')"/>'
      + '</svg>';
    return frac;
  }

  function spark(holder, values, { w = 300, h = 70, min, max } = {}) {
    if (!holder) return;
    const pts = (Array.isArray(values) ? values : []).map(Number).filter(Number.isFinite);
    if (pts.length < 2) { holder.innerHTML = ''; return; }
    if (min === undefined) min = Math.min.apply(null, pts);
    if (max === undefined) max = Math.max.apply(null, pts);
    const range = (max - min) || 1;
    const pad = 6;
    const x = (i) => pad + i * (w - 2 * pad) / (pts.length - 1);
    const y = (v) => h - pad - (v - min) / range * (h - 2 * pad);
    const line = pts.map((v, i) => (i ? 'L' : 'M') + x(i).toFixed(1) + ',' + y(v).toFixed(1)).join(' ');
    const area = line + ' L' + x(pts.length - 1).toFixed(1) + ',' + (h - pad) + ' L' + pad + ',' + (h - pad) + ' Z';
    holder.innerHTML = '<svg viewBox="0 0 ' + w + ' ' + h + '" preserveAspectRatio="none" style="width:100%;height:' + h + 'px;display:block;direction:ltr">'
      + '<path d="' + area + '" fill="var(--spark-fill,rgba(0,102,255,.14))" stroke="none"/>'
      + '<path d="' + line + '" fill="none" stroke="var(--spark-stroke,var(--accent))" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
      + '</svg>';
  }

  /* ---------- التوست ---------- */
  function toast(msg, type, ms) {
    type = type || 'info';
    const box = $('#toasts');
    if (!box) return;
    const t = document.createElement('div');
    t.className = 'toast ' + type;
    const ic = type === 'ok' ? '✅' : type === 'warn' ? '⚠️' : type === 'bad' ? '⛔' : '💡';
    t.innerHTML = '<span style="flex:none">' + ic + '</span><div style="flex:1;min-width:0">' + esc(msg) + '</div>';
    box.appendChild(t);
    while (box.children.length > 5) box.firstChild.remove();
    setTimeout(() => {
      t.style.transition = 'opacity .3s, transform .3s';
      t.style.opacity = '0';
      t.style.transform = 'translateY(10px)';
      setTimeout(() => t.remove(), 320);
    }, ms || 4200);
  }

  /* ---------- تنزيل / نسخ ---------- */
  function download(filename, text, mime) {
    mime = mime || 'application/json';
    const blob = new Blob([text], { type: mime + ';charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 400);
  }

  async function copyText(text) {
    try { await navigator.clipboard.writeText(text); return true; }
    catch (e) { return false; }
  }

  /* ---------- الثيم ---------- */
  const theme = {
    key: 'elias-theme',
    saved() { try { return localStorage.getItem(this.key); } catch (e) { return null; } },
    get() { return document.documentElement.getAttribute('data-theme'); },
    set(t) {
      if (t === 'auto' || !t) document.documentElement.removeAttribute('data-theme');
      else document.documentElement.setAttribute('data-theme', t);
      try { localStorage.setItem(this.key, t || 'auto'); } catch (e) { }
      return this.get();
    },
    toggle() {
      const cur = this.get();
      return this.set(cur === 'dark' ? 'light' : 'dark');
    },
    init() {
      const s = this.saved();
      if (s === 'dark' || s === 'light') { this.set(s); return; }
      const mq = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)');
      const apply = () => document.documentElement.setAttribute('data-theme', mq.matches ? 'dark' : 'light');
      apply();
      if (mq && mq.addEventListener) mq.addEventListener('change', apply);
    }
  };

  window.Elias = {
    $, $$, esc,
    num, integer, pct,
    ts, nowTime, timeAgo,
    fetchJson, fetchText, loadReport, loadAlert,
    netHealthModel, complianceModel, parseLogLine, parseLog,
    healthScore, toneOf, statusAr,
    ring, spark,
    toast, download, copyText,
    theme
  };
})();