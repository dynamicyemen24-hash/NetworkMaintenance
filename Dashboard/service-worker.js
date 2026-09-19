/* =====================================================================
   الياس برو v5.0.0 — Service Worker
   استراتيجيات موثوقة:
   - أصول الواجهة: Cache-first مع تحديث في الخلفية (stale-while-revalidate)
   - واجهات API: Network-first مع سقوط على ذاكرة التخزين
   - تقارير الشبكة (Reports/*) ولقطات التشخيص: stale-while-revalidate → تعمل دون اتصال
   - التنقل دون اتصال: سقوط على صفحة الطلب أو app.html
   ===================================================================== */

const CACHE = 'elias-pro-v5.0.0';
const CACHE_REPORTS = 'elias-pro-reports-v1';

const SHELL = [
  './',
  'app.html',
  'deep.html',
  'index.html',
  'login.html',
  'pricing.html',
  'download.html',
  'manifest.json',
  'assets/css/elias-core.css',
  'assets/js/elias-core.js',
  'assets/js/elias-cog.js',
  'assets/js/elias-probe.js',
  'assets/vendor/chart.umd.min.js',
  'tech/shop.html',
  'tech/index-pro.html',
  '../Branding/icon-16.png',
  '../Branding/icon-32.png',
  '../Branding/icon-48.png',
  '../Branding/icon-64.png',
  '../Branding/icon-128.png'
];

const isReport = (url) =>
  /\/Reports\//.test(url.pathname) ||
  /\/Data\//.test(url.pathname) ||
  /(net-health-last\.json|NetworkStandard-Compliance\.json|NetworkHealth\.log|NETWORK_(WAN_)?ALERT\.txt|device-snapshot\.json|device-history\.json)$/i.test(url.href);

const isApi = (url) =>
  url.pathname.startsWith('/api/') || /^api\//.test(url.pathname);

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(SHELL))
      .catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((k) => k !== CACHE && k !== CACHE_REPORTS).map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

/* تخزين/تحديث قديم مع إعادة تحقق موازية */
function staleWhileRevalidate(event, cacheName) {
  event.respondWith(
    caches.open(cacheName).then(async (cache) => {
      const cached = await cache.match(event.request, { ignoreSearch: true });
      const network = fetch(event.request).then((resp) => {
        if (resp && resp.ok) cache.put(event.request, resp.clone());
        return resp;
      }).catch(() => null);
      if (cached) return cached;
      return network || Response.error();
    })
  );
}

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);

  /* واجهات API: الشبكة أولاً ثم الذاكرة */
  if (isApi(url)) {
    event.respondWith(
      fetch(event.request)
        .then((resp) => {
          if (resp && resp.ok) caches.open(CACHE).then((c) => c.put(event.request, resp.clone()));
          return resp;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  /* تقارير الشبكة: ذاكرة أولاً مع تحديث خلفية */
  if (isReport(url)) {
    staleWhileRevalidate(event, CACHE_REPORTS);
    return;
  }

  /* التنقل: تحديث في الخلفية + سقوط على app.html دون اتصال */
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((resp) => {
          const copy = resp.clone();
          caches.open(CACHE).then((c) => c.put(event.request, copy));
          return resp;
        })
        .catch(() =>
          caches.match(event.request).then((hit) =>
            hit || caches.match('./app.html')
          )
        )
    );
    return;
  }

  /* الأصول الساكنة: ذاكرة أولاً متزامن مع تحديث خلفية */
  staleWhileRevalidate(event, CACHE);
});

/* إشعارات النظام (جاهزة لتكامل Teams/Slack) */
self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : { title: 'الياس برو', body: 'تنبيه جديد من الحارس' };
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '../Branding/icon-128.png',
      badge: '../Branding/icon-32.png'
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow('./app.html');
    })
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});