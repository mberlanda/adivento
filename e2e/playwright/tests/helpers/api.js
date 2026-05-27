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

module.exports = {
  loginApi,
  createMarketViaAdminApi,
};
