-- ====================================================================
-- NetworkMaintenance-Pro v4.0 - Repair Shop Universal Schema
-- For: Mobile / Computer / Electronics Repair Shops
-- Standards: ITIL v4 | ISO 27001 | PCI-DSS | GAAP
-- ====================================================================

-- ─────────────── CUSTOMERS (CRM) ───────────────
CREATE TABLE IF NOT EXISTS customers (
    customer_id TEXT PRIMARY KEY,
    customer_no TEXT UNIQUE NOT NULL, -- CUST-2026-00001
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    phone2 TEXT,
    whatsapp TEXT,
    email TEXT,
    national_id TEXT,
    address TEXT,
    city TEXT,
    area TEXT,
    notes TEXT,
    tags TEXT, -- JSON: ["VIP","Wholesale"]
    total_visits INTEGER DEFAULT 0,
    total_spent REAL DEFAULT 0,
    balance REAL DEFAULT 0, -- credit/debit
    loyalty_points INTEGER DEFAULT 0,
    blacklisted BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);

-- ─────────────── TECHNICIANS ───────────────
CREATE TABLE IF NOT EXISTS technicians (
    technician_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    specialty TEXT, -- Mobile, Computer, Electronics, All
    skill_level TEXT DEFAULT 'Junior', -- Junior, Senior, Expert
    commission_rate REAL DEFAULT 10.0, -- %
    active BOOLEAN DEFAULT 1,
    total_repairs INTEGER DEFAULT 0,
    rating REAL DEFAULT 5.0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────── SUPPLIERS ───────────────
CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    category TEXT, -- Screens, Batteries, ICs, General
    balance REAL DEFAULT 0,
    rating INTEGER DEFAULT 5,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────── INVENTORY - SPARE PARTS ───────────────
CREATE TABLE IF NOT EXISTS inventory_parts (
    part_id TEXT PRIMARY KEY,
    sku TEXT UNIQUE NOT NULL, -- SKU-BAT-IP14-001
    barcode TEXT UNIQUE, -- EAN13
    qr_code TEXT,
    name TEXT NOT NULL, -- "Battery iPhone 14 Original"
    category TEXT NOT NULL, -- Battery, Screen, Board, IC, Cable, Housing, Accessory
    subcategory TEXT,
    brand TEXT, -- Apple, Samsung, Xiaomi, Generic
    compatible_models TEXT, -- JSON: ["iPhone 14","iPhone 14 Pro"]
    location_bin TEXT, -- A-01-03
    quantity INTEGER DEFAULT 0,
    min_quantity INTEGER DEFAULT 2,
    max_quantity INTEGER DEFAULT 20,
    unit_cost REAL NOT NULL, -- purchase price
    unit_price REAL NOT NULL, -- selling price
    wholesale_price REAL,
    supplier_id TEXT,
    expiry_date DATE,
    warranty_days INTEGER DEFAULT 30,
    is_original BOOLEAN DEFAULT 0,
    image_path TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);
CREATE INDEX IF NOT EXISTS idx_parts_sku ON inventory_parts(sku);
CREATE INDEX IF NOT EXISTS idx_parts_barcode ON inventory_parts(barcode);
CREATE INDEX IF NOT EXISTS idx_parts_category ON inventory_parts(category);
CREATE INDEX IF NOT EXISTS idx_parts_qty ON inventory_parts(quantity);

-- ─────────────── TICKETS - REPAIR JOBS (Core) ───────────────
CREATE TABLE IF NOT EXISTS tickets (
    ticket_id TEXT PRIMARY KEY,
    ticket_no TEXT UNIQUE NOT NULL, -- TKT-2026-00001
    customer_id TEXT NOT NULL,
    technician_id TEXT,
    device_type TEXT NOT NULL, -- Mobile, Tablet, Laptop, Desktop, Console, TV, Other
    brand TEXT,
    model TEXT,
    serial_number TEXT,
    imei TEXT,
    imei2 TEXT,
    color TEXT,
    password TEXT, -- device lock
    pattern TEXT,
    accessories TEXT, -- JSON: ["Charger","Cover"]
    reported_issue TEXT NOT NULL,
    diagnosis TEXT,
    status TEXT NOT NULL DEFAULT 'RECEIVED', -- RECEIVED, DIAGNOSED, QUOTED, APPROVED, REPAIRING, QC, READY, DELIVERED, CANCELLED, WARRANTY
    priority TEXT DEFAULT 'NORMAL', -- LOW, NORMAL, HIGH, URGENT
    estimated_cost REAL DEFAULT 0,
    final_cost REAL DEFAULT 0,
    deposit REAL DEFAULT 0,
    discount REAL DEFAULT 0,
    received_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    diagnosed_at DATETIME,
    quoted_at DATETIME,
    approved_at DATETIME,
    started_at DATETIME,
    completed_at DATETIME,
    delivered_at DATETIME,
    promised_at DATETIME,
    warranty_until DATE,
    rating INTEGER, -- 1-5 after delivery
    feedback TEXT,
    internal_notes TEXT,
    photos_before TEXT, -- JSON array of paths
    photos_after TEXT, -- JSON array
    created_by TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (technician_id) REFERENCES technicians(technician_id)
);
CREATE INDEX IF NOT EXISTS idx_tickets_no ON tickets(ticket_no);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_customer ON tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_tickets_tech ON tickets(technician_id);
CREATE INDEX IF NOT EXISTS idx_tickets_received ON tickets(received_at);

-- ─────────────── TICKET ITEMS (Parts Used) ───────────────
CREATE TABLE IF NOT EXISTS ticket_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id TEXT NOT NULL,
    part_id TEXT,
    part_name TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    unit_cost REAL,
    unit_price REAL,
    total REAL,
    is_customer_supplied BOOLEAN DEFAULT 0,
    FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
    FOREIGN KEY (part_id) REFERENCES inventory_parts(part_id)
);

