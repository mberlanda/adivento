// permissions.spec.js — Table-driven role/permission access matrix tests.
// All tests use the `request` fixture (no browser) for speed.
//
// Permission matrix (from role_permissions.yml):
//   admin:     ALL permissions
//   moderator: backoffice.access, bet.void, risk.read, market.read, market.leg.create,
//              market.settle, wallet.faucet.review, template.manage
//              (NOT market.create, market.update, bet.place)
//   player:    bet.place only

const { test, expect, request } = require('@playwright/test');
const { USERS } = require('./helpers/common');
const { loginApi } = require('./helpers/api');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function getSessionCookie(baseURL, email, password) {
  const ctx = await request.newContext({ baseURL });
  const resp = await ctx.post('/signin', {
    data: { email, password },
    maxRedirects: 0,
  });
  // Rails redirects on success; 302 means login succeeded
  const cookie = resp.headers()['set-cookie'] || '';
  await ctx.dispose();
  return cookie;
}

async function getBearerToken(baseURL, email, password) {
  const { token } = await loginApi(baseURL, email, password);
  return token;
}

// ---------------------------------------------------------------------------
// Build MATRIX lazily (tokens fetched inside test body using baseURL fixture)
// ---------------------------------------------------------------------------

// We define the matrix as rows describing what to do; tokens/cookies are
// resolved at runtime inside each test via `baseURL`.

