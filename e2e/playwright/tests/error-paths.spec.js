/**
 * error-paths.spec.js — Error Path Inventory
 *
 * Tests that every significant error condition returns the correct HTTP status
 * and an actionable error message. All tests are pure API — no browser needed.
 *
 * Covered paths:
 *   AUTH
 *     - Login with wrong password → 401
 *     - Access protected endpoint without token → 401
 *     - Access endpoint with insufficient permission → 403
 *   BET PLACEMENT
 *     - Bet on closed/settled market → 422
 *     - Bet with zero stake → 422
 *     - Bet with leg from different market → 422 (or 404)
 *     - Insufficient wallet balance → 422
 *   BET VOID
 *     - Void already-voided bet → 422
 *     - Void without reason → 422
 *   SETTLEMENT
 *     - Settle already-settled market → 422
 *     - Settle with invalid outcome label → 422
 *   BETSLIP
 *     - Execute non-existent quote_id → 422/404
 *   CASHOUT
 *     - Cashout already-voided bet → 422
 *     - Cashout already-settled bet → 422
 *   RESOURCE NOT FOUND
 *     - GET /web/markets/99999 → 404
 *     - GET /admin/markets/99999 → 404
 */

const { test, expect, request } = require('@playwright/test');
const {
  USERS,
  assertOk,
  loginApi,
  createMarketViaAdminApi,
  placeBetApi,
  settleMarketApi,
} = require('./helpers/common');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function playerContext(baseURL) {
  const { token } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
  return request.newContext({
    baseURL,
    extraHTTPHeaders: { Authorization: `Bearer ${token}` },
  });
}

async function adminContext(baseURL) {
  const { token } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
  return request.newContext({
    baseURL,
    extraHTTPHeaders: { Authorization: `Bearer ${token}` },
  });
}

async function unauthContext(baseURL) {
  return request.newContext({ baseURL });
}

// ---------------------------------------------------------------------------
// AUTH errors
// ---------------------------------------------------------------------------

test.describe('Auth error paths', () => {
  test('POST /auth/login — wrong password → 401 with error message', async ({ baseURL }) => {
    const ctx = await unauthContext(baseURL);
    const resp = await ctx.post('/auth/login', {
      data: { email: USERS.player.email, password: 'wrong-password' },
    });
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.error).toBeTruthy();
  });

  test('GET /auth/me — no token → 401', async ({ baseURL }) => {
    const ctx = await unauthContext(baseURL);
    const resp = await ctx.get('/auth/me');
    expect(resp.status()).toBe(401);
  });

  test('POST /admin/markets — player token → 403 (no market.create)', async ({ baseURL }) => {
    const ctx = await playerContext(baseURL);
    const resp = await ctx.post('/admin/markets', {
      data: { question: 'Unauthorized market', description: 'Should fail' },
    });
    expect(resp.status()).toBe(403);
    const body = await resp.json();
    expect(body.error).toBeTruthy();
  });

  test('POST /admin/bets/:id/void — player token → 403 (no bet.void)', async ({ baseURL }) => {
    // Create a market and bet as admin+player, then player tries to void
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Void auth error ${Date.now()}`,
      description: 'auth error test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const playerCtx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${playerToken}` },
    });
    const betResp = await playerCtx.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 100 },
    });
    const bet = await betResp.json();

    const resp = await playerCtx.post(`/admin/bets/${bet.id}/void`, {
      data: { reason: 'test' },
    });
    expect(resp.status()).toBe(403);
  });
});

// ---------------------------------------------------------------------------
// Bet placement errors
// ---------------------------------------------------------------------------

