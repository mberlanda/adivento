// error-paths.spec.js — Negative/error path tests. All API-only, no browser.
// Covers: unauthenticated access, wrong-permission, invalid business operations.

const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi } = require('./helpers/api');
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
});