-- ─────────────── TICKET HISTORY (Audit Trail) ───────────────
CREATE TABLE IF NOT EXISTS ticket_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id TEXT NOT NULL,
    from_status TEXT,
    to_status TEXT,
    changed_by TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);

-- ─────────────── INVOICES (Billing) ───────────────
CREATE TABLE IF NOT EXISTS invoices (
    invoice_id TEXT PRIMARY KEY,
    invoice_no TEXT UNIQUE NOT NULL, -- INV-2026-00001
    ticket_id TEXT,
    customer_id TEXT NOT NULL,
    subtotal REAL NOT NULL,
    tax_rate REAL DEFAULT 14.0,
    tax_amount REAL DEFAULT 0,
    discount REAL DEFAULT 0,
    discount_reason TEXT,
    total REAL NOT NULL,
    paid REAL DEFAULT 0,
    remaining REAL DEFAULT 0,
    payment_method TEXT DEFAULT 'CASH', -- CASH, VISA, INSTAPAY, WALLET, TRANSFER
    payment_status TEXT DEFAULT 'UNPAID', -- UNPAID, PARTIAL, PAID, REFUNDED
    is_thermal_printed BOOLEAN DEFAULT 0,
    qr_code TEXT, -- for verification
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    paid_at DATETIME,
    FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE IF NOT EXISTS invoice_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id TEXT NOT NULL,
    description TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    unit_price REAL NOT NULL,
    line_total REAL NOT NULL,
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
);

-- ─────────────── PAYMENTS ───────────────
CREATE TABLE IF NOT EXISTS payments (
    payment_id TEXT PRIMARY KEY,
    invoice_id TEXT,
    customer_id TEXT,
    amount REAL NOT NULL,
    method TEXT NOT NULL,
    reference TEXT, -- transaction id
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
);

-- ─────────────── PURCHASE ORDERS ───────────────
CREATE TABLE IF NOT EXISTS purchase_orders (
    po_id TEXT PRIMARY KEY,
    po_no TEXT UNIQUE NOT NULL,
    supplier_id TEXT NOT NULL,
    total_cost REAL NOT NULL,
    status TEXT DEFAULT 'PENDING', -- PENDING, ORDERED, RECEIVED, CANCELLED
    ordered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    received_at DATETIME,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);
