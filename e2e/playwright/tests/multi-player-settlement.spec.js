// multi-player-settlement.spec.js
//
// Table-driven multi-player settlement tests across all 4 mechanism types.
// Setup (player creation, funding, bet placement) is fully API-driven.
// Verification (balance direction, settled outcome) is UI-driven per player.
//
// outcome is always 'YES', so side === 'YES' → winner, side === 'NO' → loser.
//
// Balance assertion strategy (avoids fixed-odds "max-odds = break-even" quirk):
//   Winners: balance_after_settlement > balance_AFTER_BET  (payout credited)
//   Losers:  balance_after_settlement < balance_BEFORE_BET (stake lost)
//
// LMSR v1: individual payouts are deferred; only settled-outcome visibility is
// asserted for LMSR scenarios.

const { test, expect, request } = require('@playwright/test');
const {
  loginApi,
  createMarketViaAdminApi,
  createTestPlayer,
  fundPlayer,
  fundAdmin,
  walletBalance,
} = require('./helpers/api');
const { USERS, signInUi, assertOk } = require('./helpers/common');

// ─── Scenario table ───────────────────────────────────────────────────────────

const SCENARIOS = [
  {
    name: 'larger winner, smaller winner, loser',
    players: [
      { tag: 'big_winner',   side: 'YES', stake: 500 },
      { tag: 'small_winner', side: 'YES', stake: 200 },
      { tag: 'loser',        side: 'NO',  stake: 300 },
    ],
    outcome: 'YES',
  },
  {
    name: 'single winner, two losers',
    players: [
      { tag: 'winner',   side: 'YES', stake: 300 },
      { tag: 'loser_a',  side: 'NO',  stake: 200 },
      { tag: 'loser_b',  side: 'NO',  stake: 400 },
    ],
    outcome: 'YES',
  },
  {
    name: 'only winners',
    players: [
      { tag: 'winner_a', side: 'YES', stake: 100 },
      { tag: 'winner_b', side: 'YES', stake: 200 },
    ],
    outcome: 'YES',
  },
  {
    name: 'only losers',
    players: [
      { tag: 'loser_a', side: 'NO', stake: 100 },
      { tag: 'loser_b', side: 'NO', stake: 200 },
    ],
    outcome: 'YES',
  },
];

// ─── Shared helpers ───────────────────────────────────────────────────────────

// Parse balance integer from UI text ("1,234" → 1234)
function parseUiBalance(text) {
  return parseInt(text.replace(/\D/g, ''), 10);
}

// Create all players for a scenario, fund each, return enriched specs
async function setupPlayers(baseURL, scenario, adminToken) {
  const players = [];
  for (const spec of scenario.players) {
    const player = await createTestPlayer(baseURL, `${spec.tag}_${Date.now()}`);
    await fundPlayer(baseURL, player.token, adminToken);
    players.push({ ...spec, ...player });
  }
  return players;
}

// Capture available wallet balances for all players (API-based)
async function captureBalances(baseURL, players) {
  const map = {};
  for (const p of players) {
    map[p.tag] = await walletBalance(baseURL, p.token);
  }
  return map;
}

