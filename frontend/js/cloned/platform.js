/* ============================================================
   NEXUS 2026 - Global Command Center Platform Kernel
   Unified module registry + dynamic live screen renderer.
   Every backend module becomes a live screen wired to its API.
   ============================================================ */

(function () {
    'use strict';

    const TENANT_HEADER = 'X-Tenant-ID';

    /* ---------- Unified API client (auth + tenant aware) ---------- */
    const PlatformAPI = {
        baseHeaders(extra) {
            const h = Object.assign({}, extra || {});
            const token = sessionStorage.getItem('auth_token');
            const tenant = sessionStorage.getItem('tenant_id');
            if (token) h['Authorization'] = 'Bearer ' + token;
            if (tenant) h[TENANT_HEADER] = tenant;
            return h;
        },
        async get(path) {
            const res = await fetch(path, { headers: this.baseHeaders() });
            if (!res.ok) throw new Error('HTTP ' + res.status);
            const ct = res.headers.get('content-type') || '';
            return ct.includes('json') ? res.json() : res.text();
        },
        async post(path, body) {
            const res = await fetch(path, {
                method: 'POST',
                headers: this.baseHeaders({ 'Content-Type': 'application/json' }),
                body: body === undefined ? undefined : JSON.stringify(body)
            });
            if (!res.ok) throw new Error('HTTP ' + res.status);
            const ct = res.headers.get('content-type') || '';
            return ct.includes('json') ? res.json() : res.text();
        }
    };

    /* ---------- Registry: verified live endpoints ---------- */
    const GROUPS = [
        { id: 'commerce',   name: 'التجارة والمبيعات',    icon: 'fa-cart-shopping' },
        { id: 'finance',    name: 'المالية والمحاسبة',    icon: 'fa-chart-line' },
        { id: 'inventory',  name: 'المخزون والمشتريات',   icon: 'fa-boxes-stacked' },
        { id: 'pharmacy',   name: 'الصيدلة والرعاية',     icon: 'fa-tablets' },
        { id: 'repair',     name: 'الصيانة والورش',       icon: 'fa-screwdriver-wrench' },
        { id: 'intel',      name: 'الذكاء والتشخيص',      icon: 'fa-brain-circuit' },
        { id: 'platform',   name: 'بنية المنصة والحوكمة', icon: 'fa-server' },
        { id: 'workspace',  name: 'الوركسبيس المتقدم',     icon: 'fa-layer-group' }
    ];

    const MODULES = [
        /* ===== التجارة والمبيعات ===== */
        { id: 'dashboard', group: 'commerce', name: 'مركز القيادة', icon: 'fa-gauge-high', special: 'home', desc: 'المؤشرات الحية وحالة المنصة الموحدة' },
        { id: 'sales', group: 'commerce', name: 'المبيعات والتحليلات', icon: 'fa-chart-pie', endpoints: [
            { label: 'ملخص المبيعات', path: '/sales/reports/summary', render: 'kpis' },
            { label: 'التحليلات', path: '/sales/reports/analytics', render: 'kpis' },
            { label: 'أفضل المنتجات', path: '/sales/reports/top-products', render: 'table' },
            { label: 'تقرير الضرائب', path: '/sales/reports/tax', render: 'table' },
            { label: 'الأداء', path: '/sales/reports/performance', render: 'kpis' }
        ], desc: 'تقارير المبيعات وأفضل المنتجات والضرائب' },
        { id: 'pos', group: 'commerce', name: 'نقطة البيع POS', icon: 'fa-cash-register', endpoints: [
            { label: 'تحليل المبيعات', path: '/pos/analytics/summary', render: 'kpis' },
            { label: 'الفواتير', path: '/pos/sales/invoices', render: 'table' },
            { label: 'المنتجات', path: '/pos/products', render: 'table' },
            { label: 'المخزون', path: '/pos/inventory', render: 'table' },
            { label: 'الفروع', path: '/pos/branches', render: 'table' },
            { label: 'وصفات معلقة', path: '/pos/prescriptions/pending', render: 'table' },
            { label: 'مخزون منخفض', path: '/pos/inventory/low-stock', render: 'table' },
            { label: 'قرب انتهاء الصلاحية', path: '/pos/inventory/expiry-soon', render: 'table' }
        ], desc: 'العمليات التجارية اللحظية والفوترة والإغلاق' },
        { id: 'crm', group: 'commerce', name: 'إدارة العملاء CRM', icon: 'fa-users', endpoints: [
            { label: 'العملاء', path: '/crm/customers', render: 'table' },
            { label: 'الموردون', path: '/crm/suppliers', render: 'table' }
        ], desc: 'عملاء وموردون 360 وكشوفات حسابات' },
        { id: 'custstatement', group: 'commerce', name: 'كشوفات الحسابات', icon: 'fa-receipt', endpoints: [], desc: 'كشف حساب العميل والمورد' },
        { id: 'crud-customers', group: 'commerce', name: 'العملاء', icon: 'fa-users', endpoints: [], desc: 'دليل العملاء وكشوفات الحسابات والحدود الائتمانية' },
        { id: 'crud-sales', group: 'commerce', name: 'فواتير المبيعات', icon: 'fa-file-invoice-dollar', endpoints: [], desc: 'إصدار فواتير بيع مع بنود وضريبة وقبض' },
        { id: 'closings', group: 'commerce', name: 'الإغلاقات والتقارير', icon: 'fa-file-signature', endpoints: [
            { label: 'سجل الإغلاقات', path: '/closings-and-reports/closings', render: 'table' },
            { label: 'احتساب POS تلقائي', path: '/closings-and-reports/closings/auto-calculate-pos', render: 'kpis' },
            { label: 'الملخص التنفيذي', path: '/closings-and-reports/reports/executive-summary', render: 'kpis' },
            { label: 'المشتركون الحقيقيون', path: '/closings-and-reports/subscribers/real-tenants-list', render: 'table' },
            { label: 'تقرير متعدد الأبعاد', path: '/closings-and-reports/reports/multi-dimensional', render: 'detail' }
        ], desc: 'الإغلاقات اليومية والتقارير التنفيذية' },
        { id: 'operations', group: 'commerce', name: 'العمليات والإقفالات', icon: 'fa-sheet-plastic', endpoints: [], desc: 'الإغلاقات اليومية والعمليات التشغيلية' },
        { id: 'logistics', group: 'commerce', name: 'اللوجستيات والتوصيل', icon: 'fa-truck', endpoints: [
            { label: 'السائقون', path: '/logistics/drivers', render: 'table' },
            { label: 'التسليمات', path: '/logistics/deliveries', render: 'table' }
        ], desc: 'السائقون والتسليمات والتتبع' },

        /* ===== المالية والمحاسبة ===== */
        { id: 'accounting', group: 'finance', name: 'المحاسبة والسجل', icon: 'fa-money-bill-wave', endpoints: [
            { label: 'شجرة الحسابات', path: '/accounting/chart-of-accounts', render: 'table' },
            { label: 'ميزان المراجعة', path: '/accounting/trial-balance', render: 'table' },
            { label: 'دفتر اليومية', path: '/accounting/journal-entries', render: 'table' },
            { label: 'قائمة الدخل', path: '/accounting/financial-statements/income-statement', render: 'kpis' }
        ], desc: 'شجرة الحسابات والميزان والقيود' },
        { id: 'crud-accounts', group: 'finance', name: 'دليل الحسابات', icon: 'fa-book', endpoints: [], desc: 'شجرة حسابات مزدوجة القيد مع الأرصدة' },
        { id: 'crud-journal', group: 'finance', name: 'القيود المحاسبية', icon: 'fa-receipt', endpoints: [], desc: 'إدخال قيود محاسبية متوازنة (مدين/دائن)' },
        { id: 'acct-cycle', group: 'finance', name: 'الدورة المحاسبية', icon: 'fa-scale-balanced', endpoints: [], desc: 'دورة محاسبية معيارية كاملة: افتتاحيات، قيود، أستاذ، ميزان، تسويات، قوائم مالية، إقفال' },
        { id: 'inventory_fin', group: 'finance', name: 'تقييم المخزون المالي', icon: 'fa-scale-balanced', endpoints: [
            { label: 'دوران المخزون', path: '/accounting/inventory/turnover', render: 'table' },
            { label: 'هامش الربح', path: '/accounting/inventory/gross-margin', render: 'table' },
            { label: 'تكاليف الاحتفاظ', path: '/accounting/inventory/holding-costs', render: 'table' },
            { label: 'نقطة إعادة الطلب', path: '/accounting/inventory/reorder-point', render: 'table' }
        ], desc: 'التحليل المالي العميق للمخزون' },
        { id: 'enterprise', group: 'finance', name: 'الشركات والعملات', icon: 'fa-building-columns', endpoints: [
            { label: 'المستأجرون', path: '/enterprise/tenants', render: 'table' },
            { label: 'الشركات', path: '/enterprise/companies', render: 'table' },
            { label: 'الفروع', path: '/enterprise/branches', render: 'table' },
            { label: 'العملات', path: '/enterprise/currencies', render: 'table' },
            { label: 'أسعار الصرف', path: '/enterprise/exchange-rates', render: 'table' },
            { label: 'السنوات المالية', path: '/enterprise/fiscal-years', render: 'table' },
            { label: 'وحدات القياس', path: '/enterprise/uom', render: 'table' },
            { label: 'سياسات التسعير', path: '/enterprise/pricing-policies', render: 'table' }
        ], desc: 'الكيان المؤسسي متعدد المستأجرين' },
        { id: 'vouchers', group: 'finance', name: 'السندات والقيود', icon: 'fa-receipt', endpoints: [
            { label: 'السندات', path: '/accounting/vouchers', render: 'table' },
            { label: 'أوامر الشراء', path: '/purchases/orders', render: 'table' },
            { label: 'الموردون', path: '/purchases/suppliers', render: 'table' }
        ], desc: 'سندات القبض والصرف والقيود' },
        { id: 'statements', group: 'finance', name: 'القوائم المالية', icon: 'fa-file-invoice-dollar', endpoints: [], desc: 'الميزانية العمومية وقائمة الدخل والتدفق النقدي (IFRS)' },
        { id: 'opening', group: 'finance', name: 'الأرصدة الافتتاحية', icon: 'fa-folder-open', endpoints: [], desc: 'ترحيل وتدقيق الأرصدة الافتتاحية للحسابات' },
        { id: 'reports', group: 'finance', name: 'التقارير المعيارية', icon: 'fa-chart-area', endpoints: [], desc: 'مركز التقارير المالية المعيارية' },

        /* ===== المخزون والمشتريات ===== */
        { id: 'procurement', group: 'inventory', name: 'المشتريات', icon: 'fa-truck-fast', endpoints: [
            { label: 'الموردون', path: '/procurement/suppliers', render: 'table' },
            { label: 'أوامر الشراء', path: '/procurement/purchase-orders', render: 'table' }
        ], desc: 'الطلبات وأوامر الشراء والموردين' },
        { id: 'inventory', group: 'inventory', name: 'المخزون متعدد المستودعات', icon: 'fa-warehouse', endpoints: [
            { label: 'المستودعات', path: '/inventory/warehouses', render: 'table' }
        ], desc: 'المستودعات والتحويلات والتجميع' },
        { id: 'assets', group: 'inventory', name: 'الأصول', icon: 'fa-box-archive', endpoints: [
            { label: 'سجل الأصول', path: '/assets', render: 'table' }
        ], desc: 'سجل أصول المؤسسة' },
        { id: 'invbalances', group: 'inventory', name: 'الأرصدة المخزنية', icon: 'fa-boxes-stacked', endpoints: [], desc: 'قيم الكميات والتقييم لكل مستودع' },
        { id: 'stocktaking', group: 'inventory', name: 'قوائم الجرد', icon: 'fa-clipboard-list', endpoints: [], desc: 'جداول الجرد والفروقات والتسويات' },
        { id: 'crud-items', group: 'inventory', name: 'الأصناف', icon: 'fa-boxes-stacked', endpoints: [], desc: 'دليل الأصناف والتسعير والمخزون ونقطة إعادة الطلب' },
        { id: 'crud-purchases', group: 'inventory', name: 'أوامر الشراء', icon: 'fa-truck-loading', endpoints: [], desc: 'أوامر شراء من الموردين مع بنود واستلام' },
        { id: 'crud-vendors', group: 'inventory', name: 'الموردون', icon: 'fa-truck-field', endpoints: [], desc: 'دليل الموردين وكشوفات حساباتهم' },

        /* ===== الصيدلة والرعاية ===== */
        { id: 'pharmacy', group: 'pharmacy', name: 'الصيدلية الذكية', icon: 'fa-tablets', endpoints: [
            { label: 'مؤشرات الأداء', path: '/pharmacy/kpis', render: 'kpis' },
            { label: 'تنبيهات انتهاء الصلاحية', path: '/pharmacy/inventory/expiry-alerts', render: 'table' },
            { label: 'المواد الخاضعة للرقابة', path: '/pharmacy/inventory/controlled-substances', render: 'table' },
            { label: 'تقرير الامتثال', path: '/pharmacy/compliance/report', render: 'detail' },
            { label: 'امتثال نبض', path: '/pharmacy/compliance/nabidh', render: 'detail' }
        ], desc: 'الأدوية والوصفات والامتثال' },
        { id: 'pharmacy_biz', group: 'pharmacy', name: 'تكامل الصيدلية', icon: 'fa-prescription-bottle-medical', endpoints: [
            { label: 'مؤشرات الأداء', path: '/pharmacy/integration/dashboard/kpis', render: 'kpis' },
            { label: 'التقييم اللحظي', path: '/pharmacy/integration/inventory/realtime-valuation', render: 'kpis' },
            { label: 'تقليل الفاقد', path: '/pharmacy/integration/inventory/expiry-loss-reduction', render: 'kpis' },
            { label: 'اقتراحات إعادة التوريد', path: '/pharmacy/integration/procurement/reorder-suggestions', render: 'table' },
            { label: 'عقود الموردين', path: '/pharmacy/integration/procurement/supplier-contracts', render: 'table' },
            { label: 'خط المبيعات', path: '/pharmacy/integration/sales/pipeline-summary', render: 'kpis' },
            { label: 'تقرير الربح والخسارة', path: '/pharmacy/integration/accounting/pnl-report', render: 'kpis' },
            { label: 'أداء الفئات', path: '/pharmacy/integration/accounting/category-performance', render: 'table' },
            { label: 'الميزانية مقابل الفعلي', path: '/pharmacy/integration/accounting/budget-vs-actual', render: 'table' },
            { label: 'صحة النظام', path: '/pharmacy/integration/system-health', render: 'kpis' }
        ], desc: 'المؤشرات والتقييم والهوامش والربحية' },

        /* ===== الصيانة والورش ===== */
        { id: 'maintenance', group: 'repair', name: 'الصيانة والأجهزة', icon: 'fa-wrench', endpoints: [
            { label: 'أنواع الأجهزة', path: '/maintenance/device-types', render: 'table' },
            { label: 'الأجهزة', path: '/maintenance/devices', render: 'table' },
            { label: 'قاعدة المعرفة', path: '/maintenance/knowledge-base', render: 'table' }
        ], desc: 'الأجهزة والتشخيص وخطط الإصلاح' },
        { id: 'crud-maintenance', group: 'repair', name: 'أوامر الصيانة', icon: 'fa-screwdriver-wrench', endpoints: [], desc: 'أوامر عمل صيانة للأجهزة مع حالة وأولوية وتكلفة' },
        { id: 'repair', group: 'repair', name: 'ورشة الإصلاح ERP', icon: 'fa-gears', endpoints: [
            { label: 'أوامر العمل', path: '/repair/orders', render: 'table' },
            { label: 'قطع الغيار', path: '/repair/parts', render: 'table' },
            { label: 'تقرير المبيعات', path: '/repair/reports/sales', render: 'kpis' },
            { label: 'تقرير المخزون', path: '/repair/reports/inventory', render: 'kpis' },
            { label: 'تقييم المخزون', path: '/repair/reports/inventory-valuation', render: 'kpis' },
            { label: 'مخزون منخفض', path: '/repair/reports/low-stock', render: 'table' },
            { label: 'التحويلات', path: '/repair/stock/transfers', render: 'table' },
            { label: 'الجرد', path: '/repair/stock/stocktaking', render: 'table' }
        ], desc: 'أوامر العمل والقطع والضمانات' },
        { id: 'repair_advanced', group: 'repair', name: 'الإصلاح المتقدم', icon: 'fa-microchip', endpoints: [
            { label: 'فئات الأجهزة', path: '/repair/advanced/device-categories', render: 'table' }
        ], desc: 'التشخيص المتقدم وخطط المعالجة' },

        /* ===== الذكاء والتشخيص ===== */
        { id: 'system', group: 'intel', name: 'مراقبة النظام', icon: 'fa-activity', endpoints: [
            { label: 'الملخص', path: '/system/dashboard-summary', render: 'kpis' },
            { label: 'الصحة', path: '/system/health', render: 'kpis' },
            { label: 'المحركات', path: '/system/engines', render: 'kpis' },
            { label: 'المقاييس', path: '/system/metrics', render: 'kpis' },
            { label: 'إحصائيات الكاش', path: '/system/cache/stats', render: 'kpis' }
        ], desc: 'الصحة والمقاييس والمحركات' },
        { id: 'discovery', group: 'intel', name: 'الاكتشاف والأجهزة', icon: 'fa-satellite-dish', endpoints: [
            { label: 'سجل الأجهزة', path: '/discovery/device-history', render: 'table' },
            { label: 'الأصول المكتشفة', path: '/discovery/assets', render: 'table' },
            { label: 'الحالة', path: '/discovery/status', render: 'kpis' },
            { label: 'أوامر العمل', path: '/discovery/work-orders', render: 'table' },
            { label: 'سياسات المشتركين', path: '/discovery/subscriber-policies', render: 'table' },
            { label: 'المشتركون', path: '/discovery/subscribers', render: 'table' }
        ], desc: 'اكتشاف العتاد والشبكة وسجل الأجهزة' },
        { id: 'diagnostics', group: 'intel', name: 'التشخيص الذكي', icon: 'fa-stethoscope', endpoints: [
            { label: 'تاريخ الأنابيب', path: '/diagnostics/pipeline/history', render: 'table' }
        ], desc: 'المساعد الذكي والتشخيص الفوري' },
        { id: 'ai_engine', group: 'intel', name: 'محرك الذكاء التوقعي', icon: 'fa-chart-line', endpoints: [
            { label: 'استنزاف المخزون', path: '/ai/forecast/inventory-depletion', render: 'table' },
            { label: 'توقعات الإيرادات', path: '/ai/forecast/revenue-projections', render: 'detail' }
        ], desc: 'التنبؤ بالمخزون والإيرادات' },
        { id: 'knowledge', group: 'intel', name: 'قاعدة المعرفة', icon: 'fa-book-open', endpoints: [
            { label: 'الموسوعة', path: '/knowledge', render: 'table' },
            { label: 'البحث', path: '/knowledge/search', render: 'table' },
            { label: 'التصنيفات', path: '/knowledge/categories', render: 'table' }
        ], desc: 'المعرفة الهندسية والإرشادات' },
        { id: 'uci', group: 'intel', name: 'نواة UCI', icon: 'fa-cpu', endpoints: [
            { label: 'الحالة', path: '/uci/status', render: 'kpis' },
            { label: 'الأحداث', path: '/uci/events', render: 'table' },
            { label: 'المعرفة', path: '/uci/knowledge', render: 'table' },
            { label: 'الملفات الشخصية', path: '/uci/profiles', render: 'table' },
            { label: 'المراحل', path: '/uci/phases', render: 'table' },
            { label: 'التعلم', path: '/uci/learning', render: 'table' },
            { label: 'الصحة الكلية', path: '/uci/health/all', render: 'table' },
            { label: 'التحقق', path: '/uci/validations', render: 'table' },
            { label: 'التحليلات', path: '/uci/analyses', render: 'table' }
        ], desc: 'ذكاء النواة المركزي والتحليلات العصبية' },
        { id: 'mobile', group: 'intel', name: 'تشخيص الأجهزة المحمولة', icon: 'fa-mobile-screen', endpoints: [
            { label: 'البيئة', path: '/mobile/environment', render: 'kpis' },
            { label: 'التشخيص الكامل', path: '/mobile/diagnostics/full', render: 'detail' }
        ], desc: 'تشخيص البيئة والأجهزة عبر ADB' },
        { id: 'master', group: 'intel', name: 'مركز القيادة الصحي', icon: 'fa-heart-pulse', endpoints: [
            { label: 'مركز الصحة', path: '/master/health-command-center', render: 'kpis' }
        ], desc: 'الأمر الصحي الموحد والمعالجة الكلية' },

        /* ===== بنية المنصة والحوكمة ===== */
        { id: 'subscription', group: 'platform', name: 'الاشتراك والترخيص', icon: 'fa-crown', endpoints: [
            { label: 'الباقات', path: '/api/v1/subscription/plans', render: 'table' },
            { label: 'الترخيص الحالي', path: '/api/v1/subscription/license', render: 'kpis' },
            { label: 'السياسات الإدارية', path: '/api/v1/subscription/admin/policies', render: 'table' }
        ], desc: 'باقات SaaS والتفعيل والحوكمة' },
        { id: 'users', group: 'platform', name: 'المستخدمون والصلاحيات', icon: 'fa-user-shield', endpoints: [
            { label: 'الأدوار', path: '/users/roles', render: 'table' }
        ], desc: 'RBAC والتدقيق والامتثال' },
        { id: 'sync', group: 'platform', name: 'المزامنة الأوفلاين', icon: 'fa-cloud-arrow-up', endpoints: [
            { label: 'الحالة', path: '/sync/status', render: 'kpis' },
            { label: 'قائمة الانتظار', path: '/sync/pending', render: 'table' },
            { label: 'التعارضات', path: '/sync/conflicts', render: 'table' },
            { label: 'الصحة', path: '/sync/health', render: 'kpis' }
        ], desc: 'المزامنة الذكية والتعارضات' },
        { id: 'connectors', group: 'platform', name: 'الموصلات المؤسسية', icon: 'fa-plug', endpoints: [
            { label: 'الموصلات', path: '/connectors', render: 'table' },
            { label: 'الحالة', path: '/connectors/status', render: 'kpis' }
        ], desc: 'تكامل الأنظمة الخارجية' },
        { id: 'missions', group: 'platform', name: 'المهام الذاتية', icon: 'fa-robot', endpoints: [
            { label: 'المهام', path: '/missions', render: 'table' }
        ], desc: 'مهام التشغيل الذاتي' },
        { id: 'agents', group: 'platform', name: 'الوكالات', icon: 'fa-user-astronaut', endpoints: [
            { label: 'الوكالات', path: '/agents', render: 'table' },
            { label: 'الحالة', path: '/agents/status', render: 'kpis' }
        ], desc: 'وكلاء الأجهزة المتصلون' },
        { id: 'operations', group: 'platform', name: 'عمليات النظام', icon: 'fa-terminal', endpoints: [
            { label: 'العمليات', path: '/operations', render: 'detail' }
        ], desc: 'التسريع والمعالجة وتنفيذ السكربتات' },

        /* ===== الوركسبيس المتقدم (شاشات معيارية E2E) ===== */
        { id: 'fin-dashboard', group: 'workspace', name: 'اللوحة المالية', icon: 'fa-chart-line', desc: 'مؤشرات مالية حية + رسوم بيانية + قيود حديثة' },
        { id: 'fin-journal', group: 'workspace', name: 'القيود المحاسبية', icon: 'fa-book', desc: 'إنشاء وترحيل القيود اليومية (قيد مزدوج)' },
        { id: 'fin-vouchers', group: 'workspace', name: 'سندات القبض والصرف', icon: 'fa-receipt', desc: 'إصدار سندات القبض والصرف وترحيلها' },
        { id: 'fin-statements', group: 'workspace', name: 'القوائم المالية', icon: 'fa-file-invoice-dollar', desc: 'الميزانية العمومية وقائمة الدخل (IFRS)' },
        { id: 'fin-tax', group: 'workspace', name: 'الضرائب والزكاة', icon: 'fa-percent', desc: 'إقرار ضريبة القيمة المضافة والتحليل الضريبي' },
        { id: 'fin-aging', group: 'workspace', name: 'أعمار الذمم', icon: 'fa-hourglass-half', desc: 'تقارير أعمار الذمم المدينة والدائنة' },
        { id: 'fin-cashflow', group: 'workspace', name: 'التدفق النقدي', icon: 'fa-money-bill-trend-up', desc: 'بيان التدفق النقدي غير المباشر' },
        { id: 'setup-coa', group: 'workspace', name: 'شجرة الحسابات', icon: 'fa-sitemap', desc: 'إعداد وصيانة دليل الحسابات' },
        { id: 'inv-stock', group: 'workspace', name: 'المخزون والتقييم', icon: 'fa-warehouse', desc: 'تقييم المخزون والمستودعات و التنبيهات' },
        { id: 'inv-analytics', group: 'workspace', name: 'تحليلات المخزون', icon: 'fa-chart-area', desc: 'دوران/ABC/فاقد/نقطة إعادة الطلب' },
        { id: 'pur-orders', group: 'workspace', name: 'أوامر الشراء', icon: 'fa-truck-fast', desc: 'إنشاء أوامر الشراء والفواتير الموردية' },
        { id: 'pur-suppliers', group: 'workspace', name: 'الموردون', icon: 'fa-handshake', desc: 'دليل الموردين والأرصدة' },
        { id: 'sal-customers', group: 'workspace', name: 'العملاء والذمم', icon: 'fa-users', desc: 'دليل العملاء والكشوفات والسداد' },
        { id: 'ops-production', group: 'workspace', name: 'أوامر الإنتاج', icon: 'fa-industry', desc: 'أوامر العمل والإنتاج والتجميع' },
        { id: 'ops-closings', group: 'workspace', name: 'الإقفالات اليومية', icon: 'fa-file-signature', desc: 'تسجيل الإقفالات والورديات' },
        { id: 'reports-center', group: 'workspace', name: 'مركز التقارير', icon: 'fa-chart-pie', desc: 'مكتبة التقارير المالية والتشغيلية' },
        { id: 'reports-documents', group: 'workspace', name: 'المستندات المعيارية', icon: 'fa-file-lines', desc: 'توليد وطباعة الفواتير وأوراق العمل' }
    ];

    /* ---------- Helpers ---------- */
    function isPlainObject(v) {
        return v !== null && typeof v === 'object' && !Array.isArray(v);
    }
    function truncate(s, n) {
        s = String(s == null ? '' : s);
        return s.length > n ? s.slice(0, n) + '…' : s;
    }
    function esc(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }
    function humanizeKey(k) {
        return String(k).replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    }

    /* ---------- Deep-engineering helpers ---------- */
    function isNum(v) { return typeof v === 'number' && isFinite(v); }
    function fmtNum(v) {
        if (!isNum(v)) return String(v == null ? '' : v);
        if (Math.abs(v) >= 1e9) return (v / 1e9).toFixed(1) + 'B';
        if (Math.abs(v) >= 1e6) return (v / 1e6).toFixed(1) + 'M';
        if (Math.abs(v) >= 1e3) return (v / 1e3).toFixed(1) + 'K';
        return (Math.round(v * 100) / 100).toString();
    }
    function fmtCurrency(v) {
        const n = Number(v);
        if (!isNum(n)) return String(v == null ? '' : v);
        return fmtNum(n) + ' ' + (window.__NX_CCUR || 'SAR');
    }
    function statusClass(s) {
        s = String(s || '').toLowerCase().trim();
        const ok = ['ok', 'active', 'delivered', 'paid', 'completed', 'approved', 'running', 'online', 'balanced', 'healthy', 'success', 'open'];
        const warn = ['pending', 'partial', 'shipped', 'draft', 'in_transit', 'warning', 'degraded', 'in_progress', 'queued'];
        const bad = ['inactive', 'failed', 'overdue', 'error', 'closed', 'offline', 'unhealthy', 'critical'];
        if (ok.includes(s)) return 'ok';
        if (warn.includes(s)) return 'warn';
        if (bad.includes(s)) return 'bad';
        return 'info';
    }
    function sparkline(values, color) {
        if (!Array.isArray(values) || values.length < 2) return '';
        const w = 100, h = 34, min = Math.min(...values), max = Math.max(...values);
        const span = (max - min) || 1;
        const pts = values.map((v, i) => {
            const x = (i / (values.length - 1)) * w;
            const y = h - 3 - ((v - min) / span) * (h - 6);
            return x.toFixed(1) + ',' + y.toFixed(1);
        }).join(' ');
        const last = values[values.length - 1];
        const lx = w, ly = h - 3 - ((last - min) / span) * (h - 6);
        return `<svg class="nx-kpi-spark" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none">
            <polyline points="${pts}" fill="none" stroke="${color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" opacity="0.9"/>
            <circle cx="${lx.toFixed(1)}" cy="${ly.toFixed(1)}" r="2" fill="${color}"/>
        </svg>`;
    }

    /* ---------- Live screen renderer ---------- */
    const Renderer = {
        empty(message) {
            return '<div class="px-empty"><i class="fa-solid fa-circle-info"></i><div>' + esc(message) + '</div></div>';
        },
        kpis(data) {
            const moneyKeys = /(total|amount|balance|price|cost|revenue|debit|credit|salary|value|net|profit|tax|salary)/i;
            const entries = [];
            const walk = (obj, prefix) => {
                if (isPlainObject(obj)) {
                    Object.entries(obj).forEach(([k, v]) => {
                        if (isPlainObject(v) && Object.keys(v).length <= 6) walk(v, k);
                        else if (typeof v === 'number' || (typeof v === 'string' && /^[\d.]+$/.test(v))) {
                            entries.push({ key: prefix ? prefix + ' / ' + k : k, value: v, money: moneyKeys.test(k) });
                        }
                    });
                }
            };
            walk(data, '');
            if (!entries.length) entries.push({ key: 'الحالة', value: data && typeof data === 'object' ? 'متاح' : String(data), money: false });
            const cards = entries.slice(0, 10).map(e => {
                const val = e.money ? fmtCurrency(e.value) : esc(e.value);
                return `<div class="nx-kpi">
                    <div class="nx-kpi-label">${esc(humanizeKey(e.key))}</div>
                    <div class="nx-kpi-value">${val}</div>
                </div>`;
            }).join('');
            return '<div class="px-kpis">' + cards + '</div>';
        },
        detail(data) {
            const rows = [];
            const walk = (obj, prefix) => {
                Object.entries(obj).forEach(([k, v]) => {
                    const label = prefix ? prefix + ' • ' + k : k;
                    if (isPlainObject(v)) walk(v, label);
                    else if (Array.isArray(v)) rows.push(`<div class="px-d-row"><span class="px-d-key">${esc(humanizeKey(label))}</span><span class="px-d-val">${esc(v.length)} عناصر</span></div>`);
                    else rows.push(`<div class="px-d-row"><span class="px-d-key">${esc(humanizeKey(label))}</span><span class="px-d-val">${esc(truncate(v, 90))}</span></div>`);
                });
            };
            walk(data, '');
            return '<div class="px-detail">' + rows.join('') + '</div>';
        },
        table(data) {
            if (isPlainObject(data)) {
                const lists = Object.entries(data).filter(([, v]) => Array.isArray(v));
                if (lists.length === 1) data = lists[0][1];
                else if (lists.length > 1) {
                    return lists.map(([key, arr]) => '<div class="px-subtitle">' + esc(humanizeKey(key)) + ' (' + arr.length + ')</div>' + Renderer.table(arr)).join('');
                }
                else return this.detail(data);
            }
            if (!Array.isArray(data) || !data.length) return this.empty('لا توجد بيانات لعرضها');
            const headers = Object.keys(data[0]).filter(k => {
                const v = data[0][k];
                return !(isPlainObject(v) || Array.isArray(v)) || typeof v === 'string';
            });
            const moneyKeys = /(total|amount|balance|price|cost|revenue|debit|credit|salary|value|net|profit|tax|subtotal|unit_cost|selling_price|current_balance|credit_limit)/i;
            const head = headers.map(h => `<th>${esc(humanizeKey(h))}</th>`).join('');
            const body = data.slice(0, 60).map(row => {
                const cells = headers.map(h => {
                    let raw = row[h];
                    let content;
                    if (isNum(raw) && moneyKeys.test(h)) content = `<span class="nx-cur">${fmtCurrency(raw)}</span>`;
                    else if (isNum(raw)) content = `<span class="nx-num">${fmtNum(raw)}</span>`;
                    else if (typeof raw === 'string' && statusClass(raw) !== 'info') content = `<span class="nx-pill ${statusClass(raw)}">${esc(raw)}</span>`;
                    else content = esc(truncate(raw, 60));
                    return `<td>${content}</td>`;
                }).join('');
                return `<tr>${cells}</tr>`;
            }).join('');
            return `<div class="px-table-wrap"><table class="px-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
        }
    };

    /* ---------- Module live screen ---------- */
    async function loadModuleScreen(module, host) {
        host.innerHTML = '<div class="px-loading"><div class="px-spinner"></div><div>جاري سحب البيانات الحية...</div></div>';
        if (!module.endpoints || !module.endpoints.length) {
            host.innerHTML = '<div class="px-empty"><i class="fa-solid fa-sliders"></i><div>هذه الوحدة لا تتطلب بيانات خارجية — استخدم الإجراءات التفاعلية.</div></div>';
            return;
        }
        let html = '';
        for (const ep of module.endpoints) {
            html += `<div class="px-card">
                <div class="px-card-head"><span>${esc(ep.label)}</span><button class="px-refresh" onclick="PlatformKernel.reload('${module.id}')" title="تحديث"><i class="fa-solid fa-rotate"></i></button></div>
                <div class="px-card-body" data-path="${esc(ep.path)}" data-render="${ep.render || 'table'}" data-method="${ep.method || 'GET'}">...</div>
            </div>`;
        }
        host.innerHTML = html;
        host.querySelectorAll('.px-card-body').forEach(async (bodyEl) => {
            const path = bodyEl.getAttribute('data-path');
            const render = bodyEl.getAttribute('data-render');
            const method = bodyEl.getAttribute('data-method');
            const ep = module.endpoints.find(e => e.path === path);
            try {
                const data = method === 'POST'
                    ? await PlatformAPI.post(path, ep && ep.body)
                    : await PlatformAPI.get(path);
                bodyEl.innerHTML = Renderer[render](data);
            } catch (err) {
                bodyEl.innerHTML = '<div class="px-empty px-error"><i class="fa-solid fa-triangle-exclamation"></i><div>تعذر جلب البيانات: ' + esc(err.message) + '</div></div>';
            }
        });
    }

    /* ---------- Command Center home (deep engineering) ---------- */
    async function renderHome(host) {
        host.innerHTML = '<div class="px-loading"><div class="px-spinner"></div><div>جاري تجهيز مركز القيادة الحي...</div></div>';
        const user = sessionStorage.getItem('user_name') || 'المستخدم';
        const role = sessionStorage.getItem('user_role') || '';
        const tenant = sessionStorage.getItem('tenant_name') || 'NEXUS';

        let sys = null, dash = null, uci = null, conn = null;
        try { sys = await PlatformAPI.get('/system/dashboard-summary'); } catch (e) {}
        try { dash = await PlatformAPI.get('/api/v1/dashboard/kpis'); } catch (e) {}
        try { uci = await PlatformAPI.get('/uci/status'); } catch (e) {}
        try { conn = await PlatformAPI.get('/connectors/status'); } catch (e) {}

        /* --- KPI tiles (real) --- */
        const kpiMetrics = (dash && dash.kpi_metrics) || {};
        const moneyKeys = /(total|amount|balance|revenue|profit|sales|cost|tax|credit|debit|net)/i;
        const kpiEntries = Object.entries(kpiMetrics)
            .filter(([, v]) => isNum(v)).slice(0, 8)
            .map(([k, v]) => {
                const val = moneyKeys.test(k) ? fmtCurrency(v) : fmtNum(v);
                return `<div class="nx-kpi">
                    <div class="nx-kpi-label">${esc(humanizeKey(k))}</div>
                    <div class="nx-kpi-value">${val}</div>
                </div>`;
            });
        const kpiHtml = kpiEntries.length
            ? kpiEntries.join('')
            : '<div class="nx-kpi"><div class="nx-kpi-label">الحالة</div><div class="nx-kpi-value">متصل</div></div>';

        /* --- Engineering Intelligence strip (real live metrics) --- */
        const health = (sys && isNum(sys.health_score)) ? Math.round(sys.health_score) : null;
        const eng = uci || {};
        const engines = eng.engines_registered || 0;
        const agents = eng.agents_registered || 0;
        const connectors = (conn && conn.registered_connectors) ? conn.registered_connectors.length : (eng.connectors_registered || 0);
        const pipeline = Array.isArray(eng.engineering_pipeline) ? eng.engineering_pipeline.length : 0;
        const bootMs = eng.boot_duration_ms ? Math.round(eng.boot_duration_ms) : null;
        const intelHtml = `
            <div class="nx-section-title"><i class="fa-solid fa-microchip"></i> ذكاء هندسي حي <span class="nx-line"></span></div>
            <div class="nx-intel">
                <div class="nx-intel-card">
                    <div class="nx-ic-top"><div class="nx-ic-icon"><i class="fa-solid fa-heart-pulse"></i></div>
                        <div><div class="nx-ic-title">صحة المنصة</div><div class="nx-ic-sub">Health Score</div></div></div>
                    <div class="nx-ic-metric">${health != null ? health + '%' : '—'}</div>
                    <div class="nx-ic-bar"><span style="width:${health != null ? health : 0}%"></span></div>
                </div>
                <div class="nx-intel-card">
                    <div class="nx-ic-top"><div class="nx-ic-icon"><i class="fa-solid fa-cpu"></i></div>
                        <div><div class="nx-ic-title">نواة UCI</div><div class="nx-ic-sub">${esc(eng.state || '—')}</div></div></div>
                    <div class="nx-ic-metric">${engines} <span style="font-size:12px;color:var(--nx-ink-3)">محرك</span></div>
                    <div class="nx-ic-sub" style="margin-top:6px">${agents} وكيل • ${connectors} موصل</div>
                </div>
                <div class="nx-intel-card">
                    <div class="nx-ic-top"><div class="nx-ic-icon"><i class="fa-solid fa-diagram-project"></i></div>
                        <div><div class="nx-ic-title">خط أنابيب الهندسة</div><div class="nx-ic-sub">Engineering Pipeline</div></div></div>
                    <div class="nx-ic-metric">${pipeline} <span style="font-size:12px;color:var(--nx-ink-3)">مرحلة</span></div>
                    <div class="nx-ic-bar"><span style="width:${pipeline ? Math.min(100, Math.round(pipeline * 4)) : 0}%"></span></div>
                </div>
                <div class="nx-intel-card">
                    <div class="nx-ic-top"><div class="nx-ic-icon"><i class="fa-solid fa-bolt"></i></div>
                        <div><div class="nx-ic-title">زمن الإقلاع</div><div class="nx-ic-sub">Boot Time</div></div></div>
                    <div class="nx-ic-metric">${bootMs != null ? bootMs + 'ms' : '—'}</div>
                    <div class="nx-ic-sub" style="margin-top:6px">تشغيل ذاتي كامل</div>
                </div>
            </div>`;

        const tiles = MODULES.map(m => `
            <div class="px-tile" onclick="PlatformKernel.open('${m.id}')" data-g="${m.group}">
                <div class="px-tile-icon"><i class="fa-solid ${m.icon}"></i></div>
                <div class="px-tile-title">${esc(m.name)}</div>
                <div class="px-tile-desc">${esc(m.desc || '')}</div>
            </div>`).join('');

        host.innerHTML = `
            <div class="px-hero">
                <div>
                    <div class="px-hero-greet">مرحباً، ${esc(user)}</div>
                    <div class="px-hero-sub">${esc(tenant)} • ${esc(role)} • NEXUS 2026 — منصة المؤسسات الموحّدة</div>
                </div>
                <div class="px-hero-clock" id="pxClock">--:--:--</div>
            </div>
            <div class="nx-section-title"><i class="fa-solid fa-gauge-high"></i> مؤشرات الأداء الحية <span class="nx-line"></span></div>
            <div class="px-kpis" style="margin-bottom:8px;">${kpiHtml}</div>
            ${intelHtml}
            <div class="px-search"><i class="fa-solid fa-magnifying-glass"></i><input id="pxSearch" placeholder="ابحث في الوحدات... (مخزون، صيدلية، مستخدمين، محاسبة...)"><i class="fa-solid fa-filter" id="pxFilterToggle" title="تصفية بالمجموعة"></i></div>
            <div class="px-filters" id="pxFilters">
                <button class="px-chip active" data-f="all">الكل</button>
                ${GROUPS.map(g => `<button class="px-chip" data-f="${g.id}"><i class="fa-solid ${g.icon}"></i> ${esc(g.name)}</button>`).join('')}
            </div>
            <div class="px-tiles" id="pxTiles">${tiles}</div>`;

        const clock = document.getElementById('pxClock');
        if (clock) {
            const tick = () => { const d = new Date(); clock.textContent = d.toLocaleTimeString('ar', { hour12: false }) + ' • ' + d.toLocaleDateString('ar', { weekday: 'long', day: 'numeric', month: 'long' }); };
            tick(); setInterval(tick, 1000);
        }
        const search = document.getElementById('pxSearch');
        if (search) search.addEventListener('input', () => {
            const q = (search.value || '').toLowerCase().trim();
            document.querySelectorAll('.px-tile').forEach(t => {
                t.style.display = !q || (t.textContent.toLowerCase().includes(q)) ? '' : 'none';
            });
        });
        const filterBtn = document.getElementById('pxFilterToggle');
        const filters = document.getElementById('pxFilters');
        if (filterBtn && filters) filterBtn.addEventListener('click', () => filters.classList.toggle('open'));
        document.querySelectorAll('.px-chip').forEach(chip => chip.addEventListener('click', () => {
            document.querySelectorAll('.px-chip').forEach(c => c.classList.remove('active'));
            chip.classList.add('active');
            const f = chip.getAttribute('data-f');
            document.querySelectorAll('.px-tile').forEach(t => {
                t.style.display = (f === 'all' || t.getAttribute('data-g') === f) ? '' : 'none';
            });
        }));

        PlatformKernel.refreshLiveStatus();
    }

    /* ---------- Command palette ---------- */
    const CommandPalette = {
        index: -1,
        items: [],
        open() {
            const b = document.getElementById('nxPalette');
            const inp = document.getElementById('nxPaletteInput');
            if (!b) return;
            b.classList.add('open');
            this.index = -1;
            if (inp) { inp.value = ''; this.render(''); setTimeout(() => inp.focus(), 30); }
            document.addEventListener('keydown', this._key = (e) => this.onKey(e));
        },
        close() {
            const b = document.getElementById('nxPalette');
            if (b) b.classList.remove('open');
            document.removeEventListener('keydown', this._key);
        },
        render(q) {
            const box = document.getElementById('nxPaletteResults');
            if (!box) return;
            q = (q || '').toLowerCase().trim();
            const groups = {};
            MODULES.forEach(m => {
                const hay = (m.name + ' ' + (m.desc || '')).toLowerCase();
                if (!q || hay.includes(q)) (groups[m.group] = groups[m.group] || []).push(m);
            });
            this.items = [];
            let html = '';
            const gnames = Object.fromEntries(GROUPS.map(g => [g.id, g]));
            Object.keys(groups).forEach(gid => {
                const g = gnames[gid];
                html += `<div class="nx-palette-group">${g ? g.name : gid}</div>`;
                groups[gid].forEach(m => {
                    html += `<div class="nx-palette-item" data-id="${m.id}">
                        <i class="fa-solid ${m.icon}"></i><span>${esc(m.name)}</span>
                        <span class="nx-pm-desc">${esc(m.desc || '')}</span></div>`;
                    this.items.push(m.id);
                });
            });
            if (!this.items.length) html = '<div class="nx-palette-empty">لا توجد نتائج مطابقة</div>';
            box.innerHTML = html;
            box.querySelectorAll('.nx-palette-item').forEach(el => {
                el.addEventListener('click', () => { const id = el.getAttribute('data-id'); CommandPalette.close(); PlatformKernel.open(id); });
            });
            this.index = -1;
        },
        onKey(e) {
            if (e.key === 'Escape') { this.close(); return; }
            const box = document.getElementById('nxPaletteResults');
            if (!box) return;
            const els = box.querySelectorAll('.nx-palette-item');
            if (e.key === 'ArrowDown') { e.preventDefault(); this.index = Math.min(this.index + 1, els.length - 1); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); this.index = Math.max(this.index - 1, 0); }
            else if (e.key === 'Enter') {
                e.preventDefault();
                const sel = els[this.index >= 0 ? this.index : 0];
                if (sel) { const id = sel.getAttribute('data-id'); this.close(); PlatformKernel.open(id); }
                return;
            } else return;
            els.forEach((el, i) => el.classList.toggle('active', i === this.index));
            if (els[this.index]) els[this.index].scrollIntoView({ block: 'nearest' });
        }
    };

    /* ---------- Live status pill ---------- */
    function refreshLiveStatus() {
        const txt = document.getElementById('pxLiveText');
        const dot = document.querySelector('#pxLiveStatus .nx-live-dot');
        if (!txt) return;
        PlatformAPI.get('/uci/status').then(uci => {
            const ok = uci && (uci.state === 'RUNNING' || uci.state === 'ACTIVE' || uci.state === 'BOOTED');
            txt.textContent = ok ? ('UCI ' + (uci.state || 'نشط') + ' • ' + (uci.engines_registered || 0) + ' محرك') : 'النظام يعمل';
            if (dot) dot.style.background = ok ? 'var(--nx-green)' : 'var(--nx-amber)';
        }).catch(() => { txt.textContent = 'النظام يعمل'; });
    }

    /* ---------- Kernel ---------- */
    const PlatformKernel = {
        async open(id) {
            if (window.playCyberSound) playCyberSound('click');
            const module = MODULES.find(m => m.id === id);
            if (!module) return;
            if (module.special === 'home') { this.home(); return; }
            const custom = window.NEXUS_WORKSPACES && window.NEXUS_WORKSPACES[id];
            if (custom) {
                const content = document.getElementById('platformContent');
                if (!content) return;
                this.setTitle(module.name, module.icon);
                document.querySelectorAll('.px-nav-item').forEach(n => n.classList.toggle('active', n.getAttribute('data-mod') === id));
                this.hideBuiltins();
                content.style.display = 'block';
                content.innerHTML = '';
                try { await custom(content, module); } catch (err) {
                    content.innerHTML = '<div class="px-empty px-error"><i class="fa-solid fa-triangle-exclamation"></i><div>تعذر تحميل الشاشة: ' + esc(err.message) + '</div></div>';
                }
                if (window.scrollTo) window.scrollTo({ top: 0, behavior: 'smooth' });
                return;
            }
            const content = document.getElementById('platformContent');
            if (!content) return;
            this.setTitle(module.name, module.icon);
            document.querySelectorAll('.px-nav-item').forEach(n => n.classList.toggle('active', n.getAttribute('data-mod') === id));
            this.hideBuiltins();
            content.style.display = 'block';
            loadModuleScreen(module, content);
            if (window.scrollTo) window.scrollTo({ top: 0, behavior: 'smooth' });
        },
        hideBuiltins() {
            document.querySelectorAll('.app-screen').forEach(s => s.classList.remove('active'));
            const home = document.getElementById('platformHome');
            if (home) home.style.display = 'none';
        },
        reload(id) {
            const module = MODULES.find(m => m.id === id);
            const content = document.getElementById('platformContent');
            if (module && content) loadModuleScreen(module, content);
        },
        home() {
            if (window.playCyberSound) playCyberSound('click');
            this.setTitle('مركز القيادة', 'fa-gauge-high');
            document.querySelectorAll('.px-nav-item').forEach(n => n.classList.toggle('active', n.getAttribute('data-mod') === 'dashboard'));
            document.querySelectorAll('.app-screen').forEach(s => s.classList.remove('active'));
            const content = document.getElementById('platformContent');
            const home = document.getElementById('platformHome');
            if (content) content.style.display = 'none';
            if (home) home.style.display = 'block';
            renderHome(home);
        },
        setTitle(name, icon) {
            const bc = document.getElementById('pxBreadcrumb');
            if (bc) {
                bc.innerHTML = `<span style="cursor:pointer" onclick="PlatformKernel.home()"><i class="fa-solid fa-gauge-high" style="color:var(--nx-cyan);margin-inline-end:6px"></i>مركز القيادة</span>`
                    + `<span class="sep">/</span><b>${esc(name)}</b>`;
            }
        },
        refreshLiveStatus,
        init() {
            const sidebar = document.getElementById('pxSidebar');
            if (!sidebar) return;
            let nav = '<div class="px-nav-group" data-g="__all"><div class="px-nav-group-title">المنصة</div>';
            nav += '<button class="px-nav-item active" data-mod="dashboard" onclick="PlatformKernel.home()"><i class="fa-solid fa-gauge-high"></i><span>مركز القيادة</span></button>';
            nav += '<button class="px-nav-item" data-mod="settings" onclick="openBrandSettings()"><i class="fa-solid fa-sliders"></i><span>الإعدادات العامة</span></button></div>';
            GROUPS.forEach(g => {
                const mods = MODULES.filter(m => m.group === g.id);
                if (!mods.length) return;
                nav += `<div class="px-nav-group"><div class="px-nav-group-title"><i class="fa-solid ${g.icon}"></i> ${g.name}</div>`;
                mods.forEach(m => {
                    nav += `<button class="px-nav-item" data-mod="${m.id}" onclick="PlatformKernel.open('${m.id}')"><i class="fa-solid ${m.icon}"></i><span>${esc(m.name)}</span></button>`;
                });
                nav += '</div>';
            });
            sidebar.innerHTML = nav;

            const trigger = document.getElementById('pxCmdTrigger');
            if (trigger) trigger.addEventListener('click', () => CommandPalette.open());
            const pinput = document.getElementById('nxPaletteInput');
            if (pinput) pinput.addEventListener('input', () => CommandPalette.render(pinput.value));
            const backdrop = document.getElementById('nxPalette');
            if (backdrop) backdrop.addEventListener('click', (e) => { if (e.target === backdrop) CommandPalette.close(); });
            document.addEventListener('keydown', (e) => {
                if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); CommandPalette.open(); }
            });
        }
    };

    /* ---------- Platform activation / deactivation ---------- */
    function activatePlatform() {
        const shell = document.getElementById('pxShell');
        const login = document.getElementById('loginScreen');
        const dash = document.getElementById('dashboard');
        if (login) login.style.display = 'none';
        if (dash) dash.classList.remove('active');
        if (shell) shell.style.display = 'block';
        PlatformKernel.init();
        PlatformKernel.home();
    }
    function deactivatePlatform() {
        const shell = document.getElementById('pxShell');
        if (shell) shell.style.display = 'none';
        document.querySelectorAll('.app-screen').forEach(s => s.classList.remove('active'));
    }

    window.PlatformAPI = PlatformAPI;
    window.PlatformKernel = PlatformKernel;
    window.PlatformKernel.Renderer = Renderer;
    window.activatePlatform = activatePlatform;
    window.deactivatePlatform = deactivatePlatform;
})();
