// settlement-scenarios.spec.js — Settlement flows for all 4 mechanism types.
// Fixed-odds: all 4 YES/NO bet × outcome combinations.
// CLOB / LMSR / Parimutuel: settle YES and settle NO, verify UI shows the outcome.

const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi } = require('./helpers/api');
const { USERS, signInUi, assertOk } = require('./helpers/common');

const SCENARIOS = [
  {
    label: 'YES bet + YES settlement = WIN',
    betSide: 'YES',
    outcome: 'YES',
    expectText: 'Settled outcome: YES',
  },
  {
    label: 'NO bet + YES settlement = LOSS',
    betSide: 'NO',
    outcome: 'YES',
    expectText: 'Settled outcome: YES',
  },
  {
    label: 'YES bet + NO settlement = LOSS',
    betSide: 'YES',
    outcome: 'NO',
    expectText: 'Settled outcome: NO',
  },
  {
    label: 'NO bet + NO settlement = WIN',
    betSide: 'NO',
    outcome: 'NO',
    expectText: 'Settled outcome: NO',
  },
];

test.describe('Settlement YES/NO scenarios', () => {
  // Forward browser console to Node stdout
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
    page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  });

  for (const scenario of SCENARIOS) {
    test(scenario.label, async ({ page, baseURL }) => {
      // 1. Create market via admin API (already opens it)
      const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
      const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
        question: `[${scenario.label}] ${Date.now()}`,
        description: 'E2E settlement scenario',
      });

      const leg = market.legs.find((l) => l.label === scenario.betSide);
      expect(leg, `leg ${scenario.betSide} not found in market`).toBeTruthy();

      // 2. Place bet as player
      const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
      const api = await request.newContext({ baseURL });

      const betResp = await api.post(`/markets/${market.id}/bets`, {
        data: { market_leg_id: leg.id, stake_minor: 100 },
        headers: { Authorization: `Bearer ${playerToken}` },
      });
      await assertOk(betResp, `place bet (${scenario.betSide})`);

      // 3. Settle via admin API
      const settleResp = await api.post(`/admin/markets/${market.id}/settle`, {
        data: { outcome: scenario.outcome, reason: 'e2e-scenario' },
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      await assertOk(settleResp, `settle market (${scenario.outcome})`);

      await api.dispose();

      // 4. Sign in as player in browser and verify market page
      await signInUi(page, USERS.player.email, USERS.player.password);
      await page.goto(`/web/markets/${market.id}`);
      await expect(page.getByTestId('market-trust-panel')).toContainText(scenario.expectText);
    });
  }
});

// ---------------------------------------------------------------------------
// CLOB settlement scenarios
// ---------------------------------------------------------------------------

const CLOB_SETTLE_SCENARIOS = [
  { outcome: 'YES', label: 'CLOB settle YES' },
  { outcome: 'NO', label: 'CLOB settle NO' },
];

test.describe('CLOB market settlement scenarios', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
    page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  });

  for (const scenario of CLOB_SETTLE_SCENARIOS) {
    test(scenario.label, async ({ page, baseURL }) => {
      // 1. Create CLOB market
      const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
      const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
        question: `[${scenario.label}] ${Date.now()}`,
        description: 'CLOB settlement E2E',
        mechanism_type: 'clob',
        taker_fee_bps: 70,
        liability_cap_minor: 500000,
      });

      // 2. Get player user ID via /auth/me, then place a GTC limit order as player
      const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
      const api = await request.newContext({ baseURL });

      const meResp = await api.get('/auth/me', { headers: { Authorization: `Bearer ${playerToken}` } });
      await assertOk(meResp, 'fetch player /auth/me');
      const { id: playerId } = await meResp.json();

      const orderResp = await api.post(`/admin/markets/${market.id}/orders`, {
        data: { user_id: playerId, side: 'YES', price_cents: 50, quantity: 5, time_in_force: 'GTC' },
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      await assertOk(orderResp, 'place CLOB order as player (via admin API)');

      // 3. Settle via admin API
      const settleResp = await api.post(`/admin/markets/${market.id}/settle`, {
        data: { outcome: scenario.outcome, reason: 'e2e-clob-settlement' },
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      await assertOk(settleResp, `settle CLOB market (${scenario.outcome})`);

      await api.dispose();

      // 4. Verify settled outcome in browser
      await signInUi(page, USERS.player.email, USERS.player.password);
      await page.goto(`/web/markets/${market.id}`);
      await expect(page.getByTestId('market-trust-panel')).toContainText(`Settled outcome: ${scenario.outcome}`);
    });
  }
});