const MATRIX = [
  // ---- Backoffice HTML routes (session cookie, HTML responses) ----
  {
    desc: 'admin can access GET /backoffice (backoffice.access)',
    role: 'admin',
    method: 'get',
    path: '/backoffice',
    expectedStatus: 200,
    useBearer: false,
  },
  {
    desc: 'moderator can access GET /backoffice (backoffice.access)',
    role: 'moderator',
    method: 'get',
    path: '/backoffice',
    expectedStatus: 200,
    useBearer: false,
  },
  {
    desc: 'player is redirected from GET /backoffice (no backoffice.access)',
    role: 'player',
    method: 'get',
    path: '/backoffice',
    expectedStatus: 302,
    useBearer: false,
  },
  {
    desc: 'admin can access GET /backoffice/markets (market.read)',
    role: 'admin',
    method: 'get',
    path: '/backoffice/markets',
    expectedStatus: 200,
    useBearer: false,
  },
  {
    desc: 'moderator can access GET /backoffice/markets (market.read)',
    role: 'moderator',
    method: 'get',
    path: '/backoffice/markets',
    expectedStatus: 200,
    useBearer: false,
  },
  {
    desc: 'player is redirected from GET /backoffice/markets (no backoffice.access)',
    role: 'player',
    method: 'get',
    path: '/backoffice/markets',
    expectedStatus: 302,
    useBearer: false,
  },

  // ---- JWT routes: POST /admin/markets (market.create) ----
  {
    desc: 'admin can POST /admin/markets (market.create)',
    role: 'admin',
    method: 'post',
    path: '/admin/markets',
    body: { question: `perm-matrix-admin-${Date.now()}`, description: 'test' },
    expectedStatus: 201,
    useBearer: true,
  },
  {
    desc: 'moderator gets 403 on POST /admin/markets (no market.create)',
    role: 'moderator',
    method: 'post',
    path: '/admin/markets',
    body: { question: `perm-matrix-mod-${Date.now()}`, description: 'test' },
    expectedStatus: 403,
    useBearer: true,
  },
  {
    desc: 'player gets 403 on POST /admin/markets (no market.create)',
    role: 'player',
    method: 'post',
    path: '/admin/markets',
    body: { question: `perm-matrix-player-${Date.now()}`, description: 'test' },
    expectedStatus: 403,
    useBearer: true,
  },
  {
    desc: 'unauthenticated POST /admin/markets returns 401',
    role: null,
    method: 'post',
    path: '/admin/markets',
    body: { question: 'unauth', description: 'test' },
    expectedStatus: 401,
    useBearer: false,
  },

  // ---- JWT routes: GET /wallet (authenticated only) ----
  {
    desc: 'player can GET /wallet (authenticated)',
    role: 'player',
    method: 'get',
    path: '/wallet',
    expectedStatus: 200,
    useBearer: true,
  },
  {
    desc: 'admin can GET /wallet (authenticated)',
    role: 'admin',
    method: 'get',
    path: '/wallet',
    expectedStatus: 200,
    useBearer: true,
  },
  {
    desc: 'unauthenticated GET /wallet returns 401',
    role: null,
    method: 'get',
    path: '/wallet',
    expectedStatus: 401,
    useBearer: false,
  },

  // ---- JWT routes: POST /faucet_requests (authenticated only) ----
  {
    desc: 'player can POST /faucet_requests (authenticated)',
    role: 'player',
    method: 'post',
    path: '/faucet_requests',
    body: { amount_minor: 100 },
    expectedStatus: 201,
    useBearer: true,
  },
  {
    desc: 'admin can POST /faucet_requests (authenticated)',
    role: 'admin',
    method: 'post',
    path: '/faucet_requests',
    body: { amount_minor: 100 },
    expectedStatus: 201,
    useBearer: true,
  },
  {
    desc: 'unauthenticated POST /faucet_requests returns 401',
    role: null,
    method: 'post',
    path: '/faucet_requests',
    body: { amount_minor: 100 },
    expectedStatus: 401,
    useBearer: false,
  },

  // ---- JWT routes: POST /admin/faucet_requests/:id/approve (wallet.faucet.review) ----
  // We don't need a real ID to test the permission gate — 403 fires before the record lookup
  {
    desc: 'admin can reach POST /admin/faucet_requests/:id/approve (wallet.faucet.review) — 404 expected (no record)',
    role: 'admin',
    method: 'post',
    path: '/admin/faucet_requests/0/approve',
    body: {},
    expectedStatus: 404,
    useBearer: true,
  },
  {
    desc: 'moderator can reach POST /admin/faucet_requests/:id/approve (wallet.faucet.review) — 404 expected (no record)',
    role: 'moderator',
    method: 'post',
    path: '/admin/faucet_requests/0/approve',
    body: {},
    expectedStatus: 404,
    useBearer: true,
  },
  {
    desc: 'player gets 403 on POST /admin/faucet_requests/:id/approve (no wallet.faucet.review)',
    role: 'player',
    method: 'post',
    path: '/admin/faucet_requests/0/approve',
    body: {},
    expectedStatus: 403,
    useBearer: true,
  },
  {
    desc: 'unauthenticated POST /admin/faucet_requests/:id/approve returns 401',
    role: null,
    method: 'post',
    path: '/admin/faucet_requests/0/approve',
    body: {},
    expectedStatus: 401,
    useBearer: false,
  },

  // ---- JWT routes: POST /admin/bets/:id/void (bet.void) ----
  {
    desc: 'admin can reach POST /admin/bets/:id/void (bet.void) — 404 expected (no record)',
    role: 'admin',
    method: 'post',
    path: '/admin/bets/0/void',
    body: { reason: 'test' },
    expectedStatus: 404,
    useBearer: true,
  },
  {
    desc: 'moderator can reach POST /admin/bets/:id/void (bet.void) — 404 expected (no record)',
    role: 'moderator',
    method: 'post',
    path: '/admin/bets/0/void',
    body: { reason: 'test' },
    expectedStatus: 404,
    useBearer: true,
  },
  {
    desc: 'player gets 403 on POST /admin/bets/:id/void (no bet.void)',
    role: 'player',
    method: 'post',
    path: '/admin/bets/0/void',
    body: { reason: 'test' },
    expectedStatus: 403,
    useBearer: true,
  },
  {
    desc: 'unauthenticated POST /admin/bets/:id/void returns 401',
    role: null,
    method: 'post',
    path: '/admin/bets/0/void',
    body: { reason: 'test' },
    expectedStatus: 401,
    useBearer: false,
  },
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test.describe('Role and permission access matrix', () => {
  // Token/cookie cache per test run (populated lazily, keyed by role+type)
  const cache = {};

  async function resolveAuth(baseURL, row) {
    if (!row.role) return {};

    const user = USERS[row.role];

    if (row.useBearer) {
      const cacheKey = `bearer:${row.role}`;
      if (!cache[cacheKey]) {
        cache[cacheKey] = await getBearerToken(baseURL, user.email, user.password);
      }
      return { headers: { Authorization: `Bearer ${cache[cacheKey]}` } };
    } else {
      const cacheKey = `cookie:${row.role}`;
      if (!cache[cacheKey]) {
        cache[cacheKey] = await getSessionCookie(baseURL, user.email, user.password);
      }
      return { headers: { Cookie: cache[cacheKey] } };
    }
  }

  for (const row of MATRIX) {
    test(row.desc, async ({ baseURL }) => {
      const ctx = await request.newContext({ baseURL, maxRedirects: 0 });
      try {
        const auth = await resolveAuth(baseURL, row);
        const opts = { ...auth };
        if (row.body) opts.data = row.body;

        let response;
        if (row.method === 'get') {
          response = await ctx.get(row.path, opts);
        } else if (row.method === 'post') {
          response = await ctx.post(row.path, opts);
        } else {
          throw new Error(`Unsupported method: ${row.method}`);
        }

        expect(response.status(), `${row.desc} — expected ${row.expectedStatus}, got ${response.status()}`).toBe(row.expectedStatus);
      } finally {
        await ctx.dispose();
      }
    });
  }
});