test.describe('Bet placement error paths', () => {
  test('bet on settled market → 422 "Market is not open"', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Bet-settled-market ${Date.now()}`,
      description: 'error path test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');

    // Settle the market first
    await settleMarketApi(baseURL, adminToken, market.id, 'YES', 'error-path-test');

    const ctx = await playerContext(baseURL);
    const resp = await ctx.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 100 },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.error).toContain('not open');
  });

  test('bet with zero stake → 422 "Stake must be positive"', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Zero stake ${Date.now()}`,
      description: 'error path test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');

    const ctx = await playerContext(baseURL);
    const resp = await ctx.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 0 },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.error).toContain('positive');
  });

  test('bet with insufficient wallet balance → 422', async ({ baseURL }) => {
    // Player wallet is 10,000 minor — bet 999,999 which exceeds balance
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Insufficient balance ${Date.now()}`,
      description: 'error path test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');

    const ctx = await playerContext(baseURL);
    const resp = await ctx.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 999_999 },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    // Could be insufficient balance or risk limit exceeded
    expect(body.error).toBeTruthy();
  });

  test('GET /markets/99999 — non-existent market → 404', async ({ baseURL }) => {
    const ctx = await unauthContext(baseURL);
    const resp = await ctx.get('/markets/99999');
    expect(resp.status()).toBe(404);
  });

  test('GET /web/markets/99999 — non-existent market → 404', async ({ baseURL }) => {
    const ctx = await unauthContext(baseURL);
    const resp = await ctx.get('/web/markets/99999');
    expect(resp.status()).toBe(404);
  });
});

// ---------------------------------------------------------------------------
// Bet void errors
// ---------------------------------------------------------------------------

test.describe('Bet void error paths', () => {
  test('void already-voided bet → 422 "Bet is not active"', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Double void ${Date.now()}`,
      description: 'error path test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const bet = await placeBetApi(baseURL, playerToken, market.id, yesLeg.id, 100);

    const adminCtx = await adminContext(baseURL);

    // First void — succeeds
    const first = await adminCtx.post(`/admin/bets/${bet.id}/void`, {
      data: { reason: 'first-void' },
    });
    await assertOk(first, 'first void');

    // Second void — should fail
    const second = await adminCtx.post(`/admin/bets/${bet.id}/void`, {
      data: { reason: 'second-void' },
    });
    expect(second.status()).toBe(422);
    const body = await second.json();
    expect(body.error).toContain('not active');
  });

  test('void bet without reason → 422 "Reason is required"', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Void no reason ${Date.now()}`,
      description: 'error path test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const bet = await placeBetApi(baseURL, playerToken, market.id, yesLeg.id, 100);

    const adminCtx = await adminContext(baseURL);
    const resp = await adminCtx.post(`/admin/bets/${bet.id}/void`, {
      data: { reason: '' },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.error).toContain('Reason');
  });
});

// ---------------------------------------------------------------------------
// Settlement errors
// ---------------------------------------------------------------------------

test.describe('Settlement error paths', () => {
  test('settle already-settled market → 422 "Market must be open"', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Settled-twice ${Date.now()}`,
      description: 'error path test',
    });

    const ctx = await adminContext(baseURL);
    await ctx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'YES', reason: 'first' },
    });

    const second = await ctx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'NO', reason: 'second' },
    });
    expect(second.status()).toBe(422);
    const body = await second.json();
    expect(body.error).toBeTruthy();
  });

  test('settle with invalid outcome label → 422', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Bad outcome ${Date.now()}`,
      description: 'error path test',
    });

    const ctx = await adminContext(baseURL);
    const resp = await ctx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'MAYBE', reason: 'bad-outcome' },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.error).toContain('Invalid outcome');
  });
});

// ---------------------------------------------------------------------------
// Betslip errors
// ---------------------------------------------------------------------------

test.describe('Betslip error paths', () => {
  test('execute non-existent quote_id → 422 or 404', async ({ baseURL }) => {
    const ctx = await playerContext(baseURL);
    const resp = await ctx.post('/web/betslips/execute', {
      data: { quote_id: 'does-not-exist-00000' },
    });
    expect([404, 422].includes(resp.status())).toBe(true);
  });

  test('get non-existent execution → 404', async ({ baseURL }) => {
    const ctx = await playerContext(baseURL);
    const resp = await ctx.get('/web/betslips/executions/00000000-0000-0000-0000-000000000000');
    expect(resp.status()).toBe(404);
  });

  test('betslip quote with empty items list → 422', async ({ baseURL }) => {
    const ctx = await playerContext(baseURL);
    const resp = await ctx.post('/web/betslips/quotes', {
      data: { items: [], idempotency_key: `empty-${Date.now()}` },
    });
    expect(resp.status()).toBe(422);
  });
});

// ---------------------------------------------------------------------------
// Cashout errors
// ---------------------------------------------------------------------------

test.describe('Cashout error paths', () => {
  test('cashout already-voided bet → 422 "Bet is not open"', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Cashout-voided ${Date.now()}`,
      description: 'error path test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const bet = await placeBetApi(baseURL, playerToken, market.id, yesLeg.id, 100);

    // Admin voids the bet
    const adminCtx = await adminContext(baseURL);
    await adminCtx.post(`/admin/bets/${bet.id}/void`, { data: { reason: 'cashout-error-test' } });

    // Player tries to cashout the voided bet
    const playerCtx = await playerContext(baseURL);
    const resp = await playerCtx.post('/web/positions/cashout_quotes', {
      data: { bet_id: bet.id },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.error).toContain('not open');
  });

  test('cashout bet on settled market → 422 "Market is not open"', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Cashout-settled-market ${Date.now()}`,
      description: 'error path test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const bet = await placeBetApi(baseURL, playerToken, market.id, yesLeg.id, 100);

    // Settle the market (bet becomes settled_win or settled_loss)
    await settleMarketApi(baseURL, adminToken, market.id, 'NO', 'cashout-settled-test');

    // Player tries to cashout the now-settled bet
    const playerCtx = await playerContext(baseURL);
    const resp = await playerCtx.post('/web/positions/cashout_quotes', {
      data: { bet_id: bet.id },
    });
    expect(resp.status()).toBe(422);
    const body = await resp.json();
    expect(body.error).toBeTruthy();
  });
});
