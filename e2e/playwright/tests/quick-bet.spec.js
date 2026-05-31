const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi } = require('./helpers/api');
const { USERS, signInUi } = require('./helpers/common');

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
});

test.describe('Quick-bet form on market show page', () => {
  test('signed-in player sees quick-bet form on open fixed-odds market', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Quick-bet E2E ${Date.now()}`,
      description: 'Quick-bet form test',
      mechanism_type: 'fixed_odds',
      fee_bps: 100,
      liability_cap_minor: 500000,
    });

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);

    await expect(page.getByTestId('quick-bet-panel')).toBeVisible();
    await expect(page.getByTestId('quick-bet-form')).toBeVisible();
  });

  test('unauthenticated user sees sign-in prompt instead of bet form', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Quick-bet anon E2E ${Date.now()}`,
      description: 'Quick-bet anon test',
      mechanism_type: 'fixed_odds',
      fee_bps: 100,
      liability_cap_minor: 500000,
    });

    await page.goto(`/web/markets/${market.id}`);

    await expect(page.getByTestId('bet-signin-prompt')).toBeVisible();
    await expect(page.getByTestId('quick-bet-panel')).not.toBeVisible();
  });

  test('player places a bet via quick-bet form and sees notice', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Quick-bet submit E2E ${Date.now()}`,
      description: 'Quick-bet submit test',
      mechanism_type: 'fixed_odds',
      fee_bps: 100,
      liability_cap_minor: 500000,
    });

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);

    await expect(page.getByTestId('quick-bet-panel')).toBeVisible();

    await page.getByTestId('bet-leg-yes').check();
    await page.getByTestId('bet-stake').fill('100');
    await page.getByTestId('bet-submit').click();

    await expect(page).toHaveURL(new RegExp(`/web/markets/${market.id}`));
    await expect(page.getByTestId('flash-notice')).toContainText('Bet placed on YES');
  });

  test('player places a CLOB limit order via quick-bet form', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `CLOB quick-bet E2E ${Date.now()}`,
      description: 'CLOB order test',
      mechanism_type: 'clob',
      taker_fee_bps: 70,
      liability_cap_minor: 500000,
    });

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);

    await expect(page.getByTestId('quick-bet-panel')).toBeVisible();

    await page.getByTestId('bet-leg-yes').check();
    await page.getByTestId('bet-stake').fill('50');
    await page.getByTestId('bet-submit').click();

    await expect(page).toHaveURL(new RegExp(`/web/markets/${market.id}`));
    await expect(page.getByTestId('flash-notice')).toContainText('Order placed on YES');
  });

  test('player places an LMSR trade via quick-bet form', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `LMSR quick-bet E2E ${Date.now()}`,
      description: 'LMSR trade test',
      mechanism_type: 'lmsr',
      liquidity_subsidy_minor: 100000,
      spread_fee_bps: 100,
      liability_cap_minor: 500000,
    });

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);

    await expect(page.getByTestId('quick-bet-panel')).toBeVisible();

    await page.getByTestId('bet-leg-yes').check();
    await page.getByTestId('bet-stake').fill('5');
    await page.getByTestId('bet-submit').click();

    await expect(page).toHaveURL(new RegExp(`/web/markets/${market.id}`));
    await expect(page.getByTestId('flash-notice')).toContainText('Trade placed on YES');
  });

  test('player places a parimutuel pool bet via quick-bet form', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Parimutuel quick-bet E2E ${Date.now()}`,
      description: 'Parimutuel bet test',
      mechanism_type: 'parimutuel',
      takeout_bps: 1500,
      liability_cap_minor: 500000,
    });

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);

    await expect(page.getByTestId('quick-bet-panel')).toBeVisible();

    await page.getByTestId('bet-leg-yes').check();
    await page.getByTestId('bet-stake').fill('100');
    await page.getByTestId('bet-submit').click();

    await expect(page).toHaveURL(new RegExp(`/web/markets/${market.id}`));
    await expect(page.getByTestId('flash-notice')).toContainText('Stake placed on YES');
  });
});
