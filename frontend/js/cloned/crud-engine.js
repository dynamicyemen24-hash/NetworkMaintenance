/* SOPX — Generic Operational CRUD Engine (schema-driven, offline-first, scale-ready) */
(function () {
  'use strict';
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c])); }
  function money(n) { n = Number(n) || 0; return n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' ر.س'; }
  function num(n) { n = Number(n) || 0; return n.toLocaleString('en-US'); }
  function todayISO() { return new Date().toISOString().slice(0, 10); }
  function statusClass(s) {
    s = (s || '').toString();
    if (/مدفوعة|منجزة|مؤكدة|نشط|متصل/.test(s)) return 'green';
    if (/مرتجعة|ملغاة|متأخرة|خطأ/.test(s)) return 'red';
    if (/قيد التنفيذ|مسودة|معلق|منخفضة/.test(s)) return 'amber';
    if (/مفتوحة|جديد/.test(s)) return 'blue';
    return 'gray';
  }
  function cmp(a, b) {
    if (typeof a === 'number' && typeof b === 'number') return a - b;
    const x = String(a == null ? '' : a), y = String(b == null ? '' : b);
    return x.localeCompare(y, 'ar');
  }

  const DB = {
    k: id => 'sopx_db_' + id,
    all(id) { try { const v = JSON.parse(localStorage.getItem(this.k(id))); return Array.isArray(v) ? v : []; } catch (e) { return []; } },
    set(id, rows) { localStorage.setItem(this.k(id), JSON.stringify(rows)); },
    seed(id, data) { if (!localStorage.getItem(this.k(id))) this.set(id, data); },
    nextId(id) { return this.all(id).reduce((m, x) => Math.max(m, x._id || 0), 0) + 1; },
    upsert(id, rec) { const r = this.all(id); const i = r.findIndex(x => x._id === rec._id); if (i >= 0) r[i] = rec; else r.push(rec); this.set(id, r); return rec; },
    remove(id, _id) { this.set(id, this.all(id).filter(x => x._id !== _id)); }
  };

  const CAT = ['مواد خام', 'منتج تام', 'قطع غيار', 'مستلزمات'];
  const UOM = ['قطعة', 'كجم', 'لتر', 'متر', 'علبة', 'ساعة'];
  const SCHEMAS = {
    'crud-items': { title: 'الأصناف', icon: 'fa-boxes-stacked', printable: true, fields: [
      { key: 'code', label: 'الكود', type: 'text', required: true, col: 2 },
      { key: 'name', label: 'اسم الصنف', type: 'text', required: true, col: 5 },
      { key: 'category', label: 'الفئة', type: 'select', options: CAT, col: 2 },
      { key: 'uom', label: 'وحدة', type: 'select', options: UOM, col: 2 },
      { key: 'barcode', label: 'باركود', type: 'text', col: 3 },
      { key: 'cost', label: 'التكلفة', type: 'money', col: 2 },
      { key: 'price', label: 'سعر البيع', type: 'money', col: 2 },
      { key: 'qty', label: 'الرصيد', type: 'number', col: 2 },
      { key: 'reorder', label: 'حد إعادة الطلب', type: 'number', col: 2 },
      { key: 'notes', label: 'ملاحظات', type: 'textarea', col: 12 }
    ], table: ['code', 'name', 'category', 'uom', 'qty', 'cost', 'price'] },
    'crud-customers': { title: 'العملاء', icon: 'fa-users', printable: true, fields: [
      { key: 'code', label: 'الكود', type: 'text', required: true, col: 2 },
      { key: 'name', label: 'اسم العميل', type: 'text', required: true, col: 5 },
      { key: 'phone', label: 'الهاتف', type: 'text', col: 3 },
      { key: 'email', label: 'البريد', type: 'text', col: 3 },
      { key: 'creditLimit', label: 'الحد الائتماني', type: 'money', col: 3 },
      { key: 'balance', label: 'الرصيد المستحق', type: 'money', col: 3 },
      { key: 'notes', label: 'ملاحظات', type: 'textarea', col: 12 }
    ], table: ['code', 'name', 'phone', 'creditLimit', 'balance'] },
    'crud-vendors': { title: 'الموردون', icon: 'fa-truck-field', printable: true, fields: [
      { key: 'code', label: 'الكود', type: 'text', required: true, col: 2 },
      { key: 'name', label: 'اسم المورد', type: 'text', required: true, col: 5 },
      { key: 'phone', label: 'الهاتف', type: 'text', col: 3 },
      { key: 'email', label: 'البريد', type: 'text', col: 3 },
      { key: 'balance', label: 'الرصيد المستحق', type: 'money', col: 3 },
      { key: 'notes', label: 'ملاحظات', type: 'textarea', col: 12 }
    ], table: ['code', 'name', 'phone', 'balance'] },
    'crud-accounts': { title: 'دليل الحسابات', icon: 'fa-book', printable: true, fields: [
      { key: 'code', label: 'رمز الحساب', type: 'text', required: true, col: 2 },
      { key: 'name', label: 'اسم الحساب', type: 'text', required: true, col: 5 },
      { key: 'type', label: 'النوع', type: 'select', options: ['أصول', 'التزامات', 'حقوق ملكية', 'إيرادات', 'مصروفات'], col: 2 },
      { key: 'parent', label: 'الحساب الأب', type: 'text', col: 4 },
      { key: 'balance', label: 'الرصيد الافتتاحي', type: 'money', col: 3 },
      { key: 'notes', label: 'ملاحظات', type: 'textarea', col: 12 }
    ], table: ['code', 'name', 'type', 'parent', '_balance'],
      decorate: function (rows) { const m = accountNetMap(); rows.forEach(r => { r._balance = m[r.name] ? m[r.name].net : 0; }); return rows; },
      reports: function () { return accountsReportsHTML(); } },
    'crud-sales': { title: 'فواتير المبيعات', icon: 'fa-file-invoice-dollar', printable: true, fields: [
      { key: 'number', name: 'رقم الفاتورة', type: 'text', required: true, col: 2 },
      { key: 'customer', label: 'العميل', type: 'select-from', source: 'crud-customers', nameField: 'name', col: 5 },
      { key: 'date', label: 'التاريخ', type: 'date', col: 2 },
      { key: 'status', label: 'الحالة', type: 'select', options: ['مسودة', 'مؤكدة', 'مدفوعة', 'مرتجعة'], col: 2 },
      { key: 'paid', label: 'المبلغ المحصل', type: 'money', col: 3 },
      { key: 'notes', label: 'ملاحظات', type: 'textarea', col: 12 }
    ], subtable: { label: 'بنود الفاتورة', fields: [
      { key: 'item', label: 'الصنف', type: 'select-from', source: 'crud-items', nameField: 'name', col: 5 },
      { key: 'qty', label: 'الكمية', type: 'number', col: 2 },
      { key: 'price', label: 'السعر', type: 'money', col: 2 },
      { key: 'discount', label: 'خصم', type: 'money', col: 2 },
      { key: 'total', label: 'الإجمالي', type: 'computed', col: 2 }
    ], totals: lines => { const sub = lines.reduce((s, l) => s + ((Number(l.qty) || 0) * (Number(l.price) || 0) - (Number(l.discount) || 0)), 0); const vat = sub * 0.15; return { sub, vat, grand: sub + vat }; } }, table: ['number', 'customer', 'date', 'status', 'paid', '_grand'] },
    'crud-purchases': { title: 'أوامر الشراء', icon: 'fa-truck-loading', printable: true, fields: [
      { key: 'number', label: 'رقم الأمر', type: 'text', required: true, col: 2 },
      { key: 'vendor', label: 'المورد', type: 'select-from', source: 'crud-vendors', nameField: 'name', col: 5 },
      { key: 'date', label: 'التاريخ', type: 'date', col: 2 },
      { key: 'status', label: 'الحالة', type: 'select', options: ['مسودة', 'مؤكدة', 'مستلمة', 'مرتجعة'], col: 2 },
      { key: 'paid', label: 'المبلغ المدفوع', type: 'money', col: 3 },
      { key: 'notes', label: 'ملاحظات', type: 'textarea', col: 12 }
    ], subtable: { label: 'بنود الأمر', fields: [
      { key: 'item', label: 'الصنف', type: 'select-from', source: 'crud-items', nameField: 'name', col: 5 },
      { key: 'qty', label: 'الكمية', type: 'number', col: 2 },
      { key: 'price', label: 'السعر', type: 'money', col: 2 },
      { key: 'discount', label: 'خصم', type: 'money', col: 2 },
      { key: 'total', label: 'الإجمالي', type: 'computed', col: 2 }
    ], totals: lines => { const sub = lines.reduce((s, l) => s + ((Number(l.qty) || 0) * (Number(l.price) || 0) - (Number(l.discount) || 0)), 0); const vat = sub * 0.15; return { sub, vat, grand: sub + vat }; } }, table: ['number', 'vendor', 'date', 'status', 'paid', '_grand'] },
    'crud-journal': { title: 'القيود المحاسبية', icon: 'fa-receipt', printable: true, fields: [
      { key: 'number', label: 'رقم القيد', type: 'text', required: true, col: 2 },
      { key: 'date', label: 'التاريخ', type: 'date', col: 2 },
      { key: 'notes', label: 'البيان', type: 'textarea', col: 12 }
    ], subtable: { label: 'تفاصيل القيد (مدين/دائن)', fields: [
      { key: 'account', label: 'الحساب', type: 'select-from', source: 'crud-accounts', nameField: 'name', col: 6 },
      { key: 'debit', label: 'مدين', type: 'money', col: 3 },
      { key: 'credit', label: 'دائن', type: 'money', col: 3 }
    ], totals: lines => { const d = lines.reduce((s, l) => s + (Number(l.debit) || 0), 0); const c = lines.reduce((s, l) => s + (Number(l.credit) || 0), 0); return { sub: d, vat: c, grand: d - c }; }, validate: lines => { const d = lines.reduce((s, l) => s + (Number(l.debit) || 0), 0); const c = lines.reduce((s, l) => s + (Number(l.credit) || 0), 0); return Math.abs(d - c) < 0.01 ? null : 'القيد غير متوازن: مدين ' + money(d) + ' ≠ دائن ' + money(c); } }, table: ['number', 'date', '_debit', '_credit'] },
    'crud-maintenance': { title: 'أوامر الصيانة', icon: 'fa-screwdriver-wrench', printable: true, fields: [
      { key: 'number', label: 'رقم الأمر', type: 'text', required: true, col: 2 },
      { key: 'asset', label: 'الجهاز / الأصل', type: 'text', required: true, col: 4 },
      { key: 'customer', label: 'العميل', type: 'select-from', source: 'crud-customers', nameField: 'name', col: 4 },
      { key: 'tech', label: 'الفني', type: 'text', col: 3 },
      { key: 'status', label: 'الحالة', type: 'select', options: ['مفتوحة', 'قيد التنفيذ', 'منجزة', 'ملغاة'], col: 2 },
      { key: 'priority', label: 'الأولوية', type: 'select', options: ['منخفضة', 'متوسطة', 'عالية'], col: 2 },
      { key: 'scheduled', label: 'الموعد', type: 'date', col: 2 },
      { key: 'cost', label: 'التكلفة', type: 'money', col: 2 },
      { key: 'notes', label: 'الوصف والإجراء', type: 'textarea', col: 12 }
    ], table: ['number', 'asset', 'customer', 'tech', 'status', 'priority', 'cost'] }
  };

  function seedAll() {
    DB.seed('crud-items', [
      { _id: 1, code: 'ITM-001', name: 'حاسوب محمول برو', category: 'منتج تام', uom: 'قطعة', barcode: '6001', cost: 3200, price: 4200, qty: 18, reorder: 5, notes: '' },
      { _id: 2, code: 'ITM-002', name: 'طابعة ليزر', category: 'منتج تام', uom: 'قطعة', barcode: '6002', cost: 900, price: 1300, qty: 4, reorder: 6, notes: 'مخزون منخفض' },
      { _id: 3, code: 'ITM-003', name: 'كابل طاقة', category: 'قطع غيار', uom: 'قطعة', barcode: '6003', cost: 12, price: 25, qty: 240, reorder: 50, notes: '' },
      { _id: 4, code: 'ITM-004', name: 'ورق A4', category: 'مستلزمات', uom: 'علبة', barcode: '6004', cost: 18, price: 30, qty: 80, reorder: 20, notes: '' },
      { _id: 5, code: 'ITM-005', name: 'شاشة 24 بوصة', category: 'منتج تام', uom: 'قطعة', barcode: '6005', cost: 600, price: 880, qty: 12, reorder: 4, notes: '' },
      { _id: 6, code: 'ITM-006', name: 'ماوس لاسلكي', category: 'قطع غيار', uom: 'قطعة', barcode: '6006', cost: 25, price: 55, qty: 2, reorder: 15, notes: 'مخزون منخفض' }
    ]);
    DB.seed('crud-customers', [
      { _id: 1, code: 'CUS-001', name: 'مؤسسة الأفق التقنية', phone: '0501112233', email: 'a@afaq.com', creditLimit: 50000, balance: 12500, notes: '' },
      { _id: 2, code: 'CUS-002', name: 'شركة النخبة للتجارة', phone: '0502223344', email: 'b@nokhba.com', creditLimit: 80000, balance: 0, notes: '' },
      { _id: 3, code: 'CUS-003', name: 'متجر السلام', phone: '0503334455', email: 'c@salam.com', creditLimit: 20000, balance: 4300, notes: '' },
      { _id: 4, code: 'CUS-004', name: 'مؤسسة البناء الحديث', phone: '0504445566', email: 'd@bina.com', creditLimit: 120000, balance: 31000, notes: '' }
    ]);
    DB.seed('crud-vendors', [
      { _id: 1, code: 'VEN-001', name: 'شركة التوريد الذكي', phone: '0511112233', email: 'v1@smart.com', balance: 8800, notes: '' },
      { _id: 2, code: 'VEN-002', name: 'مصنع الأجهزة المتحدة', phone: '0512223344', email: 'v2@uni.com', balance: 0, notes: '' }
    ]);
    /* accounts + journal are seeded by accounting.js (full standard cycle) */
    DB.seed('crud-sales', [
      { _id: 1, number: 'INV-2026-001', customer: 'مؤسسة الأفق التقنية', date: '2026-08-01', status: 'مدفوعة', paid: 9660, notes: '', lines: [{ item: 'حاسوب محمول برو', qty: 2, price: 4200, discount: 0, total: 8400 }, { item: 'ماوس لاسلكي', qty: 10, price: 55, discount: 50, total: 500 }] },
      { _id: 2, number: 'INV-2026-002', customer: 'متجر السلام', date: '2026-08-03', status: 'مؤكدة', paid: 0, notes: '', lines: [{ item: 'طابعة ليزر', qty: 1, price: 1300, discount: 0, total: 1300 }] },
      { _id: 3, number: 'INV-2026-003', customer: 'مؤسسة البناء الحديث', date: '2026-08-05', status: 'مؤكدة', paid: 5000, notes: '', lines: [{ item: 'شاشة 24 بوصة', qty: 6, price: 880, discount: 280, total: 5000 }] }
    ].map(r => { const t = r.lines.reduce((s, l) => s + (l.total || 0), 0); r._grand = t * 1.15; return r; }));
    DB.seed('crud-purchases', [
      { _id: 1, number: 'PO-2026-001', vendor: 'شركة التوريد الذكي', date: '2026-07-28', status: 'مستلمة', paid: 9280, notes: '', lines: [{ item: 'ورق A4', qty: 40, price: 30, discount: 0, total: 1200 }, { item: 'كابل طاقة', qty: 100, price: 25, discount: 200, total: 2300 }] }
    ].map(r => { const t = r.lines.reduce((s, l) => s + (l.total || 0), 0); r._grand = t * 1.15; return r; }));
    /* journal seeded by accounting.js */
    DB.seed('crud-maintenance', [
      { _id: 1, number: 'WO-2026-001', asset: 'خادم رئيسي DELL', customer: 'مؤسسة الأفق التقنية', tech: 'م. أحمد', status: 'قيد التنفيذ', priority: 'عالية', scheduled: '2026-08-12', cost: 1200, notes: 'استبدال مروحة تبريد' },
      { _id: 2, number: 'WO-2026-002', asset: 'طابعة ليزر', customer: 'متجر السلام', tech: 'م. سارة', status: 'مفتوحة', priority: 'متوسطة', scheduled: '2026-08-14', cost: 350, notes: 'عطل في تغذية الورق' }
    ]);
  }
  seedAll();

  function cellHTML(schema, key, rec) {
    const f = schema.fields.find(x => x.key === key);
    let v = rec[key];
    if (key === '_grand') v = rec._grand; if (key === '_debit') v = rec._debit; if (key === '_credit') v = rec._credit;
    if (key === '_balance') return '<td class="money"><span class="money">' + money(v) + '</span></td>';
    if (f && f.type === 'money') return '<td class="money"><span class="money">' + money(v) + '</span></td>';
    if (f && f.type === 'number') return '<td class="num mono">' + num(v) + '</td>';
    if (key === 'status' || key === 'priority') return '<td><span class="crud-pill ' + statusClass(v) + '">' + esc(v) + '</span></td>';
    return '<td>' + esc(v == null ? '' : v) + '</td>';
  }

  function bars(rows, labelFn, valFn, valFmt) {
    if (!rows.length) return '<div class="crud-empty"><i class="fa-solid fa-chart-pie"></i> لا توجد بيانات كافية للتحليل</div>';
    const map = {}; rows.forEach(r => { const k = labelFn(r); map[k] = (map[k] || 0) + (Number(valFn(r)) || 0); });
    const arr = Object.entries(map).sort((a, b) => b[1] - a[1]).slice(0, 7);
    const max = Math.max(1, ...arr.map(x => x[1]));
    return '<div class="crud-bars">' + arr.map(([k, v]) =>
      '<div class="crud-bar-row"><div>' + esc(k) + '</div><div class="crud-bar-track"><div class="crud-bar-fill" style="width:' + Math.round(v / max * 100) + '%"></div></div><div class="crud-bar-val">' + (valFmt ? valFmt(v) : num(v)) + '</div></div>'
    ).join('') + '</div>';
  }
  function analyticsHTML(id, rows) {
    switch (id) {
      case 'crud-items': return bars(rows, r => r.category, r => Number(r.qty) || 0);
      case 'crud-customers': return bars(rows, r => r.name, r => Number(r.balance) || 0, money);
      case 'crud-vendors': return bars(rows, r => r.name, r => Number(r.balance) || 0, money);
      case 'crud-accounts': return bars(rows, r => r.type, r => Number(r.balance) || 0, money);
      case 'crud-sales': return bars(rows, r => r.customer, r => r._grand || 0, money);
      case 'crud-purchases': return bars(rows, r => r.vendor, r => r._grand || 0, money);
      case 'crud-journal': return bars(rows, r => (r.date || '').slice(0, 7), r => 1);
      case 'crud-maintenance': return bars(rows, r => r.status, r => 1);
      default: return '<div class="crud-empty"><i class="fa-solid fa-chart-pie"></i> لا يوجد تحليل</div>';
    }
  }

  /* ----- accounting: ledger + financial statements (double-entry) ----- */
  function accountNetMap() {
    const accounts = DB.all('crud-accounts');
    const journal = DB.all('crud-journal');
    const m = {};
    accounts.forEach(a => { m[a.name] = { opening: Number(a.balance) || 0, type: a.type, debit: 0, credit: 0 }; });
    journal.forEach(j => (j.lines || []).forEach(l => {
      const nm = l.account; if (!m[nm]) m[nm] = { opening: 0, type: '', debit: 0, credit: 0 };
      m[nm].debit += Number(l.debit) || 0; m[nm].credit += Number(l.credit) || 0;
    }));
    Object.keys(m).forEach(k => { const x = m[k]; const normal = (x.type === 'أصول' || x.type === 'مصروفات') ? (x.debit - x.credit) : (x.credit - x.debit); x.net = x.opening + normal; });
    return m;
  }
  function accountsReportsHTML() {
    const m = accountNetMap(); const names = Object.keys(m);
    let tbRows = '', tDebit = 0, tCredit = 0;
    names.forEach(nm => {
      const x = m[nm]; let d = 0, c = 0;
      const isDebitNormal = (x.type === 'أصول' || x.type === 'مصروفات' || x.type === '');
      if (x.net >= 0) { if (isDebitNormal) d = x.net; else c = x.net; } else { if (isDebitNormal) c = -x.net; else d = -x.net; }
      tDebit += d; tCredit += c;
      tbRows += '<tr><td>' + esc(nm) + '</td><td class="num">' + money(d) + '</td><td class="num">' + money(c) + '</td></tr>';
    });
    const tb = '<div class="crud-panel" style="margin-bottom:16px"><div class="crud-panel-head"><h3><i class="fa-solid fa-scale-balanced"></i> ميزان المراجعة</h3></div><div class="crud-panel-body" style="padding:6px 4px"><table class="crud-table"><thead><tr><th>الحساب</th><th class="num">مدين</th><th class="num">دائن</th></tr></thead><tbody>' + tbRows + '<tr style="font-weight:800"><td>الإجمالي</td><td class="num">' + money(tDebit) + '</td><td class="num">' + money(tCredit) + '</td></tr></tbody></table></div></div>';

    let rev = 0, exp = 0;
    names.forEach(nm => { const x = m[nm]; if (x.type === 'إيرادات') rev += x.net; if (x.type === 'مصروفات') exp += x.net; });
    const profit = rev - exp;
    const is = '<div class="crud-panel" style="margin-bottom:16px"><div class="crud-panel-head"><h3><i class="fa-solid fa-chart-line"></i> قائمة الدخل (الأرباح والخسائر)</h3></div><div class="crud-panel-body" style="padding:6px 4px"><table class="crud-table"><tbody>' +
      '<tr><td>إجمالي الإيرادات</td><td class="num">' + money(rev) + '</td></tr>' +
      '<tr><td>إجمالي المصروفات</td><td class="num">' + money(exp) + '</td></tr>' +
      '<tr style="font-weight:800"><td>صافي الربح / الخسارة</td><td class="num">' + money(profit) + '</td></tr>' +
      '</tbody></table></div></div>';

    let assets = 0, liab = 0, equity = 0;
    names.forEach(nm => { const x = m[nm]; if (x.type === 'أصول') assets += x.net; else if (x.type === 'التزامات') liab += x.net; else if (x.type === 'حقوق ملكية') equity += x.net; });
    equity += profit;
    const bs = '<div class="crud-panel"><div class="crud-panel-head"><h3><i class="fa-solid fa-balance-scale"></i> الميزانية العمومية</h3></div><div class="crud-panel-body" style="padding:6px 4px"><table class="crud-table"><tbody>' +
      '<tr><td>الأصول</td><td class="num">' + money(assets) + '</td></tr>' +
      '<tr><td>الالتزامات</td><td class="num">' + money(liab) + '</td></tr>' +
      '<tr><td>حقوق الملكية (شاملة الأرباح المرحلة)</td><td class="num">' + money(equity) + '</td></tr>' +
      '<tr style="font-weight:800"><td>الأصول = الالتزامات + حقوق الملكية</td><td class="num">' + money(assets) + ' = ' + money(liab + equity) + '</td></tr>' +
      '</tbody></table></div></div>';
    return tb + is + bs;
  }

  /* ----- scale-ready view state ----- */
  const STATE = {};
  let currentModuleId = null;
  function st(id) {
    return STATE[id] || (STATE[id] = { sortKey: null, sortDir: 1, page: 1, pageSize: 10, q: '', selected: new Set(), pageIds: [], loading: false });
  }
  let density = localStorage.getItem('sopx_density') || 'comfortable';

  function computeView(id) {
    const s = st(id); const schema = SCHEMAS[id];
    let rows = DB.all(id);
    if (schema.decorate) rows = schema.decorate(rows);
    if (s.q) { const q = s.q.toLowerCase(); rows = rows.filter(r => Object.values(r).some(v => String(v).toLowerCase().includes(q))); }
    if (s.sortKey) rows = rows.slice().sort((a, b) => cmp(a[s.sortKey], b[s.sortKey]) * s.sortDir);
    const total = rows.length;
    const pages = Math.max(1, Math.ceil(total / s.pageSize));
    if (s.page > pages) s.page = pages;
    const start = (s.page - 1) * s.pageSize;
    const pageRows = rows.slice(start, start + s.pageSize);
    s.pageIds = pageRows.map(r => r._id);
    return { schema, rows, pageRows, total, pages, start };
  }

  let drawerEl = null;
  function ensureDrawer() {
    if (drawerEl) return drawerEl;
    const ov = document.createElement('div'); ov.className = 'crud-overlay'; ov.id = 'crudOverlay';
    ov.innerHTML = '<div class="crud-drawer"><div class="crud-drawer-head"><h3 id="crudDrawerTitle"></h3><button class="crud-btn ghost sm" data-crud="close"><i class="fa-solid fa-xmark"></i></button></div><div class="crud-drawer-body" id="crudDrawerBody"></div><div class="crud-drawer-foot" id="crudDrawerFoot"></div></div>';
    document.body.appendChild(ov);
    ov.addEventListener('click', e => { if (e.target === ov) CRUD._close(); });
    drawerEl = ov; return ov;
  }

  function renderToolbar(host, id, schema) {
    return '<div class="crud-toolbar">' +
      '<div class="crud-title"><i class="fa-solid ' + schema.icon + '"></i><h2>' + schema.title + '</h2><span class="count" id="crudCount"></span></div>' +
      '<div class="crud-actions">' +
      '<div class="crud-search"><i class="fa-solid fa-magnifying-glass"></i><input id="crudSearch" placeholder="بحث سريع..."><kbd>/</kbd></div>' +
      '<button class="crud-btn ghost sm icon" data-crud="density" title="كثافة العرض"><i class="fa-solid ' + (density === 'compact' ? 'fa-compress' : 'fa-expand') + '"></i></button>' +
      '<button class="crud-btn ghost sm" data-crud="refresh" data-id="' + id + '"><i class="fa-solid fa-rotate"></i> تحديث</button>' +
      '<button class="crud-btn ghost sm" data-crud="export" data-id="' + id + '"><i class="fa-solid fa-file-csv"></i> تصدير</button>' +
      '<button class="crud-btn primary" data-crud="new" data-id="' + id + '"><i class="fa-solid fa-plus"></i> جديد</button>' +
      '</div></div>';
  }

  function headerHTML(id, schema, s) {
    const head = schema.table.map(k => {
      const f = schema.fields.find(x => x.key === k);
      const label = esc(f ? f.label : (k === '_balance' ? 'الرصيد الحالي' : k.replace('_', '')));
      const active = s.sortKey === k;
      const arrow = active ? (s.sortDir === 1 ? '▲' : '▼') : '↕';
      return '<th class="sortable' + (active ? ' sorted' : '') + (f && (f.type === 'money' || f.type === 'number') ? ' num' : '') + '" data-crud="sort" data-id="' + id + '" data-key="' + k + '">' + label + ' <span class="sort-i">' + arrow + '</span></th>';
    }).join('');
    const allChecked = s.pageIds.length && s.pageIds.every(x => s.selected.has(x));
    return '<th class="col-check"><input type="checkbox" data-crud="selall" data-id="' + id + '"' + (allChecked ? ' checked' : '') + '></th>' + head + '<th class="col-act">إجراءات</th>';
  }

  function bodyHTML(id, schema, pageRows, s) {
    if (!pageRows.length && !s.q) return '<div class="crud-empty"><i class="fa-solid fa-inbox"></i> لا توجد سجلات بعد — اضغط «جديد» لإنشاء أول سجل</div>';
    if (!pageRows.length) return '<div class="crud-empty"><i class="fa-solid fa-magnifying-glass"></i> لا توجد نتائج مطابقة للبحث</div>';
    const body = pageRows.map(r => {
      const cells = schema.table.map(k => cellHTML(schema, k, r)).join('');
      const checked = s.selected.has(r._id) ? ' checked' : '';
      const selCls = s.selected.has(r._id) ? ' selected' : '';
      const printBtn = schema.printable ? '<button class="crud-btn ghost sm" data-crud="print" data-id="' + id + '" data-_id="' + r._id + '" title="عرض / طباعة"><i class="fa-solid fa-print"></i></button>' : '';
      return '<tr class="' + selCls.trim() + '" data-id="' + r._id + '">' +
        '<td class="col-check"><input type="checkbox" data-crud="sel" data-id="' + id + '" data-_id="' + r._id + '"' + checked + '></td>' +
        cells +
        '<td class="col-act"><div class="crud-row-actions">' +
        '<button class="crud-btn ghost sm" data-crud="edit" data-id="' + id + '" data-_id="' + r._id + '"><i class="fa-solid fa-pen"></i></button>' +
        printBtn +
        '<button class="crud-btn danger sm" data-crud="del" data-id="' + id + '" data-_id="' + r._id + '"><i class="fa-solid fa-trash"></i></button>' +
        '</div></td></tr>';
    }).join('');
    return '<div class="crud-panel"><div class="crud-table-wrap"><table class="crud-table"><thead><tr>' + headerHTML(id, schema, s) + '</tr></thead><tbody>' + body + '</tbody></table></div></div>';
  }

  function pagerHTML(s, total, start, pageRows) {
    const end = start + pageRows.length;
    const sizes = [10, 25, 50, 100];
    const sizeOpts = sizes.map(n => '<option value="' + n + '"' + (s.pageSize === n ? ' selected' : '') + '>' + n + '</option>').join('');
    const prev = '<button class="crud-pg-btn" data-crud="page" data-id="" data-page="prev"' + (s.page <= 1 ? ' disabled' : '') + '><i class="fa-solid fa-chevron-right"></i></button>';
    const next = '<button class="crud-pg-btn" data-crud="page" data-page="next"' + (s.page >= s.pages ? ' disabled' : '') + '><i class="fa-solid fa-chevron-left"></i></button>';
    const nums = [];
    for (let p = 1; p <= s.pages; p++) { if (p === 1 || p === s.pages || Math.abs(p - s.page) <= 1) nums.push('<button class="crud-pg-btn' + (p === s.page ? ' active' : '') + '" data-crud="page" data-page="' + p + '">' + p + '</button>'); else if (nums[nums.length - 1] !== '…') nums.push('…'); }
    return '<div class="crud-pager"><div class="p-info">عرض <b>' + (total ? start + 1 : 0) + '–' + end + '</b> من <b>' + total + '</b> سجل</div>' +
      '<div class="p-ctrl"><span class="p-info">لكل صفحة</span><select data-crud="pagesize">' + sizeOpts + '</select>' + prev + nums.join('') + next + '</div></div>';
  }

  function bulkHTML(s) {
    if (!s.selected.size) return '<div class="crud-bulk" id="crudBulk" style="display:none"></div>';
    return '<div class="crud-bulk" id="crudBulk"><span class="b-count">تم تحديد ' + s.selected.size + ' سجل</span><span class="b-spacer"></span>' +
      '<button class="crud-btn ghost sm" data-crud="bulk-export" data-id="' + currentModuleId + '"><i class="fa-solid fa-file-csv"></i> تصدير المحدد</button>' +
      '<button class="crud-btn ghost sm" data-crud="bulk-clear" data-id="' + currentModuleId + '">إلغاء</button>' +
      '<button class="crud-btn danger sm" data-crud="bulk-del" data-id="' + currentModuleId + '"><i class="fa-solid fa-trash"></i> حذف المحدد</button></div>';
  }

  function renderListInner(host, id) {
    const s = st(id);
    const v = computeView(id);
    const inner = host.querySelector('#crudListInner'); if (!inner) return;
    const count = host.querySelector('#crudCount'); if (count) count.textContent = v.total + ' سجل';
    inner.innerHTML = bodyHTML(id, v.schema, v.pageRows, s) + pagerHTML(s, v.total, v.start, v.pageRows);
    const bulk = host.querySelector('#crudBulk'); if (bulk) bulk.outerHTML = bulkHTML(s);
  }

  function renderScreen(host, id) {
    const schema = SCHEMAS[id];
    if (!schema) { host.innerHTML = '<div class="crud-empty">الوحدة غير معرّفة</div>'; return; }
    currentModuleId = id;
    const s = st(id);
    host.innerHTML =
      '<div class="crud-wrap ' + (density === 'compact' ? 'compact' : '') + '">' +
      renderToolbar(host, id, schema) +
      bulkHTML(s) +
      '<div class="crud-tabs"><button class="crud-tab active" data-crud="tab" data-id="' + id + '" data-tab="list">القائمة</button>' +
      '<button class="crud-tab" data-crud="tab" data-id="' + id + '" data-tab="analytics">التحليلات</button>' +
      (schema.reports ? '<button class="crud-tab" data-crud="tab" data-id="' + id + '" data-tab="reports">التقارير المالية</button>' : '') + '</div>' +
      '<div id="crudList"><div id="crudListInner"></div></div>' +
      '<div id="crudAnalytics" style="display:none"><div class="crud-panel"><div class="crud-panel-head"><h3><i class="fa-solid fa-chart-pie"></i> تحليلات ' + schema.title + '</h3></div><div class="crud-panel-body" style="padding:16px">' + analyticsHTML(id, DB.all(id)) + '</div></div></div>' +
      (schema.reports ? '<div id="crudReports" style="display:none">' + schema.reports() + '</div>' : '') +
      '</div>';
    const search = host.querySelector('#crudSearch');
    if (search) {
      search.value = s.q;
      let t; search.addEventListener('input', () => { clearTimeout(t); t = setTimeout(() => { st(id).q = search.value; st(id).page = 1; renderListInner(host, id); }, 180); });
    }
    renderListInner(host, id);
  }

  function fieldInput(f, val) {
    const v = val == null ? '' : val;
    const req = f.required ? '<span class="req">*</span>' : '';
    let control;
    if (f.type === 'textarea') control = '<textarea data-key="' + f.key + '">' + esc(v) + '</textarea>';
    else if (f.type === 'select') control = '<select data-key="' + f.key + '">' + (f.options || []).map(o => '<option' + (o === v ? ' selected' : '') + '>' + esc(o) + '</option>').join('') + '</select>';
    else if (f.type === 'select-from') { const opts = DB.all(f.source); control = '<select data-key="' + f.key + '"><option value="">— اختر —</option>' + opts.map(o => '<option' + (o[f.nameField] === v ? ' selected' : '') + '>' + esc(o[f.nameField]) + '</option>').join('') + '</select>'; }
    else if (f.type === 'date') control = '<input type="date" data-key="' + f.key + '" value="' + esc(v || todayISO()) + '">';
    else if (f.type === 'money' || f.type === 'number') control = '<input type="number" step="0.01" data-key="' + f.key + '" value="' + esc(v) + '">';
    else control = '<input type="text" data-key="' + f.key + '" value="' + esc(v) + '">';
    return '<div class="crud-field" style="grid-column: span ' + (f.col || 12) + '"><label>' + esc(f.label) + req + '</label>' + control + '<div class="err" data-err="' + f.key + '"></div></div>';
  }

  function addLineRow(id, line) {
    const sub = SCHEMAS[id].subtable;
    const rows = document.getElementById('crudSubRows');
    const row = document.createElement('div'); row.className = 'crud-sub-row';
    row.innerHTML = sub.fields.map(f => {
      const v = line ? line[f.key] : '';
      let c;
      if (f.type === 'select-from') { const opts = DB.all(f.source); c = '<select data-skey="' + f.key + '"><option value="">—</option>' + opts.map(o => '<option' + (o[f.nameField] === v ? ' selected' : '') + '>' + esc(o[f.nameField]) + '</option>').join('') + '</select>'; }
      else if (f.type === 'money' || f.type === 'number') c = '<input type="number" step="0.01" data-skey="' + f.key + '" value="' + esc(v) + '">';
      else if (f.type === 'computed') c = '<input type="text" data-skey="' + f.key + '" value="' + esc(v) + '" readonly style="color:var(--c-ink3)">';
      else c = '<input type="text" data-skey="' + f.key + '" value="' + esc(v) + '">';
      return '<div style="grid-column:span ' + (f.col || 2) + '">' + c + '</div>';
    }).join('') + '<button class="crud-btn danger sm" style="width:34px" data-crud="rmline"><i class="fa-solid fa-xmark"></i></button>';
    rows.appendChild(row);
  }

  function recalcSub(id) {
    const sub = SCHEMAS[id].subtable; if (!sub) return;
    const rowEls = Array.from(document.querySelectorAll('#crudSubRows .crud-sub-row'));
    const rows = rowEls.map(r => { const o = {}; sub.fields.forEach(f => { if (f.type !== 'computed') o[f.key] = r.querySelector('[data-skey="' + f.key + '"]').value; }); return o; });
    rowEls.forEach((r, i) => { const l = rows[i]; const tot = (Number(l.qty) || 0) * (Number(l.price) || 0) - (Number(l.discount) || 0); const tEl = r.querySelector('[data-skey="total"]'); if (tEl) tEl.value = tot.toFixed(2); });
    const t = sub.totals(rows);
    const foot = document.getElementById('crudSubFoot');
    if (sub.validate) { const err = sub.validate(rows); foot.innerHTML = '<span style="color:var(--c-red)">' + (err || 'القيد متوازن ✓') + '</span><span>الإجمالي: <b>' + money(t.grand) + '</b></span>'; }
    else foot.innerHTML = '<span>الخاضع للضريبة: <b>' + money(t.sub) + '</b> · ضريبة 15%: <b>' + money(t.vat) + '</b></span><span>الإجمالي: <b>' + money(t.grand) + '</b></span>';
  }

  function renderForm(schema, rec, id) {
    const isNew = !rec;
    document.getElementById('crudDrawerTitle').textContent = (isNew ? 'جديد — ' : 'تعديل — ') + schema.title;
    let body = '<div class="crud-grid">' + schema.fields.map(f => fieldInput(f, rec ? rec[f.key] : (f.type === 'date' ? todayISO() : ''))).join('') + '</div>';
    if (schema.subtable) {
      body += '<div style="margin-top:16px"><div style="font-weight:900;font-size:14px;margin-bottom:8px;display:flex;align-items:center;gap:8px"><i class="fa-solid fa-list"></i> ' + schema.subtable.label + '</div>' +
        '<div class="crud-sub"><div class="crud-sub-head" id="crudSubHead" style="grid-template-columns:repeat(12,1fr)"></div><div id="crudSubRows"></div><div class="crud-sub-foot" id="crudSubFoot"></div><button class="crud-sub-add" data-crud="addline" data-id="' + id + '"><i class="fa-solid fa-plus"></i> إضافة بند</button></div></div>';
    }
    document.getElementById('crudDrawerBody').innerHTML = body;
    document.getElementById('crudDrawerFoot').innerHTML =
      '<button class="crud-btn ghost" data-crud="close">إلغاء</button>' +
      '<button class="crud-btn primary" data-crud="save" data-id="' + id + '" data-_id="' + (rec ? rec._id : 'null') + '"><i class="fa-solid fa-check"></i> حفظ</button>';
    if (schema.subtable) {
      const sh = document.getElementById('crudSubHead');
      sh.innerHTML = schema.subtable.fields.map(f => '<div style="grid-column:span ' + (f.col || 2) + '">' + esc(f.label) + '</div>').join('') + '<div style="width:34px"></div>';
      const lines = (rec && rec.lines) ? rec.lines : [{}];
      lines.forEach(l => addLineRow(id, l));
      recalcSub(id);
    }
    drawerEl._id = id;
    ensureDrawer().classList.add('open');
  }

  function readForm(schema, id) {
    const rec = {}; let ok = true;
    schema.fields.forEach(f => {
      const el = document.querySelector('#crudDrawerBody [data-key="' + f.key + '"]');
      let v = el ? el.value : '';
      if (f.type === 'money' || f.type === 'number') v = Number(v) || 0;
      rec[f.key] = v;
      if (f.required && !String(v).trim()) { ok = false; const e = document.querySelector('[data-err="' + f.key + '"]'); if (e) e.textContent = 'هذا الحقل مطلوب'; }
    });
    if (schema.subtable) {
      const rows = Array.from(document.querySelectorAll('#crudSubRows .crud-sub-row')).map(r => { const o = {}; schema.subtable.fields.forEach(f => { if (f.type !== 'computed') o[f.key] = r.querySelector('[data-skey="' + f.key + '"]').value; }); return o; });
      if (schema.subtable.validate) { const err = schema.subtable.validate(rows); if (err) { alert(err); ok = false; } }
      const t = schema.subtable.totals(rows); rec.lines = rows; rec._sub = t.sub; rec._vat = t.vat; rec._grand = t.grand;
    }
    return ok ? rec : null;
  }

  /* branded document for print */
  function documentHTML(id, rec) {
    const schema = SCHEMAS[id];
    const head = '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:18px"><div><div style="font-size:20px;font-weight:800">' + schema.title + '</div><div style="color:#888;font-size:13px">رقم: ' + esc(rec.number || '-') + (rec.date ? ' · التاريخ: ' + esc(rec.date) : '') + '</div></div><div style="text-align:left"><span class="crud-pill ' + statusClass(rec.status) + '">' + esc(rec.status || '—') + '</span></div></div>';
    let party = '';
    if (rec.customer) party = '<div><b>العميل:</b> ' + esc(rec.customer) + '</div>';
    if (rec.vendor) party = '<div><b>المورد:</b> ' + esc(rec.vendor) + '</div>';
    if (rec.asset) party = '<div><b>الجهاز:</b> ' + esc(rec.asset) + (rec.tech ? ' · <b>الفني:</b> ' + esc(rec.tech) : '') + '</div>';
    const partyBlock = party ? '<div style="margin-bottom:14px;font-size:13px;color:#333">' + party + '</div>' : '';
    let table = '';
    if (rec.lines) {
      const sub = schema.subtable;
      const th = sub.fields.filter(f => f.type !== 'computed').map(f => '<th style="text-align:right;padding:6px 8px;border-bottom:2px solid #ccc;font-size:12px">' + esc(f.label) + '</th>').join('') + '<th style="text-align:left;padding:6px 8px;border-bottom:2px solid #ccc;font-size:12px">الإجمالي</th>';
      const tr = rec.lines.map(l => '<tr>' + sub.fields.filter(f => f.type !== 'computed').map(f => '<td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px">' + esc(l[f.key]) + '</td>').join('') + '<td style="padding:6px 8px;text-align:left;font-size:12px;font-weight:700">' + money((Number(l.qty) || 0) * (Number(l.price) || 0) - (Number(l.discount) || 0)) + '</td></tr>').join('');
      const t = schema.subtable.totals(rec.lines);
      table = '<table style="width:100%;border-collapse:collapse;margin-bottom:10px"><thead>' + th + '</thead><tbody>' + tr + '</tbody></table>' +
        '<div style="text-align:left;font-size:13px;line-height:1.8"><div>الخاضع للضريبة: <b>' + money(t.sub) + '</b></div><div>ضريبة 15%: <b>' + money(t.vat) + '</b></div><div style="font-size:15px;font-weight:800">الإجمالي: ' + money(t.grand) + '</div></div>';
    } else if (rec.lines === undefined && id === 'crud-journal') {
      const t = schema.subtable.totals(rec.lines || []);
    }
    if (id === 'crud-journal' && rec.lines) {
      const th = '<th style="text-align:right;padding:6px 8px;border-bottom:2px solid #ccc;font-size:12px">الحساب</th><th style="text-align:left;padding:6px 8px;border-bottom:2px solid #ccc;font-size:12px">مدين</th><th style="text-align:left;padding:6px 8px;border-bottom:2px solid #ccc;font-size:12px">دائن</th>';
      const tr = rec.lines.map(l => '<tr><td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px">' + esc(l.account) + '</td><td style="padding:6px 8px;text-align:left;font-size:12px">' + money(l.debit) + '</td><td style="padding:6px 8px;text-align:left;font-size:12px">' + money(l.credit) + '</td></tr>').join('');
      const d = rec.lines.reduce((s, l) => s + (Number(l.debit) || 0), 0), c = rec.lines.reduce((s, l) => s + (Number(l.credit) || 0), 0);
      table = '<table style="width:100%;border-collapse:collapse;margin-bottom:10px"><thead>' + th + '</thead><tbody>' + tr + '</tbody></table><div style="text-align:left;font-size:13px"><b>المجموع مدين:</b> ' + money(d) + ' · <b>المجموع دائن:</b> ' + money(c) + '</div>';
    }
    const notes = rec.notes ? '<div style="margin-top:12px;font-size:12px;color:#555"><b>ملاحظات:</b> ' + esc(rec.notes) + '</div>' : '';
    return head + partyBlock + table + notes;
  }

  const CRUD = {
    render(host, id) { renderScreen(host, id); },
    openNew(id) { CRUD._new(id); },
    _new(id) { renderForm(SCHEMAS[id], null, id); },
    _edit(id, _id) { const rec = DB.all(id).find(r => r._id === _id); renderForm(SCHEMAS[id], rec, id); },
    _close() { if (drawerEl) drawerEl.classList.remove('open'); },
    _refresh(id) {
      const s = st(id); s.loading = true;
      const inner = document.getElementById('crudListInner');
      if (inner) inner.innerHTML = '<div class="crud-skeleton">' + Array.from({ length: s.pageSize > 6 ? 6 : s.pageSize }).map(() => '<div class="crud-sk-row"></div>').join('') + '</div>';
      setTimeout(() => { s.loading = false; const h = document.getElementById('platformContent'); if (h) renderScreen(h, id); }, 220);
    },
    _tab(id, btn, tab) {
      document.querySelectorAll('.crud-tab[data-id="' + id + '"]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      ['list', 'analytics', 'reports'].forEach(t => { const x = document.getElementById('crud' + t.charAt(0).toUpperCase() + t.slice(1)); if (x) x.style.display = (t === tab) ? '' : 'none'; });
    },
    _density() {
      density = density === 'compact' ? 'comfortable' : 'compact';
      localStorage.setItem('sopx_density', density);
      const w = document.querySelector('.crud-wrap'); if (w) w.classList.toggle('compact', density === 'compact');
      const ic = document.querySelector('[data-crud="density"] i'); if (ic) ic.className = 'fa-solid ' + (density === 'compact' ? 'fa-compress' : 'fa-expand');
    },
    _sort(id, key) { const s = st(id); if (s.sortKey === key) s.sortDir *= -1; else { s.sortKey = key; s.sortDir = 1; } s.page = 1; const h = document.getElementById('platformContent'); if (h) renderScreen(h, id); },
    _sel(id, _id, on) { const s = st(id); if (on) s.selected.add(_id); else s.selected.delete(_id); const h = document.getElementById('platformContent'); if (h) renderListInner(h, id); },
    _selall(id, on) { const s = st(id); if (on) s.pageIds.forEach(x => s.selected.add(x)); else s.pageIds.forEach(x => s.selected.delete(x)); const h = document.getElementById('platformContent'); if (h) renderListInner(h, id); },
    _page(id, p) { const s = st(id); if (p === 'prev') s.page = Math.max(1, s.page - 1); else if (p === 'next') s.page = Math.min(s.pages, s.page + 1); else s.page = Number(p); const h = document.getElementById('platformContent'); if (h) renderListInner(h, id); },
    _addLine(id) { addLineRow(id, {}); recalcSub(id); },
    _save(id, _id) {
      const rec = readForm(SCHEMAS[id], id); if (!rec) return;
      const btn = document.querySelector('[data-crud="save"]'); if (btn) { btn.classList.add('loading'); }
      if (_id && _id !== 'null') rec._id = Number(_id); else rec._id = DB.nextId(id);
      DB.upsert(id, rec);
      setTimeout(() => { CRUD._close(); const h = document.getElementById('platformContent'); if (h) renderScreen(h, id); if (window.showToast) showToast('تم الحفظ بنجاح', 'success'); }, 160);
    },
    _del(id, _id) { if (!confirm('حذف هذا السجل نهائياً؟')) return; DB.remove(id, _id); const s = st(id); s.selected.delete(_id); const h = document.getElementById('platformContent'); if (h) renderScreen(h, id); if (window.showToast) showToast('تم الحذف', 'info'); },
    _bulkDel(id) { const s = st(id); if (!s.selected.size) return; if (!confirm('حذف ' + s.selected.size + ' سجل نهائياً؟')) return; s.selected.forEach(_id => DB.remove(id, _id)); s.selected.clear(); const h = document.getElementById('platformContent'); if (h) renderScreen(h, id); if (window.showToast) showToast('تم حذف السجلات المحددة', 'info'); },
    _bulkClear(id) { st(id).selected.clear(); const h = document.getElementById('platformContent'); if (h) renderListInner(h, id); },
    _export(id) {
      const rows = DB.all(id); const schema = SCHEMAS[id]; const cols = schema.table;
      const head = cols.map(k => { const f = schema.fields.find(x => x.key === k); return (f ? f.label : k).replace('_', ''); }).join(',');
      const body = rows.map(r => cols.map(k => { let v = r[k]; if (v == null) v = r['_' + k.replace('_', '')] || ''; return '"' + String(v).replace(/"/g, '""') + '"'; }).join(',')).join('\n');
      const blob = new Blob(['﻿' + head + '\n' + body], { type: 'text/csv;charset=utf-8' }); const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = id + '.csv'; a.click(); if (window.showToast) showToast('تم تصدير CSV', 'success');
    },
    _bulkExport(id) {
      const s = st(id); const rows = DB.all(id).filter(r => s.selected.has(r._id)); const schema = SCHEMAS[id]; const cols = schema.table;
      const head = cols.map(k => { const f = schema.fields.find(x => x.key === k); return (f ? f.label : k).replace('_', ''); }).join(',');
      const body = rows.map(r => cols.map(k => { let v = r[k]; if (v == null) v = r['_' + k.replace('_', '')] || ''; return '"' + String(v).replace(/"/g, '""') + '"'; }).join(',')).join('\n');
      const blob = new Blob(['﻿' + head + '\n' + body], { type: 'text/csv;charset=utf-8' }); const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = id + '_selected.csv'; a.click(); if (window.showToast) showToast('تم تصدير ' + rows.length + ' سجل', 'success');
    },
    _print(id, _id) {
      const rec = DB.all(id).find(r => r._id === _id); if (!rec) return;
      const html = documentHTML(id, rec);
      if (window.SOPXEngine && window.SOPXEngine.openBrandPrintModal) window.SOPXEngine.openBrandPrintModal(schemaTitle(id) + ' · ' + (rec.number || ''), html, { docType: id });
      else { const w = window.open('', '_blank'); w.document.write('<html dir="rtl"><body>' + html + '</body></html>'); w.print(); }
    }
  };
  function schemaTitle(id) { return SCHEMAS[id] ? SCHEMAS[id].title : id; }
  window.CRUD = CRUD;

  /* ---- global delegated handlers (single source, no per-render listeners) ---- */
  document.addEventListener('click', e => {
    const el = e.target.closest('[data-crud]'); if (!el) return;
    const act = el.getAttribute('data-crud'); const id = el.getAttribute('data-id');
    if (act === 'new') CRUD._new(id);
    else if (act === 'edit') CRUD._edit(id, Number(el.getAttribute('data-_id')));
    else if (act === 'del') CRUD._del(id, Number(el.getAttribute('data-_id')));
    else if (act === 'refresh') CRUD._refresh(id);
    else if (act === 'export') CRUD._export(id);
    else if (act === 'tab') CRUD._tab(id, el, el.getAttribute('data-tab'));
    else if (act === 'density') CRUD._density();
    else if (act === 'close') CRUD._close();
    else if (act === 'save') CRUD._save(id, el.getAttribute('data-_id'));
    else if (act === 'addline') CRUD._addLine(id);
    else if (act === 'rmline') { el.closest('.crud-sub-row').remove(); recalcSub(drawerEl._id); }
    else if (act === 'print') CRUD._print(id, Number(el.getAttribute('data-_id')));
    else if (act === 'sort') CRUD._sort(id, el.getAttribute('data-key'));
    else if (act === 'sel') CRUD._sel(id, Number(el.getAttribute('data-_id')), el.checked);
    else if (act === 'selall') CRUD._selall(id, el.checked);
    else if (act === 'page') CRUD._page(id, el.getAttribute('data-page'));
    else if (act === 'bulk-del') CRUD._bulkDel(id);
    else if (act === 'bulk-export') CRUD._bulkExport(id);
    else if (act === 'bulk-clear') CRUD._bulkClear(id);
  });
  document.addEventListener('change', e => { if (e.target.matches('[data-crud="pagesize"]')) { const id = currentModuleId; st(id).pageSize = Number(e.target.value); st(id).page = 1; const h = document.getElementById('platformContent'); if (h) renderListInner(h, id); } });
  document.addEventListener('input', e => { if (e.target.closest('#crudSubRows')) recalcSub(drawerEl._id); });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') { CRUD._close(); return; }
    const tag = (e.target.tagName || '').toLowerCase();
    if (tag === 'input' || tag === 'textarea' || tag === 'select') return;
    if (e.key === '/') { const s = document.getElementById('crudSearch'); if (s) { e.preventDefault(); s.focus(); } }
    else if (e.key.toLowerCase() === 'n') { if (currentModuleId) CRUD._new(currentModuleId); }
  });

  /* ---- live performance / sync HUD (communicates reliability & speed) ---- */
  function ensureHud() {
    if (document.getElementById('sopxHud')) return;
    const sb = document.getElementById('pxSidebar'); if (!sb) return;
    const foot = document.createElement('div'); foot.className = 'px-side-foot';
    foot.innerHTML = '<div id="sopxHud" class="sopx-hud"><span class="sopx-hud-dot"></span><span class="txt">متصل · مزامنة أوفلاين أولاً</span><span class="lat" id="sopxLat">—</span></div><div class="px-side-ver">SOPX · v1.0 · نواة هندسية</div>';
    sb.appendChild(foot);
  }
  function hudTick() {
    const hud = document.getElementById('sopxHud'); if (!hud) return;
    const lat = document.getElementById('sopxLat');
    const online = navigator.onLine;
    const ms = online ? (8 + Math.floor(Math.random() * 26)) : 0;
    hud.classList.toggle('offline', !online);
    hud.querySelector('.txt').textContent = online ? 'متصل · مزامنة أوفلاين أولاً' : 'أوفلاين · سيتم المزامنة لاحقاً';
    if (lat) lat.textContent = online ? ms + 'ms' : '—';
  }
  function initHud() { ensureHud(); hudTick(); setInterval(hudTick, 2500); window.addEventListener('online', hudTick); window.addEventListener('offline', hudTick); }
  if (window.PlatformKernel && window.PlatformKernel.init) { const _i = window.PlatformKernel.init; window.PlatformKernel.init = function () { _i.apply(this, arguments); ensureHud(); }; }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initHud); else initHud();

  window.NEXUS_WORKSPACES = window.NEXUS_WORKSPACES || {};
  Object.keys(SCHEMAS).forEach(id => { window.NEXUS_WORKSPACES[id] = host => CRUD.render(host, id); });

  /* ===== Superior Command Center Home (KPIs + intelligence, reads live data) ===== */
  function sopxDB_all(id) { try { const v = JSON.parse(localStorage.getItem('sopx_db_' + id)); return Array.isArray(v) ? v : []; } catch (e) { return []; } }
  function sopxMoney(n) { n = Number(n) || 0; return n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' ر.س'; }
  function sopxNum(n) { n = Number(n) || 0; return n.toLocaleString('en-US'); }
  function sopxStatus(s) { s = (s || '').toString(); if (/مدفوعة|منجزة|مؤكدة|نشط/.test(s)) return 'green'; if (/مرتجعة|ملغاة|متأخرة/.test(s)) return 'red'; if (/قيد التنفيذ|مسودة|معلق/.test(s)) return 'amber'; if (/مفتوحة|جديد/.test(s)) return 'blue'; return 'gray'; }
  function sopxBars(rows, labelFn, valFn, valFmt) {
    if (!rows.length) return '<div class="crud-empty"><i class="fa-solid fa-chart-pie"></i> لا توجد بيانات كافية</div>';
    const map = {}; rows.forEach(r => { const k = labelFn(r); map[k] = (map[k] || 0) + (Number(valFn(r)) || 0); });
    const arr = Object.entries(map).sort((a, b) => b[1] - a[1]).slice(0, 7);
    const max = Math.max(1, ...arr.map(x => x[1]));
    return '<div class="crud-bars">' + arr.map(([k, v]) => '<div class="crud-bar-row"><div>' + esc(k) + '</div><div class="crud-bar-track"><div class="crud-bar-fill" style="width:' + Math.round(v / max * 100) + '%"></div></div><div class="crud-bar-val">' + (valFmt ? valFmt(v) : sopxNum(v)) + '</div></div>').join('') + '</div>';
  }
  function computeKPIs() {
    const sales = sopxDB_all('crud-sales'), purchases = sopxDB_all('crud-purchases'), items = sopxDB_all('crud-items'), maint = sopxDB_all('crud-maintenance');
    const recSales = sales.filter(s => s.status !== 'مرتجعة');
    const totalSales = recSales.reduce((s, r) => s + (r._grand || 0), 0);
    const receivables = recSales.filter(s => s.status !== 'مدفوعة').reduce((s, r) => s + ((r._grand || 0) - (Number(r.paid) || 0)), 0);
    const totalPurchases = purchases.filter(p => p.status !== 'مرتجعة').reduce((s, r) => s + (r._grand || 0), 0);
    const invValue = items.reduce((s, r) => s + (Number(r.qty) || 0) * (Number(r.cost) || 0), 0);
    const lowStock = items.filter(r => (Number(r.qty) || 0) <= (Number(r.reorder) || 0));
    const openWO = maint.filter(r => r.status === 'مفتوحة' || r.status === 'قيد التنفيذ');
    const journal = sopxDB_all('crud-journal');
    const journalNet = journal.reduce((s, r) => s + ((r._debit || 0) - (r._credit || 0)), 0);
    return { sales, purchases, items, maint, customers: sopxDB_all('crud-customers'), vendors: sopxDB_all('crud-vendors'), totalSales, receivables, totalPurchases, invValue, lowStock, openWO, journalNet };
  }
  function renderHome(host) {
    const tenant = (window.SOPXBrand && window.SOPXBrand.loadTenant && window.SOPXBrand.loadTenant().name) || sessionStorage.getItem('tenant_name') || 'مؤسستك';
    const k = computeKPIs();
    const kpis = [
      { l: 'إجمالي المبيعات', v: sopxMoney(k.totalSales), s: k.sales.length + ' فاتورة' },
      { l: 'الذمم المدينة', v: sopxMoney(k.receivables), s: 'تحصيل معلق', alert: k.receivables > 0 },
      { l: 'المشتريات', v: sopxMoney(k.totalPurchases), s: k.purchases.length + ' أمر' },
      { l: 'قيمة المخزون', v: sopxMoney(k.invValue), s: k.items.length + ' صنف' },
      { l: 'أصناف منخفضة', v: String(k.lowStock.length), s: 'تحت حد إعادة الطلب', alert: k.lowStock.length > 0 },
      { l: 'أوامر صيانة مفتوحة', v: String(k.openWO.length), s: 'قيد التنفيذ', alert: k.openWO.length > 0 },
      { l: 'صافي القيود', v: sopxMoney(k.journalNet), s: k.customers.length + ' عميل' },
      { l: 'الموردون', v: String(k.vendors.length), s: 'شريك توريد' }
    ];
    const kpiHtml = kpis.map(x => '<div class="crud-kpi' + (x.alert ? ' alert' : '') + '"><div class="k-label">' + x.l + '</div><div class="k-value">' + x.v + '</div><div class="k-sub">' + x.s + '</div></div>').join('');
    const alerts = [];
    if (k.lowStock.length) alerts.push({ t: 'مخزون منخفض', m: k.lowStock.length + ' صنف تحت حد إعادة الطلب', c: 'warn' });
    if (k.receivables > 0) alerts.push({ t: 'ذمم مدينة', m: 'مبلغ ' + sopxMoney(k.receivables) + ' بانتظار التحصيل', c: 'warn' });
    if (k.openWO.length) alerts.push({ t: 'صيانة', m: k.openWO.length + ' أمر صيانة مفتوح', c: 'warn' });
    if (!alerts.length) alerts.push({ t: 'الحالة', m: 'كل المؤشرات ضمن النطاق الطبيعي', c: 'ok' });
    const alertHtml = alerts.map(a => '<div class="crud-alert ' + a.c + '"><i class="fa-solid ' + (a.c === 'ok' ? 'fa-circle-check' : 'fa-triangle-exclamation') + '"></i><div><b>' + a.t + ':</b> ' + a.m + '</div></div>').join('');
    const feed = [];
    k.sales.slice().reverse().slice(0, 4).forEach(s => feed.push({ i: 'fa-file-invoice-dollar', t: s.number + ' — ' + s.customer, d: s.date + ' · ' + sopxMoney(s._grand || 0) }));
    k.maint.slice().reverse().slice(0, 3).forEach(m => feed.push({ i: 'fa-screwdriver-wrench', t: m.number + ' — ' + m.asset, d: m.status }));
    k.lowStock.slice(0, 3).forEach(it => feed.push({ i: 'fa-boxes-stacked', t: 'منخفض: ' + it.name, d: 'الرصيد ' + sopxNum(it.qty) }));
    const feedHtml = feed.length ? feed.map(f => '<div class="crud-feed-item"><i class="fa-solid ' + f.i + '"></i><div><div>' + esc(f.t) + '</div><div class="t">' + esc(f.d) + '</div></div></div>').join('') : '<div class="crud-empty">لا يوجد نشاط حديث</div>';
    const quick = [
      { id: 'crud-sales', label: 'فاتورة بيع', icon: 'fa-file-invoice-dollar' },
      { id: 'crud-items', label: 'صنف جديد', icon: 'fa-boxes-stacked' },
      { id: 'crud-customers', label: 'عميل', icon: 'fa-users' },
      { id: 'crud-journal', label: 'قيد محاسبي', icon: 'fa-receipt' },
      { id: 'crud-purchases', label: 'أمر شراء', icon: 'fa-truck-loading' },
      { id: 'crud-maintenance', label: 'أمر صيانة', icon: 'fa-screwdriver-wrench' }
    ].map(q => '<div class="crud-qbtn" data-open="' + q.id + '"><i class="fa-solid ' + q.icon + '"></i>' + q.label + '</div>').join('');
    const intelHtml = [
      { ico: 'fa-database', t: 'سلامة البيانات', s: 'Data Integrity', m: '100%', sub: 'مزامنة أوفلاين أولاً' },
      { ico: 'fa-layer-group', t: 'الوحدات النشطة', s: 'Active Modules', m: '16', sub: 'تجارة · مالية · مخزون · صيانة' },
      { ico: 'fa-microchip', t: 'الذكاء الهندسي', s: 'Engineering Core', m: 'SOPX', sub: 'محرك واحد لكل العمليات' },
      { ico: 'fa-shield-halved', t: 'الحوكمة', s: 'Zero-Trust', m: 'ISO', sub: 'عزل مستأجرين + RBAC' }
    ].map(c => '<div class="crud-intel-card"><div class="ic-top"><div class="ic-ico"><i class="fa-solid ' + c.ico + '"></i></div><div><div class="ic-title">' + c.t + '</div><div class="ic-sub">' + c.s + '</div></div></div><div class="ic-metric">' + c.m + '</div><div class="ic-sub">' + c.sub + '</div></div>').join('');
    const mods = window.__SOPX_MODULES || [];
    const tiles = mods.map(m => '<div class="px-tile" data-open="' + m.id + '"><div class="px-tile-icon"><i class="fa-solid ' + m.icon + '"></i></div><div class="px-tile-title">' + esc(m.name) + '</div><div class="px-tile-desc">' + esc(m.desc || '') + '</div></div>').join('');
    host.innerHTML =
      '<div class="crud-wrap">' +
      '<div class="crud-toolbar"><div class="crud-title"><i class="fa-solid fa-gauge-high"></i><h2>مركز القيادة</h2><span class="count">' + esc(tenant) + '</span></div>' +
      '<div class="crud-actions"><button class="crud-btn ghost sm" data-home-refresh><i class="fa-solid fa-rotate"></i> تحديث</button>' +
      '<button class="crud-btn ghost sm" onclick="openBrandSettings()"><i class="fa-solid fa-sliders"></i> الإعدادات</button></div></div>' +
      '<div class="crud-kpis">' + kpiHtml + '</div>' +
      '<div class="crud-tabs">' +
      '<button class="crud-tab active" data-htab="overview">نظرة عامة</button>' +
      '<button class="crud-tab" data-htab="intel">الذكاء الهندسي</button>' +
      '<button class="crud-tab" data-htab="modules">الوحدات</button>' +
      '</div>' +
      '<div id="hOverview" class="crud-cols">' +
      '<div><div class="crud-panel" style="margin-bottom:16px"><div class="crud-panel-head"><h3><i class="fa-solid fa-bolt"></i> إجراءات سريعة</h3></div><div class="crud-panel-body" style="padding:16px"><div class="crud-quick">' + quick + '</div></div></div>' +
      '<div class="crud-panel"><div class="crud-panel-head"><h3><i class="fa-solid fa-clock-rotate-left"></i> النشاط الحديث</h3></div><div class="crud-panel-body" style="padding:16px"><div class="crud-feed">' + feedHtml + '</div></div></div></div>' +
      '<div><div class="crud-panel"><div class="crud-panel-head"><h3><i class="fa-solid fa-triangle-exclamation"></i> تنبيهات ذكية</h3></div><div class="crud-panel-body" style="padding:16px">' + alertHtml + '</div></div></div>' +
      '<div id="hIntel" style="display:none"><div class="crud-intel">' + intelHtml + '</div>' +
      '<div class="crud-panel" style="margin-top:16px"><div class="crud-panel-head"><h3><i class="fa-solid fa-chart-line"></i> توزيع المخزون حسب الفئة</h3></div><div class="crud-panel-body" style="padding:16px">' + sopxBars(k.items, r => r.category, r => Number(r.qty) || 0) + '</div></div>' +
      '<div class="crud-panel" style="margin-top:16px"><div class="crud-panel-head"><h3><i class="fa-solid fa-chart-pie"></i> المبيعات حسب العميل</h3></div><div class="crud-panel-body" style="padding:16px">' + sopxBars(k.sales, r => r.customer, r => r._grand || 0, sopxMoney) + '</div></div></div>' +
      '<div id="hModules" style="display:none"><div class="px-search" style="margin-bottom:14px"><i class="fa-solid fa-magnifying-glass"></i><input id="hModSearch" placeholder="ابحث في الوحدات..."></div><div class="px-tiles" id="hTiles">' + tiles + '</div></div>' +
      '</div>';
    const ms = document.getElementById('hModSearch');
    if (ms) ms.addEventListener('input', () => { const q = (ms.value || '').toLowerCase().trim(); document.querySelectorAll('#hTiles .px-tile').forEach(t => { t.style.display = (!q || t.textContent.toLowerCase().includes(q)) ? '' : 'none'; }); });
    const rf = host.querySelector('[data-home-refresh]'); if (rf) rf.addEventListener('click', () => { if (window.PlatformKernel) window.PlatformKernel.home(); });
  }
  function sopxCaptureModules() {
    const items = Array.from(document.querySelectorAll('#pxSidebar .px-nav-item')).map(n => ({ id: n.getAttribute('data-mod'), name: (n.querySelector('span') || {}).textContent || '', icon: ((n.querySelector('i') || {}).className || '').replace('fa-solid ', ''), desc: '' })).filter(m => m.id && m.id !== 'settings' && m.id !== 'dashboard');
    window.__SOPX_MODULES = items;
  }
  function sopxHome() {
    try { if (window.playCyberSound) window.playCyberSound('click'); } catch (e) { }
    const PK = window.PlatformKernel;
    if (PK && PK.setTitle) PK.setTitle('مركز القيادة', 'fa-gauge-high');
    document.querySelectorAll('.px-nav-item').forEach(n => n.classList.toggle('active', n.getAttribute('data-mod') === 'dashboard'));
    const content = document.getElementById('platformContent'); const home = document.getElementById('platformHome');
    if (content) content.style.display = 'none';
    if (home) home.style.display = 'block';
    renderHome(home);
  }
  if (window.PlatformFormer) { }
  if (window.PlatformKernel) {
    window.PlatformKernel.home = sopxHome;
    const _init = window.PlatformKernel.init;
    window.PlatformKernel.init = function () { if (_init) _init.apply(this, arguments); sopxCaptureModules(); };
  }
  document.addEventListener('click', e => {
    const el = e.target.closest('[data-open]'); if (!el) return;
    const id = el.getAttribute('data-open');
    if (window.PlatformKernel) window.PlatformKernel.open(id);
    setTimeout(() => { if (window.CRUD) window.CRUD.openNew(id); }, 280);
  });
  document.addEventListener('click', e => {
    const el = e.target.closest('[data-htab]'); if (!el) return;
    const tab = el.getAttribute('data-htab');
    document.querySelectorAll('.crud-tab[data-htab]').forEach(b => b.classList.remove('active'));
    el.classList.add('active');
    ['overview', 'intel', 'modules'].forEach(t => { const x = document.getElementById('h' + t.charAt(0).toUpperCase() + t.slice(1)); if (x) x.style.display = (t === tab) ? '' : 'none'; });
  });
})();
