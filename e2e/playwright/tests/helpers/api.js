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
  return { context, payload: await response.json() };
}

module.exports = {
  loginApi,
  createMarketViaAdminApi,
};
