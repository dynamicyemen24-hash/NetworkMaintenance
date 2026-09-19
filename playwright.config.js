// ====================================================================
// Elias Pro v4.2 — Playwright E2E Testing
// ====================================================================
// التأثير: Confidence في user flows — Tests حقيقية browser
// القيمة: Deploy بدون خطر — Zero-downtime releases
// Open Source: Microsoft Playwright (https://github.com/microsoft/playwright)
// ====================================================================

const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { open: 'never' }],
    ['list'],
    ['json', { outputFile: 'test-results/results.json' }]
  ],
  use: {
    baseURL: 'http://127.0.0.1:8080',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10000,
    navigationTimeout: 15000,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    // Mobile
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
  ],
  // Run API server before tests
  webServer: {
    command: 'powershell -ExecutionPolicy Bypass -File "C:\\NetworkMaintenance\\API\\Server-Pode.ps1" -Port 8080',
    url: 'http://127.0.0.1:8080/api/v1/health',
    reuseExistingServer: !process.env.CI,
    timeout: 30 * 1000,
  },
  expect: {
    timeout: 5000
  },
});
