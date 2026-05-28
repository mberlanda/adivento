const { request, expect } = require('@playwright/test');

async function loginApi(baseURL, email, password) {
  const context = await request.newContext({ baseURL });
  const response = await context.post('/auth/login', {
    data: { email, password },
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json();
  return { context, token: payload.token, payload };
}

async function createMarketViaAdminApi(baseURL, token, attrs) {
  const context = await request.newContext({
    baseURL,
    extraHTTPHeaders: { Authorization: `Bearer ${token}` },
  });

  const response = await context.post('/admin/markets', { data: attrs });
  expect(response.ok()).toBeTruthy();
  const created = await response.json();

  // Open the market so bets can be placed
  const openResponse = await context.put(`/admin/markets/${created.id}`, {
    data: { status: 'open' },
  });
  expect(openResponse.ok()).toBeTruthy();

  // Fetch full market details (includes leg IDs)
  const showResponse = await context.get(`/admin/markets/${created.id}`);
  expect(showResponse.ok()).toBeTruthy();
  const payload = await showResponse.json();

  return { context, payload };
}

// Register a fresh player, return { email, password, token, id }
async function createTestPlayer(baseURL, tag) {
  const email = `e2e_${tag}_${Date.now()}@test.local`;
  const password = 'Test1234!';
  const ctx = await request.newContext({ baseURL });

  const reg = await ctx.post('/auth/register', { data: { email, password } });
  if (!reg.ok()) throw new Error(`register ${tag} failed: ${await reg.text()}`);
  const { token } = await reg.json();

  const me = await ctx.get('/auth/me', { headers: { Authorization: `Bearer ${token}` } });
  const { id } = await me.json();

  await ctx.dispose();
  return { email, password, token, id };
}

// Top-up via faucet: player creates request, admin approves
async function fundPlayer(baseURL, playerToken, adminToken, amountMinor = 20000) {
  const ctx = await request.newContext({ baseURL });

  const fResp = await ctx.post('/faucet_requests', {
    data: { amount_minor: amountMinor },
    headers: { Authorization: `Bearer ${playerToken}` },
  });
  if (!fResp.ok()) throw new Error(`faucet create failed: ${await fResp.text()}`);
  const { id: fid } = await fResp.json();

  const apResp = await ctx.post(`/admin/faucet_requests/${fid}/approve`, {
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  if (!apResp.ok()) throw new Error(`faucet approve failed: ${await apResp.text()}`);

  await ctx.dispose();
}

// Return available_minor for a player via JWT
async function walletBalance(baseURL, token) {
  const ctx = await request.newContext({ baseURL });
  const resp = await ctx.get('/wallet', { headers: { Authorization: `Bearer ${token}` } });
  const { available_minor } = await resp.json();
  await ctx.dispose();
  return available_minor;
}

// Convenience: admin self-funds (creates faucet request as admin, approves as admin)
async function fundAdmin(baseURL, adminToken, amountMinor = 100000) {
  await fundPlayer(baseURL, adminToken, adminToken, amountMinor);
}

module.exports = {
  loginApi,
  createMarketViaAdminApi,
  createTestPlayer,
  fundPlayer,
  fundAdmin,
  walletBalance,
};