// Settle market via admin API
async function settleMarket(baseURL, adminToken, marketId, outcome) {
  const ctx = await request.newContext({ baseURL });
  const resp = await ctx.post(`/admin/markets/${marketId}/settle`, {
    data: { outcome, reason: 'e2e-multi-player' },
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  await assertOk(resp, `settle market (${outcome})`);
  await ctx.dispose();
}

// POST to a web endpoint with JWT Bearer auth (skips CSRF) and Accept: JSON.
// Buffers ok/status/text before disposing the context so assertOk can read the
// failure body without keeping the context alive.
async function webPost(baseURL, token, path, formData) {
  const ctx = await request.newContext({ baseURL });
  try {
    const resp = await ctx.post(path, {
      form: formData,
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
    });
    const ok = resp.ok();
    const status = resp.status();
    const text = ok ? '' : await resp.text();
    return { ok: () => ok, status: () => status, text: async () => text };
  } finally {
    await ctx.dispose();
  }
}

// For each player, open an isolated browser context, sign in, navigate to the
// profile page and assert:
//   winners: UI balance > balancesAfterBets[tag]  (payout credited by settlement)
//   losers:  UI balance < balancesBefore[tag]     (stake was deducted and not returned)
async function assertBalancesInUi(browser, baseURL, players, balancesBefore, balancesAfterBets, outcome) {
  for (const player of players) {
    const ctx = await browser.newContext({ baseURL });
    const pg = await ctx.newPage();

    await signInUi(pg, player.email, player.password);
    await pg.goto('/web/profile');

    const walletPanel = pg.getByTestId('wallet-balance-panel');
    await expect(walletPanel).toBeVisible();

    const availableEl = pg.getByTestId('wallet-available');
    await expect(availableEl).toBeVisible();

    const balanceUi = parseUiBalance(await availableEl.innerText());
    const isWinner = player.side === outcome;

    if (isWinner) {
      expect(
        balanceUi,
        `${player.tag} (${player.side}) → winner: balance should increase after payout (was ${balancesAfterBets[player.tag]})`,
      ).toBeGreaterThan(balancesAfterBets[player.tag]);
    } else {
      expect(
        balanceUi,
        `${player.tag} (${player.side}) → loser: balance should be below pre-bet level (was ${balancesBefore[player.tag]})`,
      ).toBeLessThan(balancesBefore[player.tag]);
    }

    await ctx.close();
  }
}

// For LMSR (v1: no individual payouts): each player signs in and checks that the
// market-trust-panel shows the correct settled outcome.
async function assertSettledOutcomeInUi(browser, baseURL, players, marketId, outcome) {
  for (const player of players) {
    const ctx = await browser.newContext({ baseURL });
    const pg = await ctx.newPage();

    await signInUi(pg, player.email, player.password);
    await pg.goto(`/web/markets/${marketId}`);

    const panel = pg.getByTestId('market-trust-panel');
    await expect(panel).toBeVisible();
    await expect(panel).toContainText(`Settled outcome: ${outcome}`);

    await ctx.close();
  }
}

// ─── Fixed-odds ───────────────────────────────────────────────────────────────
// Fixed-odds legs have a maximum odds_minor of 10 000 (1:1, break-even at best).
// Winners receive a payout equal to their stake; losers receive nothing.
// The winner assertion compares to balance-after-bet (payout received),
// the loser assertion compares to balance-before-bet (stake not returned).

test.describe('Fixed-odds multi-player settlement', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  });

  for (const scenario of SCENARIOS) {
    test(scenario.name, async ({ browser, baseURL }) => {
      const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);

      const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
        question: `[FO-multi: ${scenario.name}] ${Date.now()}`,
        description: 'Fixed-odds multi-player E2E',
        mechanism_type: 'fixed_odds',
        fee_bps: 0,
        liability_cap_minor: 1000000,
      });

      const players = await setupPlayers(baseURL, scenario, adminToken);
      const balancesBefore = await captureBalances(baseURL, players);

      // Place fixed-odds bets via the non-namespaced JWT endpoint
      const betCtx = await request.newContext({ baseURL });
      for (const player of players) {
        const leg = market.legs.find((l) => l.label === player.side);
        const resp = await betCtx.post(`/markets/${market.id}/bets`, {
          data: { market_leg_id: leg.id, stake_minor: player.stake },
          headers: { Authorization: `Bearer ${player.token}` },
        });
        await assertOk(resp, `fixed-odds bet for ${player.tag}`);
      }
      await betCtx.dispose();

      const balancesAfterBets = await captureBalances(baseURL, players);

      await settleMarket(baseURL, adminToken, market.id, scenario.outcome);
      await assertBalancesInUi(browser, baseURL, players, balancesBefore, balancesAfterBets, scenario.outcome);
    });
  }
});

