const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi } = require('./helpers/api');
const { USERS, signInUi, assertOk } = require('./helpers/common');

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
});

test.describe('Leaderboard page', () => {
  test('leaderboard is publicly accessible without login', async ({ page }) => {
    await page.goto('/web/leaderboard');
    await expect(page.getByTestId('leaderboard-title')).toContainText('Leaderboard');
    await expect(page).not.toHaveURL(/signin/);
  });

  test('nav shows leaderboard link', async ({ page }) => {
    await page.goto('/web/leaderboard');
    await expect(page.getByTestId('nav-leaderboard')).toBeVisible();
  });

  test('leaderboard shows settled player after win', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Leaderboard E2E ${Date.now()}`,
      description: 'Leaderboard test market',
    });

    const yesLeg = market.legs.find((l) => l.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const api = await request.newContext({ baseURL });

    const betResp = await api.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 500 },
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    await assertOk(betResp, 'place bet');

    const settleResp = await api.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'YES', reason: 'leaderboard-e2e' },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    await assertOk(settleResp, 'settle market');

    await page.goto('/web/leaderboard');

    await expect(page.getByTestId('leaderboard-table')).toBeVisible();
    await expect(page.locator('[data-testid^="leaderboard-player-"]').first()).toBeVisible();
  });
});
