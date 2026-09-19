/* =====================================================================
   الياس برو v4.8 — المستكشف الذاتي (elias-probe)
   فحص منهجي للجهاز الذي يُشغَّل على صفحة الويب (PC/موبايل/تابلت)
   بمنهجية معيارية عالمية (شبيهة بمنهجية NIST للفحص البيئي):
   الفئات: الجهاز/الشاشة/العتاد/الطاقة/الشبكة/الأداء/الوسائط/المستشعرات/التخزين
   المخرجات: مصفوفة كشف {يكتشف/لا} + تغطية % + درجة استكشاف + بصمة جهاز مستقرة
   ===================================================================== */
(function () {
  'use strict';

  function esc(v) { return (v === null || v === undefined) ? null : v; }

  function detectFormFactor() {
    const ua = navigator.userAgent || '';
    const isMobileUA = /Mobi|Android/i.test(ua) && !/iPad|Tablet/i.test(ua);
    const isTablet = /iPad|Tablet/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const maxTouch = (navigator.maxTouchPoints || 0);
    let ff;
    if (isTablet) ff = 'tablet';
    else if (isMobileUA || (maxTouch > 1 && /Mobi/i.test(ua)) || (window.innerWidth <= 480 && maxTouch > 1 && window.matchMedia('(pointer: coarse)').matches)) ff = 'mobile';
    else if (maxTouch > 1 && window.matchMedia('(pointer: coarse)').matches && window.innerWidth <= 1024) ff = 'tablet';
    else ff = 'desktop';
    return { value: ff, touch: maxTouch, tactile: window.matchMedia('(pointer: coarse)').matches, hasFinePointer: window.matchMedia('(any-pointer: fine)').matches };
  }

  function guessOS(ua, platform) {
    const p = (platform || '').toLowerCase();
    const s = (ua || '');
    if (/windows nt|win32|win64/i.test(s) || p.indexOf('win') === 0) return 'windows';
    if (/android/i.test(s)) return 'android';
    if (/(iphone|ipad|ipod)/i.test(s)) return /iPad/i.test(s) ? 'ipados' : 'ios';
    if (/mac os x|macintosh/i.test(s)) return 'macos';
    if (/crkey|linux/i.test(s)) return 'chromebook';
    if (/linux/i.test(s)) return 'linux';
    if (/x11/i.test(s)) return 'unix';
    return 'غير معروف';
  }

  function guessBrowser(ua) {
    const s = (ua || '');
    if (/edg\//i.test(s)) return 'Microsoft Edge';
    if (/opr\//i.test(s) || /opera/i.test(s)) return 'Opera';
    if (/firefox\//i.test(s)) return 'Firefox';
    if (/chrome|chromium|crios/i.test(s)) return 'Chrome/Chromium';
    if (/safari\//i.test(s)) return 'Safari';
    if (/samsungbrowser/i.test(s)) return 'Samsung Internet';
    return 'غير معروف';
  }

  function webglInfo() {
    try {
      const c = document.createElement('canvas');
      const gl = c.getContext('webgl2') || c.getContext('webgl') || c.getContext('experimental-webgl');
      if (!gl) return { ok: false };
      const dbg = gl.getExtension('WEBGL_debug_renderer_info');
      const renderer = dbg ? String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) || '') : String(gl.getParameter(gl.RENDERER) || '');
      const vendorRaw = (gl.getParameter(gl.VENDOR) || '');
      let type = 'مجهول';
      const r = renderer.toLowerCase();
      if (/nvidia|geforce|quadro|tesla/i.test(r)) type = 'NVIDIA';
      else if (/amd|radeon|rx /i.test(r)) type = 'AMD/ATI';
      else if (/intel|uhd|iris/i.test(r)) type = 'Intel';
      else if (/mali|adreno|powervr/i.test(r)) type = 'وحدة رسوميات هواتف';
      else if (/apple|apple_gpu|metal/i.test(r)) type = 'Apple';
      return {
        ok: true,
        api: gl.getParameter(gl.VERSION) || null,
        renderer: renderer || null,
        vendor: String(vendorRaw) || null,
        type
      };
    } catch (e) { return { ok: false }; }
  }

  function approximateCpuSpeed() {
    try {
      const start = performance.now();
      let x = 0;
      while (performance.now() - start < 45) { for (let i = 0; i < 1e5; i++) { x = (x + i) & 0xffff; } }
      const ops = Math.round((100000 * 45) / Math.max(1, performance.now() - start));
      return { opsPerMs: ops, label: ops >= 300000 ? 'عالٍ' : ops >= 150000 ? 'متوسط' : 'عادي' };
    } catch (e) { return { opsPerMs: null, label: null }; }
  }

  function estimateRefreshRate(ms) {
    return new Promise((res) => {
      try {
        if (window.matchMedia && window.matchMedia('(display-refresh-rate: 120hz)').matches) return res(120);
        if (window.matchMedia && window.matchMedia('(display-refresh-rate: 90hz)').matches) return res(90);
        let frames = 0;
        const t0 = performance.now();
        function tick() {
          frames++;
          if (performance.now() - t0 < (ms || 500)) requestAnimationFrame(tick);
          else res(Math.round(frames * 1000 / (performance.now() - t0)));
        }
        requestAnimationFrame(tick);
        setTimeout(() => res(null), (ms || 500) + 120);
      } catch (e) { res(null); }
    });
  }

  function stableHash(obj) {
    let h = 0x811c9dc5;
    const s = JSON.stringify(obj);
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = (h * 0x01000193) >>> 0;
    }
    return ('00000000' + h.toString(16)).slice(-8).toUpperCase();
  }

  async function highEntropy() {
    try {
      if (!navigator.userAgentData || typeof navigator.userAgentData.getHighEntropyValues !== 'function') return {};
      const v = await navigator.userAgentData.getHighEntropyValues(['architecture', 'bitness', 'model', 'platform', 'platformVersion', 'uaFullVersion']);
      return v || {};
    } catch (e) { return {}; }
  }

  async function batteryProbe() {
    try {
      if (!navigator.getBattery) return { ok: false };
      const b = await navigator.getBattery();
      return {
        ok: true,
        charging: b.charging,
        level: Math.round((b.level || 0) * 100),
        chargingTime: b.chargingTime,
        dischargingTime: b.dischargingTime,
        supported: true
      };
    } catch (e) { return { ok: false }; }
  }

  async function storageProbe() {
    try {
      if (!navigator.storage || !navigator.storage.estimate) return { ok: false };
      const e = await navigator.storage.estimate();
      const usage = e.usage ? e.usage : 0;
      const quota = e.quota ? e.quota : 0;
      return {
        ok: true,
        usageBytes: usage,
        quotaBytes: quota,
        usedPct: quota ? Math.round(100 * usage / quota) : null
      };
    } catch (e) { return { ok: false }; }
  }

  async function mediaProbe() {
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.enumerateDevices) return { ok: false };
      const list = await navigator.mediaDevices.enumerateDevices();
      const video = list.filter(d => d.kind === 'videoinput');
      const audioIn = list.filter(d => d.kind === 'audioinput');
      const audioOut = list.filter(d => d.kind === 'audiooutput');
      return { ok: true, cameras: video.length, microphones: audioIn.length, audioOutputs: audioOut.length };
    } catch (e) { return { ok: false }; }
  }

  const mm = (q) => { try { return window.matchMedia ? !!window.matchMedia(q).matches : false; } catch (e) { return false; } };

  async function explore() {
    const ua = navigator.userAgent || '';
    const he = await highEntropy();
    const ff = detectFormFactor();
    const gpu = webglInfo();
    const speed = approximateCpuSpeed();
    const [battery, storage, media, fps] = await Promise.allSettled([
      batteryProbe(), storageProbe(), mediaProbe(), estimateRefreshRate(600)
    ]).then(rs => rs.map(r => r.status === 'fulfilled' ? r.value : { ok: false }));

    const net = (typeof navigator.connection === 'object' && navigator.connection) ? {
      effectiveType: navigator.connection.effectiveType || null,
      downlinkMbps: navigator.connection.downlink || null,
      rttMs: navigator.connection.rtt || null,
      saveData: !!navigator.connection.saveData,
      type: navigator.connection.type || null
    } : { effectiveType: null, downlinkMbps: null, rttMs: null, saveData: null, type: null };

    const screen = window.screen || {};
    const pub = {
      name: 'irrelevant',
      formFactor: ff.value,
      platform: he.platform || navigator.platform || null,
      os: guessOS(ua + (he.platform || ''), he.platform || navigator.platform),
      browser: guessBrowser(ua),
      arch: he.architecture || null,
      bitness: he.bitness || null,
      model: he.model || null,
      uaFull: ua.slice(0, 160),
      language: (navigator.languages || [navigator.language || '']).join(', '),
      online: navigator.onLine,
      touchPoints: ff.touch,
      pointerCoarse: ff.tactile,
      finePointer: ff.hasFinePointer
    };

    const scr = {
      cssW: window.innerWidth, cssH: window.innerHeight,
      availW: screen.availWidth, availH: screen.availHeight,
      colorDepth: screen.colorDepth, pixelDepth: screen.pixelDepth,
      dpr: (window.devicePixelRatio || 1),
      orientation: (screen.orientation && screen.orientation.type) || (screen.msOrientation) || null,
      refreshHz: +fps || null,
      hdr: mm('(dynamic-range: high)'),
      p3: mm('(color-gamut: p3)'),
      prefersDark: mm('(prefers-color-scheme: dark)'),
      reducedMotion: mm('(prefers-reduced-motion: reduce)'),
      monochrome: mm('(monochrome: 1)'),
      foldable: mm('(horizontal-viewport-segments: 2)') || mm('(screen-spanning: single-fold-vertical)')
    };

    const hw = {
      deviceMemory: navigator.deviceMemory || null,
      concurrency: navigator.hardwareConcurrency || null,
      gpu: gpu,
      bluetooth: typeof navigator.bluetooth === 'object',
      usb: typeof navigator.usb === 'object',
      serial: typeof navigator.serial === 'object',
      nfc: typeof navigator.nfc === 'object',
      vibrate: typeof navigator.vibrate === 'function',
      wakeLock: typeof navigator.wakeLock === 'object',
      clipboard: !!(navigator.clipboard && navigator.clipboard.writeText),
      webgl: gpu.ok
    };

    const perf = {
      cpuBench: speed,
      timingType: (typeof performance.getEntriesByType === 'function' && performance.getEntriesByType('navigation').length) ? 'nav' : null,
      reducedMemory: mm('(max-device-memory: 1GB)') ? true : false
    };

    const mediaOut = media.ok ? { cameras: media.cameras, microphones: media.microphones, audioOutputs: media.audioOutputs } : null;

    const sensors = {
      motion: 'DeviceMotionEvent' in window,
      orientation: 'DeviceOrientationEvent' in window,
      proximity: 'DeviceProximityEvent' in window,
      light: 'AmbientLightSensor' in window
    };

    const op = {
      shorthand: navigator.userAgent ? null : null
    };

    /* مصفوفة الكشف المنهجية */
    const cats = {
      device: {
        label: 'الجهاز والنظام', weight: 0.16,
        fields: [
          { k: 'formFactor', v: pub.formFactor },
          { k: 'platform', v: pub.platform }, { k: 'os', v: pub.os },
          { k: 'browser', v: pub.browser }, { k: 'arch', v: pub.arch },
          { k: 'language', v: pub.language }, { k: 'model', v: pub.model }
        ]
      },
      screen: {
        label: 'الشاشة والعرض', weight: 0.14,
        fields: [
          { k: 'resolution', v: scr.cssW + 'x' + scr.cssH }, { k: 'dpr', v: scr.dpr },
          { k: 'colorDepth', v: scr.colorDepth }, { k: 'orientation', v: scr.orientation },
          { k: 'refreshHz', v: scr.refreshHz }, { k: 'hdr', v: scr.hdr },
          { k: 'p3', v: scr.p3 }, { k: 'darkMode', v: scr.prefersDark }
        ]
      },
      hardware: {
        label: 'العتاد', weight: 0.18,
        fields: [
          { k: 'deviceMemory', v: hw.deviceMemory }, { k: 'concurrency', v: hw.concurrency },
          { k: 'gpu', v: hw.gpu.renderer || (hw.gpu.ok ? 'متوفر' : null) }, { k: 'bluetooth', v: hw.bluetooth },
          { k: 'usb', v: hw.usb }, { k: 'vibrate', v: hw.vibrate }
        ]
      },
      power: {
        label: 'الطاقة', weight: 0.12,
        fields: [
          { k: 'batteryLevel', v: battery.ok ? battery.level : null },
          { k: 'charging', v: battery.ok ? battery.charging : null },
          { k: 'chargingTime', v: battery.ok ? battery.chargingTime : null }
        ]
      },
      network: {
        label: 'الشبكة', weight: 0.14,
        fields: [
          { k: 'effectiveType', v: net.effectiveType }, { k: 'downlinkMbps', v: net.downlinkMbps },
          { k: 'rttMs', v: net.rttMs }, { k: 'saveData', v: net.saveData },
          { k: 'online', v: pub.online }
        ]
      },
      performance: {
        label: 'الأداء', weight: 0.10,
        fields: [
          { k: 'cpuBench', v: perf.cpuBench.opsPerMs }, { k: 'memoryTier', v: perf.reducedMemory ? 'منخفض' : null },
          { k: 'touchPoints', v: pub.touchPoints }, { k: 'concurrency', v: hw.concurrency }
        ]
      },
      media: {
        label: 'الوسائط والاستشعار', weight: 0.08,
        fields: [
          { k: 'cameras', v: mediaOut ? mediaOut.cameras : null },
          { k: 'microphones', v: mediaOut ? mediaOut.microphones : null },
          { k: 'motionSensor', v: sensors.motion }, { k: 'orientationSensor', v: sensors.orientation }
        ]
      },
      storage: {
        label: 'التخزين', weight: 0.08,
        fields: [
          { k: 'usedPct', v: storage.usedPct }, { k: 'quotaGB', v: storage.quotaBytes ? Math.round(storage.quotaBytes / 1e9) : null }
        ]
      }
    };

    /* درجة التغطية لكل فئة */
    let totalW = 0, coverageTotal = 0;
    const coverage = {};
    for (const key of Object.keys(cats)) {
      const c = cats[key];
      const present = c.fields.filter(f => f.v !== null && f.v !== undefined && f.v !== '').length;
      const pct = c.fields.length ? Math.round(100 * present / c.fields.length) : 0;
      coverage[key] = pct;
      totalW += c.weight;
      coverageTotal += pct * c.weight;
    }
    const coveragePct = totalW ? Math.round(coverageTotal / totalW) : 0;

    /* درجة الاستكشاف */
    let score;
    if (!pub.formFactor) score = 0;
    else {
      let base = Math.round(coveragePct * 0.55);
      const perfAdj = Math.max(0, Math.min(22, (perf.cpuBench.opsPerMs || 0) / 40000));
      const memAdj = hw.deviceMemory ? Math.min(8, hw.deviceMemory * 2) : 0;
      const netAdj = net.effectiveType === '4g' ? 7 : net.effectiveType === '3g' ? 3 : net.effectiveType ? 1 : 0;
      const gpuAdj = hw.gpu.ok ? 3 : 0;
      score = Math.round(Math.min(100, base + perfAdj + memAdj + netAdj + gpuAdj));
    }

    const level = score >= 85 ? 'متقدم' : score >= 65 ? 'عالٍ' : score >= 45 ? 'متوسط' : 'أساسي';

    const identity = {
      formFactor: pub.formFactor, os: pub.os, browser: pub.browser,
      arch: pub.arch, concurrency: hw.concurrency, deviceMemory: hw.deviceMemory,
      dpr: scr.dpr, viewport: scr.cssW + 'x' + scr.cssH, gpu: hw.gpu.renderer || null
    };
    const fingerprint = stableHash(identity);

    return {
      capturedAt: new Date().toISOString(),
      client: pub, screen: scr, hardware: hw, power: battery.ok ? { level: battery.level, charging: battery.charging, chargingTimeH: battery.chargingTime !== null && battery.chargingTime !== Infinity ? +(battery.chargingTime / 3600).toFixed(2) : null } : null,
      network: net, performance: perf, media: mediaOut, sensors,
      storage: storage.ok ? { usedPct: storage.usedPct, quotaGB: storage.quotaBytes ? Math.round(storage.quotaBytes / 1e9) : null } : null,
      categories: cats, coverage, coveragePct,
      score, level, fingerprint,
      method: 'ELIAS-P-2026 · NIST-800-183-inspired client-forensics profile'
    };
  }

  window.EliasProbe = { explore };
  window.EliasProbe.hash = stableHash;
})();