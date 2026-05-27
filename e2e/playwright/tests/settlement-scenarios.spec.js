// settlement-scenarios.spec.js — All 4 YES/NO bet × outcome combinations.
// Setup is fully API-driven; verification is UI-driven (player browser view).

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
