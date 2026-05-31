// error-paths.spec.js — Negative/error path tests. All API-only, no browser.
// Covers: unauthenticated access, wrong-permission, invalid business operations.

const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi, createTestPlayer, fundPlayer } = require('./helpers/api');
const { USERS, assertOk } = require('./helpers/common');

test.describe('API error paths', () => {
  test('unauthenticated POST /admin/markets returns 401', async ({ baseURL }) => {
    const ctx = await request.newContext({ baseURL });
    const resp = await ctx.post('/admin/markets', {
      data: { question: 'no-auth market', description: 'test' },
    });
    expect(resp.status()).toBe(401);
    await ctx.dispose();
  });

  test('unauthenticated GET /wallet returns 401', async ({ baseURL }) => {
    const ctx = await request.newContext({ baseURL });
    const resp = await ctx.get('/wallet');
    expect(resp.status()).toBe(401);
    await ctx.dispose();
  });

  test('player JWT on POST /admin/markets returns 403 (has token, wrong permission)', async ({ baseURL }) => {
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const ctx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${playerToken}` },
    });
    const resp = await ctx.post('/admin/markets', {
      data: { question: 'player-create attempt', description: 'test' },
    });
    expect(resp.status()).toBe(403);
    await ctx.dispose();
  });

  test('place bet on draft market (not open) returns 422', async ({ baseURL }) => {
    // Create market but do NOT open it (skip the status:open step)
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const ctx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${adminToken}` },
    });

    // Create market (stays in draft)
    const createResp = await ctx.post('/admin/markets', {
      data: { question: `Draft bet test ${Date.now()}`, description: 'test' },
    });
    await assertOk(createResp, 'create draft market');
    const market = await createResp.json();

    // Fetch full details to get leg IDs
    const showResp = await ctx.get(`/admin/markets/${market.id}`);
    await assertOk(showResp, 'show draft market');
    const fullMarket = await showResp.json();
    const yesLeg = fullMarket.legs.find((l) => l.label === 'YES');
    expect(yesLeg).toBeTruthy();

    // Place bet as player — market is draft → should fail
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const playerCtx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${playerToken}` },
    });
    const betResp = await playerCtx.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 100 },
    });
    expect(betResp.status()).toBe(422);
    const body = await betResp.json();
    expect(body.error || (body.errors && body.errors.length > 0)).toBeTruthy();

    await ctx.dispose();
    await playerCtx.dispose();
  });

  test('place bet with stake_minor=0 returns 422', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Zero stake test ${Date.now()}`,
      description: 'test',
    });
    const yesLeg = market.legs.find((l) => l.label === 'YES');

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const ctx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${playerToken}` },
    });
    const resp = await ctx.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 0 },
    });
    expect(resp.status()).toBe(422);
    await ctx.dispose();
  });

  test('settle already-settled market returns 422', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Double settle test ${Date.now()}`,
      description: 'test',
    });

    const ctx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${adminToken}` },
    });

    // First settlement — should succeed
    const firstSettle = await ctx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'YES', reason: 'first' },
    });
    await assertOk(firstSettle, 'first settle');

    // Second settlement on same market — should fail
    const secondSettle = await ctx.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'NO', reason: 'second' },
    });
    expect(secondSettle.status()).toBe(422);
    const body = await secondSettle.json();
    expect(body.error).toBeTruthy();

    await ctx.dispose();
  });

  test('login with wrong password returns 401', async ({ baseURL }) => {
    const ctx = await request.newContext({ baseURL });
    const resp = await ctx.post('/auth/login', {
      data: { email: USERS.player.email, password: 'wrong-password' },
    });
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.error).toBeTruthy();
    await ctx.dispose();
  });

  // D3 — CLOB trading-state guard: orders rejected on non-open markets
  test('CLOB order on draft market returns 422 with "Market is not open" (admin API)', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const ctx = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${adminToken}` },
    });

    // Create a CLOB market but do NOT open it (stays draft)
    const createResp = await ctx.post('/admin/markets', {
      data: {
        question: `Draft CLOB guard test ${Date.now()}`,
        description: 'test',
        mechanism_type: 'clob',
        taker_fee_bps: 70,
        liability_cap_minor: 500000,
      },
    });
    await assertOk(createResp, 'create draft CLOB market');
    const market = await createResp.json();

    // Get admin user id
    const meResp = await ctx.get('/auth/me');
    const { id: adminUserId } = await meResp.json();

    const orderResp = await ctx.post(`/admin/markets/${market.id}/orders`, {
      data: { user_id: adminUserId, side: 'YES', price_cents: 50, quantity: 1, time_in_force: 'GTC' },
    });

    expect(orderResp.status()).toBe(422);
    const body = await orderResp.json();
    expect(body.errors).toContain('Market is not open');

    await ctx.dispose();
  });

  // D4 — OrderCancellationService: duplicate cancel returns 422
  test('duplicate web CLOB order cancel returns 422', async ({ baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Dup cancel test ${Date.now()}`,
      description: 'test',
      mechanism_type: 'clob',
      taker_fee_bps: 70,
      liability_cap_minor: 500000,
    });

    // Create and fund a test player
    const player = await createTestPlayer(baseURL, 'dupecancel');
    await fundPlayer(baseURL, player.token, adminToken, 10000);

    const yesLeg = market.legs.find((l) => l.label === 'YES');

    // Player places a CLOB order (resting, no counterparty)
    const placeCtx = await request.newContext({ baseURL });
    const placeResp = await placeCtx.post(`/web/markets/${market.id}/orders`, {
      form: { side: 'YES', price_cents: 40, quantity: 1, time_in_force: 'GTC' },
      headers: { Authorization: `Bearer ${player.token}`, Accept: 'application/json' },
    });
    await assertOk(placeResp, 'place CLOB order');
    const orderBody = await placeResp.json();
    const orderId = orderBody.order_id;
    await placeCtx.dispose();

    // First cancel — succeeds
    const cancelCtx = await request.newContext({ baseURL });
    const firstCancel = await cancelCtx.delete(`/web/orders/${orderId}`, {
      headers: { Authorization: `Bearer ${player.token}`, Accept: 'application/json' },
    });
    expect(firstCancel.status()).toBe(200);

    // Second cancel — must return 422
    const secondCancel = await cancelCtx.delete(`/web/orders/${orderId}`, {
      headers: { Authorization: `Bearer ${player.token}`, Accept: 'application/json' },
    });
    expect(secondCancel.status()).toBe(422);
    const errBody = await secondCancel.json();
    expect(errBody.error).toBeTruthy();

    await cancelCtx.dispose();
  });
});