CREATE TABLE IF NOT EXISTS po_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    po_id TEXT NOT NULL,
    part_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_cost REAL NOT NULL,
    line_total REAL NOT NULL,
    FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id),
    FOREIGN KEY (part_id) REFERENCES inventory_parts(part_id)
);

-- ─────────────── WARRANTIES ───────────────
CREATE TABLE IF NOT EXISTS warranties (
    warranty_id TEXT PRIMARY KEY,
    ticket_id TEXT NOT NULL,
    customer_id TEXT NOT NULL,
    device_info TEXT,
    warranty_type TEXT DEFAULT 'SHOP', -- SHOP, SUPPLIER, MANUFACTURER
    duration_days INTEGER DEFAULT 30,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    terms TEXT,
    status TEXT DEFAULT 'ACTIVE', -- ACTIVE, CLAIMED, EXPIRED, VOID
    claim_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);

-- ─────────────── DEVICE DIAGNOSTICS (Smart) ───────────────
CREATE TABLE IF NOT EXISTS device_diagnostics (
    diag_id TEXT PRIMARY KEY,
    ticket_id TEXT,
    device_type TEXT NOT NULL,
    mode TEXT DEFAULT 'QUICK', -- QUICK, FULL, CUSTOM
    battery_health REAL, -- %
    battery_cycles INTEGER,
    battery_temp REAL,
    storage_health REAL, -- %
    storage_used_gb REAL,
    storage_total_gb REAL,
    ram_total_gb REAL,
    ram_available_gb REAL,
    cpu_temp REAL,
    cpu_usage REAL,
    screen_test TEXT, -- JSON: {touch: PASS, display: PASS}
    sensors_test TEXT, -- JSON
    camera_test TEXT, -- JSON
    mic_speaker_test TEXT, -- JSON
    network_test TEXT, -- JSON: {wifi: PASS, sim: PASS, signal: -70}
    ports_test TEXT, -- JSON
    overall_score INTEGER, -- 0-100
    overall_status TEXT, -- EXCELLENT, GOOD, FAIR, POOR, CRITICAL
    issues_found TEXT, -- JSON array
    ai_recommendation TEXT,
    raw_data TEXT, -- JSON full dump
    performed_by TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);

