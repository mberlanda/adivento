const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi } = require('./helpers/api');
const { USERS, signInUi, assertOk } = require('./helpers/common');

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
});

test.describe('User profile page', () => {
  test('unauthenticated user is redirected to sign-in', async ({ page }) => {
    await page.goto('/web/profile');
    await expect(page).toHaveURL(/signin/);
  });

  test('player sees wallet balance and P&L panel', async ({ page }) => {
    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto('/web/profile');

    await expect(page.getByTestId('profile-title')).toContainText('My Profile');
    await expect(page.getByTestId('wallet-balance-panel')).toBeVisible();
    await expect(page.getByTestId('pnl-panel')).toBeVisible();
    await expect(page.getByTestId('bets-panel')).toBeVisible();
  });

  test('nav balance chip shows ADIV balance', async ({ page }) => {
    await signInUi(page, USERS.player.email, USERS.player.password);

    const chip = page.getByTestId('nav-balance');
    await expect(chip).toBeVisible();
    await expect(chip).toContainText('ADIV');
  });

  test('faucet request form submits and shows notice', async ({ page }) => {
    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto('/web/profile');

    const details = page.locator('details').filter({ hasText: 'Request more tokens' });
    await details.locator('summary').click();

    const amountInput = details.locator('input[name="amount_minor"]');
    await amountInput.fill('5000');

    await page.getByTestId('faucet-submit').click();
    await page.waitForURL(/web\/profile/);
    await expect(page.getByTestId('flash-notice')).toContainText('Token request submitted');
  });

  test('bet history table shows player bets with status tabs', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Profile E2E market ${Date.now()}`,
      description: 'Profile bet history test',
    });

    const yesLeg = market.legs.find((l) => l.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const api = await request.newContext({ baseURL });
    const betResp = await api.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 100 },
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    await assertOk(betResp, 'place bet for profile test');

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto('/web/profile');

    await expect(page.getByTestId('bets-table')).toBeVisible();
    await expect(page.getByTestId('bets-panel')).toContainText('YES');
  });
});

test.describe('Market detail enrichment (F-003)', () => {
  test('resolution details panel shows when market has close_at and criteria', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);

    const closeAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Resolution E2E ${Date.now()}`,
      description: 'Test resolution panel',
      close_at: closeAt,
      resolution_criteria: 'Resolves YES if confirmed by official source',
      resolution_source: 'Official Website',
    });

    await page.goto(`/web/markets/${market.id}`);

    await expect(page.getByTestId('market-resolution-panel')).toBeVisible();
    await expect(page.getByTestId('market-close-at')).toBeVisible();
    await expect(page.getByTestId('market-resolution-criteria')).toContainText('Resolves YES');
    await expect(page.getByTestId('market-resolution-source')).toContainText('Official Website');
  });

  test('market stats show volume and open positions', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Stats E2E ${Date.now()}`,
      description: 'Test market stats display',
    });

    const yesLeg = market.legs.find((l) => l.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const api = await request.newContext({ baseURL });
    const betResp = await api.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 200 },
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    await assertOk(betResp, 'place bet for stats test');

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);

    await expect(page.getByTestId('market-stats')).toBeVisible();
    await expect(page.getByTestId('market-volume')).toContainText('ADIV');
    await expect(page.getByTestId('market-open-bets')).toContainText('1');
  });
});