// ─── Parimutuel ───────────────────────────────────────────────────────────────
// Pool must have both YES and NO stakes for meaningful settlement:
//   "only winners" → inject admin NO so the payout ratio > 1 (winners profit)
//   "only losers"  → inject admin YES so the winning pool is non-zero
//                    (without this the service refunds everyone)

test.describe('Parimutuel multi-player settlement', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  });

  for (const scenario of SCENARIOS) {
    test(scenario.name, async ({ browser, baseURL }) => {
      const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);

      const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
        question: `[PARI-multi: ${scenario.name}] ${Date.now()}`,
        description: 'Parimutuel multi-player E2E',
        mechanism_type: 'parimutuel',
        takeout_bps: 1500,
        liability_cap_minor: 1000000,
      });

      const hasYes = scenario.players.some((p) => p.side === 'YES');
      const hasNo  = scenario.players.some((p) => p.side === 'NO');

      // For single-sided scenarios a fresh market-maker player provides the opposite pool:
      //   "only winners" (all YES) → needs NO pool so payout ratio > 1
      //   "only losers"  (all NO)  → needs YES pool to prevent zero-winning-pool refund
      if (!hasNo || !hasYes) {
        const mm = await createTestPlayer(baseURL, `mm_${Date.now()}`);
        await fundPlayer(baseURL, mm.token, adminToken, 5000);

        if (!hasNo) {
          const r = await webPost(baseURL, mm.token, `/web/markets/${market.id}/parimutuel_bets`, { side: 'NO', stake_minor: 1000 });
          await assertOk(r, 'market-maker NO pool injection');
        }
        if (!hasYes) {
          const r = await webPost(baseURL, mm.token, `/web/markets/${market.id}/parimutuel_bets`, { side: 'YES', stake_minor: 100 });
          await assertOk(r, 'market-maker YES pool injection');
        }
      }

      const players = await setupPlayers(baseURL, scenario, adminToken);
      const balancesBefore = await captureBalances(baseURL, players);

      for (const player of players) {
        const resp = await webPost(baseURL, player.token, `/web/markets/${market.id}/parimutuel_bets`, {
          side: player.side,
          stake_minor: player.stake,
        });
        await assertOk(resp, `parimutuel stake for ${player.tag}`);
      }

      const balancesAfterBets = await captureBalances(baseURL, players);

      await settleMarket(baseURL, adminToken, market.id, scenario.outcome);
      await assertBalancesInUi(browser, baseURL, players, balancesBefore, balancesAfterBets, scenario.outcome);
    });
  }
});

// ─── CLOB ─────────────────────────────────────────────────────────────────────
// Uses price_cents = 50 for all orders (YES@50 + NO@50 = 100 → always matches).
// Order sequencing to guarantee fills:
//   1. Admin injects opposite-side resting orders if either side lacks counterparty.
//   2. NO player orders are placed first (resting makers).
//   3. YES player orders are placed last (incoming takers, fill immediately).
//
// Balance guarantees:
//   Winners (YES, filled): payout = filled_qty × 100 > stake (net positive)
//   Losers  (NO, filled):  payout = 0, stake committed → net negative
//   Unfilled portions are cancelled at settlement with a refund, which does NOT
//   flip the direction for either side.
//
// Admin wallet is topped up before each test to absorb the liquidity cost.

const CLOB_PRICE = 50;
const clobQty = (stake) => Math.max(1, Math.floor(stake / CLOB_PRICE));