-- ─────────────── PRICE LIST (AI-Powered) ───────────────
CREATE TABLE IF NOT EXISTS price_list (
    price_id TEXT PRIMARY KEY,
    device_type TEXT NOT NULL,
    brand TEXT,
    model TEXT,
    service TEXT NOT NULL, -- "Screen Replacement", "Battery Replacement", "Board Repair"
    cost REAL NOT NULL,
    price REAL NOT NULL,
    duration_minutes INTEGER DEFAULT 60,
    warranty_days INTEGER DEFAULT 30,
    popularity INTEGER DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_price_service ON price_list(service);

-- ─────────────── NOTIFICATIONS ───────────────
CREATE TABLE IF NOT EXISTS notifications (
    notif_id TEXT PRIMARY KEY,
    customer_id TEXT,
    ticket_id TEXT,
    channel TEXT NOT NULL, -- SMS, WHATSAPP, CALL
    template TEXT,
    message TEXT,
    status TEXT DEFAULT 'PENDING', -- PENDING, SENT, FAILED, DELIVERED
    sent_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────── DAILY CLOSING (End of Day) ───────────────
CREATE TABLE IF NOT EXISTS daily_closing (
    closing_id TEXT PRIMARY KEY,
    closing_date DATE UNIQUE NOT NULL,
    total_tickets INTEGER DEFAULT 0,
    total_invoices INTEGER DEFAULT 0,
    total_sales REAL DEFAULT 0,
    total_cost REAL DEFAULT 0,
    total_profit REAL DEFAULT 0,
    total_expenses REAL DEFAULT 0,
    cash_in_drawer REAL DEFAULT 0,
    closed_by TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────── EXPENSES ───────────────
CREATE TABLE IF NOT EXISTS expenses (
    expense_id TEXT PRIMARY KEY,
    category TEXT NOT NULL, -- Rent, Electricity, Purchase, Salary, Other
    amount REAL NOT NULL,
    description TEXT,
    expense_date DATE DEFAULT CURRENT_DATE,
    created_by TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────── VIEWS ───────────────
CREATE VIEW IF NOT EXISTS v_ticket_summary AS
SELECT status, COUNT(*) as count, SUM(final_cost) as total_value, AVG(final_cost) as avg_value FROM tickets GROUP BY status;

CREATE VIEW IF NOT EXISTS v_low_stock AS
SELECT * FROM inventory_parts WHERE quantity <= min_quantity ORDER BY quantity ASC;

CREATE VIEW IF NOT EXISTS v_top_customers AS
SELECT c.customer_id, c.name, c.phone, COUNT(t.ticket_id) as visits, SUM(t.final_cost) as total_spent FROM customers c LEFT JOIN tickets t ON c.customer_id = t.customer_id GROUP BY c.customer_id ORDER BY total_spent DESC LIMIT 20;

CREATE VIEW IF NOT EXISTS v_technician_performance AS
SELECT t.technician_id, tec.name, COUNT(*) as repairs, AVG(t.rating) as avg_rating, SUM(t.final_cost) as revenue FROM tickets t JOIN technicians tec ON t.technician_id = tec.technician_id WHERE t.status = 'DELIVERED' GROUP BY t.technician_id;

CREATE VIEW IF NOT EXISTS v_daily_sales AS
SELECT date(created_at) as day, COUNT(*) as invoices, SUM(total) as sales, SUM(paid) as collected FROM invoices GROUP BY date(created_at) ORDER BY day DESC;

CREATE VIEW IF NOT EXISTS v_warranty_expiring AS
SELECT * FROM warranties WHERE end_date BETWEEN date('now') AND date('now','+7 days') AND status = 'ACTIVE';

-- ─────────────── TRIGGERS ───────────────
CREATE TRIGGER IF NOT EXISTS trg_ticket_history AFTER UPDATE ON tickets
WHEN OLD.status != NEW.status
BEGIN
    INSERT INTO ticket_history (ticket_id, from_status, to_status, changed_by) VALUES (NEW.ticket_id, OLD.status, NEW.status, 'SYSTEM');
END;

CREATE TRIGGER IF NOT EXISTS trg_customer_stats AFTER INSERT ON tickets
BEGIN
    UPDATE customers SET total_visits = total_visits + 1, updated_at = CURRENT_TIMESTAMP WHERE customer_id = NEW.customer_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_inventory_low AFTER UPDATE ON inventory_parts
WHEN NEW.quantity <= NEW.min_quantity
BEGIN
    INSERT INTO alerts (alert_id, device_id, severity, category, title, description, status) VALUES ('LOW-' || NEW.part_id || '-' || strftime('%Y%m%d%H%M%S','now'), NULL, 'HIGH', 'INVENTORY', 'Low Stock: ' || NEW.name, 'SKU ' || NEW.sku || ' qty ' || NEW.quantity || ' <= min ' || NEW.min_quantity, 'OPEN');
END;

-- Seed: Default Technician + Price List Samples
INSERT OR IGNORE INTO technicians (technician_id, name, specialty, skill_level) VALUES ('TECH-001', 'فني عام', 'All', 'Expert');
INSERT OR IGNORE INTO price_list (price_id, device_type, brand, model, service, cost, price, duration_minutes) VALUES
('PRICE-001', 'Mobile', 'Apple', 'iPhone 14', 'Screen Replacement', 800, 1500, 45),
('PRICE-002', 'Mobile', 'Samsung', 'A54', 'Battery Replacement', 300, 600, 30),
('PRICE-003', 'Laptop', 'Dell', 'General', 'RAM Upgrade 8GB', 400, 700, 20),
('PRICE-004', 'Mobile', 'Xiaomi', 'General', 'Charging Port Repair', 150, 350, 40),
('PRICE-005', 'Electronics', 'General', 'General', 'General Diagnosis', 0, 50, 15);
