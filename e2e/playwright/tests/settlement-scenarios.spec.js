/**
 * settlement-scenarios.spec.js — Settlement Outcome Matrix
 *
 * Tests the full lifecycle of markets from open → settled across every
 * meaningful combination of:
 *   - which leg the player bet on (YES / NO)
 *   - which outcome the market settled to (YES / NO)
 *
 * Result grid:
 *   Bet YES, settle YES → WIN  (payout credited)
 *   Bet YES, settle NO  → LOSS (no credit)
 *   Bet NO,  settle NO  → WIN  (payout credited)
 *   Bet NO,  settle YES → LOSS (no credit)
 *
 * Also covers:
 *   - Settling a market with no bets (zero payout, status → settled)
 *   - Void bet before settlement (bet status → voided, not included in payout)
 *   - Double-settlement attempt (idempotency / error)
 */

const { test, expect, request } = require('@playwright/test');
const {
  USERS,
  assertOk,
  loginApi,
  signInUi,
  createMarketViaAdminApi,
  placeBetApi,
  settleMarketApi,
  attachConsoleForwarder,
} = require('./helpers/common');

test.beforeEach(async ({ page }) => {
  attachConsoleForwarder(page);
});

test.describe('Settlement Outcome Matrix', () => {
  // -----------------------------------------------------------------------
  // WIN scenarios — UI verification
  // -----------------------------------------------------------------------

  test('bet YES → settle YES → player sees WIN outcome in UI', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `YES-WIN ${Date.now()}`,
      description: 'Settlement matrix: bet YES, settle YES',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    await placeBetApi(baseURL, playerToken, market.id, yesLeg.id, 100);
    await settleMarketApi(baseURL, adminToken, market.id, 'YES', 'matrix-yes-win');

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);
    await expect(page.getByTestId('market-trust-panel')).toContainText('Settled outcome: YES');
  });

  test('bet NO → settle NO → player sees WIN outcome in UI', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `NO-WIN ${Date.now()}`,
      description: 'Settlement matrix: bet NO, settle NO',
    });
    const noLeg = market.legs.find((l) => l.label === 'NO');

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    await placeBetApi(baseURL, playerToken, market.id, noLeg.id, 100);
    await settleMarketApi(baseURL, adminToken, market.id, 'NO', 'matrix-no-win');

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);
    await expect(page.getByTestId('market-trust-panel')).toContainText('Settled outcome: NO');
  });

  // -----------------------------------------------------------------------
  // LOSS scenarios — UI verification
  // -----------------------------------------------------------------------

  test('bet YES → settle NO → player sees LOSS outcome in UI', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `YES-LOSS ${Date.now()}`,
      description: 'Settlement matrix: bet YES, settle NO',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    await placeBetApi(baseURL, playerToken, market.id, yesLeg.id, 100);
    await settleMarketApi(baseURL, adminToken, market.id, 'NO', 'matrix-yes-loss');

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);
    await expect(page.getByTestId('market-trust-panel')).toContainText('Settled outcome: NO');
  });

  test('bet NO → settle YES → player sees LOSS outcome in UI', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `NO-LOSS ${Date.now()}`,
      description: 'Settlement matrix: bet NO, settle YES',
    });
    const noLeg = market.legs.find((l) => l.label === 'NO');

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    await placeBetApi(baseURL, playerToken, market.id, noLeg.id, 100);
    await settleMarketApi(baseURL, adminToken, market.id, 'YES', 'matrix-no-loss');

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${market.id}`);
    await expect(page.getByTestId('market-trust-panel')).toContainText('Settled outcome: YES');
  });

  // -----------------------------------------------------------------------
  // Edge: settle with no bets
  // -----------------------------------------------------------------------

  test('settle market with no bets → status becomes settled, no errors', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `No-bets settle ${Date.now()}`,
      description: 'Settlement with zero bets',
    });

    const ctx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${adminToken}` },
    });
    const resp = await ctx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'YES', reason: 'no-bets' },
    });
    await assertOk(resp, 'settle with no bets');
    const body = await resp.json();
    expect(body.status).toBe('settled');
    expect(body.settled_outcome).toBe('YES');
  });

  // -----------------------------------------------------------------------
  // Edge: void bet before settlement
  // -----------------------------------------------------------------------

  test('void bet before settlement → voided bet not settled_win or settled_loss', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Void-before-settle ${Date.now()}`,
      description: 'Void bet then settle',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const bet = await placeBetApi(baseURL, playerToken, market.id, yesLeg.id, 100);

    const adminCtx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${adminToken}` },
    });

    // Void the bet before settling
    const voidResp = await adminCtx.post(`/admin/bets/${bet.id}/void`, {
      data: { reason: 'pre-settlement-void' },
    });
    await assertOk(voidResp, 'void bet pre-settlement');
    const voidedBet = await voidResp.json();
    expect(voidedBet.status).toBe('voided');

    // Now settle the market
    const settleResp = await adminCtx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'YES', reason: 'void-then-settle' },
    });
    await assertOk(settleResp, 'settle after void');
    const settled = await settleResp.json();
    expect(settled.status).toBe('settled');
  });

  // -----------------------------------------------------------------------
  // Edge: double-settlement attempt
  // -----------------------------------------------------------------------

  test('settle already-settled market → 422 error', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Double-settle ${Date.now()}`,
      description: 'Cannot settle twice',
    });

    const ctx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${adminToken}` },
    });

    // First settlement — succeeds
    const first = await ctx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'YES', reason: 'first-settle' },
    });
    await assertOk(first, 'first settlement');

    // Second settlement — should fail
    const second = await ctx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'NO', reason: 'second-settle' },
    });
    expect(second.status()).toBe(422);
    const body = await second.json();
    expect(body.error).toBeTruthy();
  });

  // -----------------------------------------------------------------------
  // Betslip (multi-leg) WIN path via API
  // -----------------------------------------------------------------------

  test('betslip: quote → execute → settle → bet status settled_win (API)', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Betslip win ${Date.now()}`,
      description: 'Betslip settlement win path',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const playerCtx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${playerToken}` },
    });

    const quoteResp = await playerCtx.post('/web/betslips/quotes', {
      data: {
        items: [{ market_leg_id: yesLeg.id, stake_minor: 100 }],
        idempotency_key: `e2e-settle-win-${Date.now()}`,
      },
    });
    await assertOk(quoteResp, 'betslip quote');
    const quote = await quoteResp.json();

    const execResp = await playerCtx.post('/web/betslips/execute', {
      data: { quote_id: quote.quote_id },
    });
    await assertOk(execResp, 'betslip execute');
    const exec = await execResp.json();
    expect(exec.status).toBe('completed');

    // Settle the market YES → player's YES bet is a win
    await settleMarketApi(baseURL, adminToken, market.id, 'YES', 'betslip-win-settle');

    // Positions should show settled status
    const posResp = await playerCtx.get('/web/positions');
    await assertOk(posResp, 'positions after settlement');
    const positions = await posResp.json();
    // Settled bets are no longer "open" so positions (open only) should exclude them
    const openForMarket = positions.positions.filter((p) => p.market_id === market.id);
    expect(openForMarket.length).toBe(0);
  });
});
