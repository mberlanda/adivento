const { defineConfig, devices } = require('@playwright/test');
const path = require('path');

const baseURL = process.env.BASE_URL || 'http://0.0.0.0:3000';
const isCI = !!process.env.CI;
const isDocker = !!process.env.DOCKER;

module.exports = defineConfig({
  testDir: './tests',
  timeout: 60_000,
  globalSetup: path.resolve(__dirname, 'tests/global-setup.js'),
  expect: {
    timeout: 10_000,
  },
  fullyParallel: false,
  retries: isCI ? 1 : 0,
  reporter: [
    // Human-readable line-by-line output (visible in CI logs)
    ['list', { printSteps: true }],
    // HTML report saved to playwright-report/ (uploaded as artifact)
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    // JSON results for machine consumption
    ['json', { outputFile: 'playwright-report/results.json' }],
  ],
  use: {
    baseURL,
    // Always capture trace and screenshot so failures are always diagnosable
    trace: 'on',
    screenshot: 'on',
    video: isCI ? 'on' : 'retain-on-failure',
    headless: process.env.HEADED ? false : true,
    // Log browser console messages to stdout
    launchOptions: {
      args: ['--enable-logging', '--v=1'],
    },
  },
  // In docker only Chromium is installed; locally extend with firefox/webkit.
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    ...(isDocker
      ? []
      : [
          { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
          { name: 'webkit', use: { ...devices['Desktop Safari'] } },
        ]),
  ],
});
