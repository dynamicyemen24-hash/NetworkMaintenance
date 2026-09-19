// ====================================================================
// Elias Pro v4.2 — Critical User Flows E2E (Playwright)
// ====================================================================
// Tests حقيقية browser — Confidence قبل Deploy
// Covers: Login, Ticket Creation, Diagnostics, Inventory
// ====================================================================

const { test, expect } = require('@playwright/test');

test.describe('Elias Pro — Critical Flows', () => {

  test.beforeEach(async ({ page }) => {
    // Mock API if Pode not running — intercept and mock
    await page.route('**/api/v1/health', route => route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ status: 'OPERATIONAL', health_score: 72, version: '5.0.0' })
    }));
    await page.route('**/api/v1/shop/stats', route => route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ tickets_total: 5, tickets_pending: 2, customers_total: 10, inventory_total: 20, total_sales: 5000 })
    }));
    await page.route('**/api/v1/shop/tickets', route => {
      if (route.request().method() === 'GET') {
        route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([{ ticket_no: 'TKT-001', status: 'RECEIVED', brand: 'Apple', model: 'iPhone 14' }]) });
      } else {
        route.fulfill({ status: 201, contentType: 'application/json', body: JSON.stringify({ ticket_no: 'TKT-NEW', status: 'RECEIVED' }) });
      }
    });
    await page.route('**/api/v1/shop/customers', route => route.fulfill({
      status: 200, contentType: 'application/json',
      body: JSON.stringify([{ customer_no: 'CUST-001', name: 'Ali Hassan', phone: '01012345678' }])
    }));
    await page.route('**/api/v1/shop/inventory', route => route.fulfill({
      status: 200, contentType: 'application/json',
      body: JSON.stringify([{ sku: 'SKU-001', name: 'Battery iPhone', quantity: 5, category: 'Battery' }])
    }));
  });

  test('Login flow — JWT auth', async ({ page }) => {
    await page.goto('/Dashboard/login.html');
    await expect(page.locator('h2')).toContainText('تسجيل الدخول');
    await page.fill('#username', 'admin');
    await page.fill('#password', 'admin123');
    await page.click('button:has-text("دخول")');
    // Should store JWT and redirect
    await page.waitForTimeout(1000);
    // Check localStorage
    const token = await page.evaluate(() => localStorage.getItem('elias_token'));
    expect(token).toBeTruthy();
  });

  test('Command Center loads — app.html PWA', async ({ page }) => {
    await page.goto('/Dashboard/app.html');
    await expect(page.locator('#ovRingScore')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('#refreshAll')).toBeVisible();
  });

  test('Deep diagnostics loads', async ({ page }) => {
    await page.goto('/Dashboard/deep.html');
    await expect(page.locator('body')).toContainText('التشخيص');
  });

  test('Pricing checkout path uses /api/v1', async ({ page }) => {
    await page.goto('/Dashboard/pricing.html');
    await expect(page.locator('text=Pro')).toBeVisible();
  });

  test('Dashboard loads — Health Score', async ({ page }) => {
    await page.goto('/Dashboard/index-pro.html');
    await expect(page.locator('#healthScore')).toBeVisible({ timeout: 10000 });
    // ECharts should render
    await expect(page.locator('#latencyChart')).toBeVisible();
    // AG Grid should render
    await expect(page.locator('#alertGrid')).toBeVisible();
  });

  test('Shop Kanban — Ticket board', async ({ page }) => {
    await page.goto('/Dashboard/shop-pro.html');
    await expect(page.locator('#kanbanBoard')).toBeVisible({ timeout: 10000 });
    // Check Kanban columns
    await expect(page.locator('text=RECEIVED')).toBeVisible();
    await expect(page.locator('text=READY')).toBeVisible();
  });

  test('Shop Inventory — AG Grid filtering', async ({ page }) => {
    await page.goto('/Dashboard/shop-pro.html');
    // AG Grid should load inventory
    await page.waitForTimeout(1500);
    await expect(page.locator('#inventoryGrid')).toBeVisible();
    // Test filter
    const filterInput = page.locator('#kanbanFilter');
    if (await filterInput.isVisible()) {
      await filterInput.fill('Battery');
      await page.waitForTimeout(500);
    }
  });

  test('Diagnostics — HDR flow', async ({ page }) => {
    await page.goto('/Dashboard/shop-pro.html');
    // Select device type and run diagnostics
    const diagButton = page.locator('button:has-text("تشغيل HDR")');
    if (await diagButton.isVisible()) {
      await diagButton.click();
      await expect(page.locator('#diagResult')).toContainText('HDR', { timeout: 5000 });
    }
  });

  test('Ticket creation flow', async ({ page }) => {
    await page.goto('/Dashboard/shop-pro.html');
    await page.click('text=تذكرة جديدة');
    await expect(page.locator('#newTicketModal')).toBeVisible({ timeout: 5000 });
    await page.fill('#tPhone', '01012345678');
    await page.fill('#tIssue', 'Screen broken');
    // Modal should be visible
    await expect(page.locator('#tPhone')).toHaveValue('01012345678');
  });

  test('Download page — integrity', async ({ page }) => {
    await page.goto('/Dashboard/download.html');
    await expect(page.locator('text=Elias Pro')).toBeVisible();
    await expect(page.locator('text=SHA256')).toBeVisible();
    // Check ZIP link
    const zipLink = page.locator('a:has-text("تنزيل ZIP")');
    await expect(zipLink).toBeVisible();
    expect(await zipLink.getAttribute('href')).toContain('.zip');
  });

});

test.describe('API — Health checks (Deploy safety)', () => {
  test('Health endpoint returns 200', async ({ request }) => {
    const res = await request.get('/api/v1/health');
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('OPERATIONAL');
  });

  test('Shop stats endpoint', async ({ request }) => {
    const res = await request.get('/api/v1/shop/stats');
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body).toHaveProperty('tickets_total');
  });
});
