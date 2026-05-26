const { defineConfig, devices } = require('@playwright/test');
const path = require('path');

const baseURL = process.env.BASE_URL || 'http://0.0.0.0:3000';

module.exports = defineConfig({
  testDir: './tests',
  timeout: 60_000,
  globalSetup: path.resolve(__dirname, 'tests/global-setup.js'),
  expect: {
    timeout: 10_000,
  },
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  reporter: [['html', { open: 'never' }], ['list']],
  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    headless: process.env.HEADED ? false : true,
  },
  // In docker only Chromium is installed; locally extend with firefox/webkit.
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    ...(process.env.DOCKER
      ? []
      : [
          { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
          { name: 'webkit', use: { ...devices['Desktop Safari'] } },
        ]),
  ],
});
