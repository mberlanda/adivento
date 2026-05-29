const { test, expect } = require('@playwright/test');
const { USERS, signInUi } = require('./helpers/common');

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
});

test.describe('Backoffice open-market flow', () => {
  test('admin creates a draft market then opens it for betting', async ({ page }) => {
    await signInUi(page, USERS.admin.email, USERS.admin.password);
    await page.goto('/backoffice/markets');

    const suffix = Date.now();
    await page.getByTestId('market-question').fill(`Draft-to-open E2E ${suffix}`);
    await page.getByTestId('market-description').fill('TD-007 draft to open path');
    await page.getByTestId('market-create-submit').click();

    await expect(page.getByTestId('market-title')).toContainText(`Draft-to-open E2E ${suffix}`);

    // Draft market: open form is present, settle form is not
    await expect(page.getByTestId('open-market-form')).toBeVisible();
    await expect(page.getByTestId('settle-market-form')).not.toBeVisible();

    // Open the market
    await page.getByTestId('open-market-submit').click();

    // After opening: settle form appears, open form disappears
    await expect(page.getByTestId('settle-market-form')).toBeVisible();
    await expect(page.getByTestId('open-market-form')).not.toBeVisible();

    // Status label reflects the open state
    await expect(page.locator('strong', { hasText: /open/i }).first()).toBeVisible();
  });
});