test.describe('CLOB multi-player settlement', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  });

  for (const scenario of SCENARIOS) {
    test(scenario.name, async ({ browser, baseURL }) => {
      const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);

      // Ensure admin wallet has enough for liquidity orders
      await fundAdmin(baseURL, adminToken);

      const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
        question: `[CLOB-multi: ${scenario.name}] ${Date.now()}`,
        description: 'CLOB multi-player E2E',
        mechanism_type: 'clob',
        taker_fee_bps: 70,
        liability_cap_minor: 1000000,
      });

      // Get admin user ID for the admin-API liquidity order
      const adminCtx = await request.newContext({ baseURL });
      const meResp = await adminCtx.get('/auth/me', { headers: { Authorization: `Bearer ${adminToken}` } });
      const { id: adminId } = await meResp.json();
      await adminCtx.dispose();

      const yesQty = scenario.players.filter((p) => p.side === 'YES').reduce((s, p) => s + clobQty(p.stake), 0);
      const noQty  = scenario.players.filter((p) => p.side === 'NO').reduce((s, p) => s + clobQty(p.stake), 0);

      async function injectAdminOrder(side, qty) {
        const ctx = await request.newContext({ baseURL });
        const resp = await ctx.post(`/admin/markets/${market.id}/orders`, {
          data: { user_id: adminId, side, price_cents: CLOB_PRICE, quantity: qty, time_in_force: 'GTC' },
          headers: { Authorization: `Bearer ${adminToken}` },
        });
        await assertOk(resp, `admin ${side} order injection (${qty} @ ${CLOB_PRICE})`);
        await ctx.dispose();
      }

      // Balance: inject admin resting orders on whichever side is undersupplied
      if (noQty < yesQty) await injectAdminOrder('NO', yesQty - noQty);
      if (yesQty < noQty) await injectAdminOrder('YES', noQty - yesQty);

      const players = await setupPlayers(baseURL, scenario, adminToken);
      const balancesBefore = await captureBalances(baseURL, players);

      // NO players first (resting makers), YES players second (takers → immediate fills)
      const ordered = [
        ...players.filter((p) => p.side === 'NO'),
        ...players.filter((p) => p.side === 'YES'),
      ];

      for (const player of ordered) {
        const resp = await webPost(baseURL, player.token, `/web/markets/${market.id}/orders`, {
          side: player.side,
          price_cents: CLOB_PRICE,
          quantity: clobQty(player.stake),
          time_in_force: 'GTC',
        });
        await assertOk(resp, `CLOB order for ${player.tag}`);
      }

      const balancesAfterBets = await captureBalances(baseURL, players);

      await settleMarket(baseURL, adminToken, market.id, scenario.outcome);
      await assertBalancesInUi(browser, baseURL, players, balancesBefore, balancesAfterBets, scenario.outcome);
    });
  }
});

// ─── LMSR ─────────────────────────────────────────────────────────────────────
// LmsrSettlementHandler v1 marks the market settled but does not credit
// individual position holders (individual payouts deferred to v2).
// Only the settled-outcome visibility is asserted; each player checks the
// market-trust-panel in their own browser session.

const lmsrQty = (stake) => Math.max(1, Math.floor(stake / 100));

test.describe('LMSR multi-player settlement (v1: settled-outcome visibility only)', () => {
  test.beforeEach(async ({ page }) => {
    page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  });

  for (const scenario of SCENARIOS) {
    test(scenario.name, async ({ browser, baseURL }) => {
      const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);

      const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
        question: `[LMSR-multi: ${scenario.name}] ${Date.now()}`,
        description: 'LMSR multi-player E2E',
        mechanism_type: 'lmsr',
        liquidity_subsidy_minor: 100000,
        spread_fee_bps: 100,
        liability_cap_minor: 1000000,
      });

      const players = await setupPlayers(baseURL, scenario, adminToken);

      for (const player of players) {
        const resp = await webPost(baseURL, player.token, `/web/markets/${market.id}/lmsr_trades`, {
          side: player.side,
          quantity: lmsrQty(player.stake),
        });
        await assertOk(resp, `LMSR trade for ${player.tag}`);
      }

      await settleMarket(baseURL, adminToken, market.id, scenario.outcome);
      await assertSettledOutcomeInUi(browser, baseURL, players, market.id, scenario.outcome);
    });
  }
});
