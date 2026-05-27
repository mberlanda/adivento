/**
 * common.js — shared constants, helpers, and utilities for all Playwright specs.
 *
 * Auth mechanism:
 *   - Admin API endpoints (/admin/*, /auth/login) use JWT Bearer tokens.
 *   - Backoffice HTML surface (/backoffice/*) uses session cookies set by POST /signin.
 *   - Web HTML surface (/web/*, /) accepts both session cookies (for HTML) and JWT Bearer
 *     (for JSON API calls like /web/betslips/quotes, /web/positions, etc.).
 *
 * Seed data (see db/seeds.rb and e2e/playwright/tests/global-setup.js):
 *   - admin@adivento.local    role=admin     password=password123  wallet=0
 *   - moderator@adivento.local role=moderator password=password123  wallet=0
 *   - player@adivento.local   role=player    password=password123  wallet=10,000 minor
 */

const { request, expect } = require('@playwright/test');

// ---------------------------------------------------------------------------
// Known seed users
// ---------------------------------------------------------------------------

const USERS = {
  admin: {
    email: process.env.E2E_ADMIN_EMAIL || 'admin@adivento.local',
    password: process.env.E2E_ADMIN_PASSWORD || 'password123',
  },
  moderator: {
    email: process.env.E2E_MODERATOR_EMAIL || 'moderator@adivento.local',
    password: process.env.E2E_MODERATOR_PASSWORD || 'password123',
  },
  player: {
    email: process.env.E2E_PLAYER_EMAIL || 'player@adivento.local',
    password: process.env.E2E_PLAYER_PASSWORD || 'password123',
  },
};

// ---------------------------------------------------------------------------
// Assertion helper — surface HTTP errors with body
// ---------------------------------------------------------------------------

async function assertOk(response, label) {
  if (!response.ok()) {
    let body = '';
    try { body = await response.text(); } catch (_) {}
    throw new Error(`${label} failed with HTTP ${response.status()}: ${body.slice(0, 500)}`);
  }
}

// ---------------------------------------------------------------------------
// API login — returns JWT token
// ---------------------------------------------------------------------------

async function loginApi(baseURL, email, password) {
  const context = await request.newContext({ baseURL });
  const response = await context.post('/auth/login', {
    data: { email, password },
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json();
  return { context, token: payload.token, payload };
}

// ---------------------------------------------------------------------------
// Sign in via browser UI (session cookie)
// ---------------------------------------------------------------------------

async function signInUi(page, email, password) {
  await page.goto('/signin');
  await page.getByTestId('signin-email').fill(email);
  await page.getByTestId('signin-password').fill(password);
  await page.getByTestId('signin-submit').click();
  await expect(page.getByTestId('top-nav')).toBeVisible();
}

// ---------------------------------------------------------------------------
// Create a market via admin API (auto-opens it with two YES/NO legs)
// Returns the full market payload including leg IDs.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Create a DRAFT market via admin API (does NOT open it)
// Useful for testing the "open" action separately.
// ---------------------------------------------------------------------------

async function createDraftMarketViaAdminApi(baseURL, token, attrs) {
  const context = await request.newContext({
    baseURL,
    extraHTTPHeaders: { Authorization: `Bearer ${token}` },
  });

  const response = await context.post('/admin/markets', { data: attrs });
  expect(response.ok()).toBeTruthy();
  const created = await response.json();

  // Fetch full market details
  const showResponse = await context.get(`/admin/markets/${created.id}`);
  expect(showResponse.ok()).toBeTruthy();
  const payload = await showResponse.json();

  return { context, payload };
}

// ---------------------------------------------------------------------------
// Place a bet via the markets/bets API (JWT auth)
// ---------------------------------------------------------------------------

async function placeBetApi(baseURL, token, marketId, marketLegId, stakeMinor = 100) {
  const context = await request.newContext({
    baseURL,
    extraHTTPHeaders: { Authorization: `Bearer ${token}` },
  });

  const response = await context.post(`/markets/${marketId}/bets`, {
    data: { market_leg_id: marketLegId, stake_minor: stakeMinor },
  });
  await assertOk(response, 'place bet');
  return response.json();
}

// ---------------------------------------------------------------------------
// Settle a market via admin API (JWT auth)
// ---------------------------------------------------------------------------

async function settleMarketApi(baseURL, token, marketId, outcome, reason = 'e2e-settle') {
  const context = await request.newContext({
    baseURL,
    extraHTTPHeaders: { Authorization: `Bearer ${token}` },
  });

  const response = await context.post(`/admin/markets/${marketId}/settle`, {
    data: { outcome, reason },
  });
  await assertOk(response, `settle market outcome=${outcome}`);
  return response.json();
}

// ---------------------------------------------------------------------------
// Build browser console forwarder (attach to page in beforeEach)
// ---------------------------------------------------------------------------

function attachConsoleForwarder(page) {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  page.on('requestfailed', (req) =>
    process.stdout.write(`[browser:reqfail] ${req.method()} ${req.url()} — ${req.failure()?.errorText}\n`)
  );
}

module.exports = {
  USERS,
  assertOk,
  loginApi,
  signInUi,
  createMarketViaAdminApi,
  createDraftMarketViaAdminApi,
  placeBetApi,
  settleMarketApi,
  attachConsoleForwarder,
};