// ---------------------------------------------------------------------------
// LMSR settlement scenarios
// ---------------------------------------------------------------------------

const LMSR_SETTLE_SCENARIOS = [
  { outcome: 'YES', label: 'LMSR settle YES' },
  { outcome: 'NO', label: 'LMSR settle NO' },
];

test.describe('LMSR market settlement scenarios', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
    page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  });

  for (const scenario of LMSR_SETTLE_SCENARIOS) {
    test(scenario.label, async ({ page, baseURL }) => {
      // 1. Create LMSR market
      const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
      const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
        question: `[${scenario.label}] ${Date.now()}`,
        description: 'LMSR settlement E2E',
        mechanism_type: 'lmsr',
        liquidity_subsidy_minor: 100000,
        spread_fee_bps: 100,
        liability_cap_minor: 500000,
      });

      // 2. Sign in as player and place an LMSR trade via the quick-bet form
      await signInUi(page, USERS.player.email, USERS.player.password);
      await page.goto(`/web/markets/${market.id}`);
      await page.getByTestId('bet-leg-yes').check();
      await page.getByTestId('bet-stake').fill('5');
      await page.getByTestId('bet-submit').click();
      await expect(page.locator('.notice')).toContainText('Trade placed on YES');

      // 3. Settle via admin API
      const api = await request.newContext({ baseURL });
      const settleResp = await api.post(`/admin/markets/${market.id}/settle`, {
        data: { outcome: scenario.outcome, reason: 'e2e-lmsr-settlement' },
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      await assertOk(settleResp, `settle LMSR market (${scenario.outcome})`);
      await api.dispose();

      // 4. Verify settled outcome in browser
      await page.goto(`/web/markets/${market.id}`);
      await expect(page.getByTestId('market-trust-panel')).toContainText(`Settled outcome: ${scenario.outcome}`);
    });
  }
});

// ---------------------------------------------------------------------------
// Parimutuel settlement scenarios
// ---------------------------------------------------------------------------

const PARIMUTUEL_SETTLE_SCENARIOS = [
  { outcome: 'YES', label: 'Parimutuel settle YES' },
  { outcome: 'NO', label: 'Parimutuel settle NO' },
];

test.describe('Parimutuel market settlement scenarios', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
    page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  });

  for (const scenario of PARIMUTUEL_SETTLE_SCENARIOS) {
    test(scenario.label, async ({ page, baseURL }) => {
      // 1. Create parimutuel market
      const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
      const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
        question: `[${scenario.label}] ${Date.now()}`,
        description: 'Parimutuel settlement E2E',
        mechanism_type: 'parimutuel',
        takeout_bps: 1500,
        liability_cap_minor: 500000,
      });

      // 2. Sign in as player and place a parimutuel stake via the quick-bet form
      await signInUi(page, USERS.player.email, USERS.player.password);
      await page.goto(`/web/markets/${market.id}`);
      await page.getByTestId('bet-leg-yes').check();
      await page.getByTestId('bet-stake').fill('100');
      await page.getByTestId('bet-submit').click();
      await expect(page.locator('.notice')).toContainText('Stake placed on YES');

      // 3. Settle via admin API
      const api = await request.newContext({ baseURL });
      const settleResp = await api.post(`/admin/markets/${market.id}/settle`, {
        data: { outcome: scenario.outcome, reason: 'e2e-parimutuel-settlement' },
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      await assertOk(settleResp, `settle parimutuel market (${scenario.outcome})`);
      await api.dispose();

      // 4. Verify settled outcome in browser
      await page.goto(`/web/markets/${market.id}`);
      await expect(page.getByTestId('market-trust-panel')).toContainText(`Settled outcome: ${scenario.outcome}`);
    });
  }
});
