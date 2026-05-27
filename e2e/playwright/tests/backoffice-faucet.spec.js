const { test, expect, request } = require('@playwright/test');
const { loginApi } = require('./helpers/api');
const { USERS, signInUi, assertOk } = require('./helpers/common');

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
});

test.describe('Backoffice faucet request approval', () => {
  async function createFaucetRequest(baseURL, amount = 5000) {
    const { token } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const api = await request.newContext({ baseURL });
    const resp = await api.post('/faucet_requests', {
      data: { amount_minor: amount },
      headers: { Authorization: `Bearer ${token}` },
    });
    await assertOk(resp, 'create faucet request');
    return resp.json();
  }

  test('admin can approve a pending faucet request', async ({ page, baseURL }) => {
    await createFaucetRequest(baseURL, 5000);

    await signInUi(page, USERS.admin.email, USERS.admin.password);
    await page.goto('/backoffice/faucet_requests');

    await expect(page.locator('h2').filter({ hasText: /Pending/ })).toBeVisible();

    const approveBtn = page.locator('[data-testid^="approve-"]').first();
    await approveBtn.click();
    await page.waitForURL(/backoffice\/faucet_requests/);

    await expect(page.locator('.notice')).toContainText('Faucet request approved');
    await expect(page.locator('h2').filter({ hasText: /Recently Processed/ })).toBeVisible();
  });

  test('admin can reject a pending faucet request', async ({ page, baseURL }) => {
    await createFaucetRequest(baseURL, 3000);

    await signInUi(page, USERS.admin.email, USERS.admin.password);
    await page.goto('/backoffice/faucet_requests');

    const rejectBtn = page.locator('[data-testid^="reject-"]').first();
    await rejectBtn.click();
    await page.waitForURL(/backoffice\/faucet_requests/);

    await expect(page.locator('.notice')).toContainText('Faucet request rejected');
  });

  test('player cannot access backoffice faucet requests', async ({ page }) => {
    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto('/backoffice/faucet_requests');

    await expect(page).not.toHaveURL(/backoffice\/faucet_requests/);
  });
});
