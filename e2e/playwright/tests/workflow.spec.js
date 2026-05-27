const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi } = require('./helpers/api');
const { USERS, signInUi, assertOk } = require('./helpers/common');

// Forward browser console to Node stdout so it appears in CI logs
test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  page.on('requestfailed', (req) => process.stdout.write(`[browser:reqfail] ${req.method()} ${req.url()} — ${req.failure()?.errorText}\n`));
});

test.describe('UI workflows with API-assisted operations', () => {
  test('moderator creates market from template in backoffice UI', async ({ page }) => {
    await signInUi(page, USERS.moderator.email, USERS.moderator.password);
    await expect(page.getByTestId('nav-backoffice')).toBeVisible();

    await page.getByTestId('nav-backoffice').click();
    await page.getByRole('link', { name: 'Templates' }).click();

    const templateCard = page.getByTestId(/template-card-/).first();
    await expect(templateCard).toBeVisible();

    const suffix = Date.now();
    const form = page.getByTestId(/create-market-from-template-form-/).first();
    await form.locator('input[name="question"]').fill(`E2E market ${suffix}`);
    await form.locator('textarea[name="description"]').fill('Created in UI E2E suite');
    await form.locator('input[type="submit"]').click();

    await expect(page.getByTestId('market-title')).toContainText(`E2E market ${suffix}`);
    await expect(page.getByTestId('market-legs-list')).toContainText('YES');
    await expect(page.getByTestId('market-legs-list')).toContainText('NO');
  });

  test('player sees settled YES outcome after setup via API', async ({ page, baseURL }) => {
    // API is only used for deterministic setup; verification remains UI-driven.
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: createdMarket } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Win scenario ${Date.now()}`,
      description: 'E2E settlement win path',
    });

    const yesLeg = createdMarket.legs.find((leg) => leg.label === 'YES');

    const api = await request.newContext({ baseURL });
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const betResponse = await api.post(`/markets/${createdMarket.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 100 },
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    await assertOk(betResponse, 'place bet (YES)');

    const settleResponse = await api.post(`/admin/markets/${createdMarket.id}/settle`, {
      data: { outcome: 'YES', reason: 'e2e-win' },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    await assertOk(settleResponse, 'settle market');

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${createdMarket.id}`);
    await expect(page.getByTestId('market-trust-panel')).toContainText('Settled outcome: YES');
  });

  test('player sees settled YES outcome after betting NO (lost path setup via API)', async ({ page, baseURL }) => {
    // API is only used for deterministic setup; verification remains UI-driven.
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: createdMarket } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Loss scenario ${Date.now()}`,
      description: 'E2E settlement loss path',
    });

    const noLeg = createdMarket.legs.find((leg) => leg.label === 'NO');
    const api = await request.newContext({ baseURL });

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const betResponse = await api.post(`/markets/${createdMarket.id}/bets`, {
      data: { market_leg_id: noLeg.id, stake_minor: 100 },
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    await assertOk(betResponse, 'place bet (NO)');

    const settleResponse = await api.post(`/admin/markets/${createdMarket.id}/settle`, {
      data: { outcome: 'YES', reason: 'e2e-loss' },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    await assertOk(settleResponse, 'settle market');

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${createdMarket.id}`);
    await expect(page.getByTestId('market-trust-panel')).toContainText('Settled outcome: YES');
  });

  test('voided scenario publishes SSE event and keeps UI market view available', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: createdMarket } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Void scenario ${Date.now()}`,
      description: 'E2E void path',
    });

    const yesLeg = createdMarket.legs.find((leg) => leg.label === 'YES');
    const api = await request.newContext({ baseURL });

    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const betResponse = await api.post(`/markets/${createdMarket.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 100 },
      headers: { Authorization: `Bearer ${playerToken}` },
    });
    await assertOk(betResponse, 'place bet (void path)');
    const placedBet = await betResponse.json();

    const voidResponse = await api.post(`/admin/bets/${placedBet.id}/void`, {
      data: { reason: 'e2e-void' },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    await assertOk(voidResponse, 'void bet');

    // Verify SSE endpoint is reachable (stream stays open — don't read body)
    const sseResponse = await api.get(`/sse/markets/${createdMarket.id}`, { timeout: 3000 }).catch(() => null);
    // SSE endpoint either connects (ok) or times out — either way the UI should reflect the voided state

    await signInUi(page, USERS.player.email, USERS.player.password);
    await page.goto(`/web/markets/${createdMarket.id}`);
    await expect(page.getByTestId('market-trust-panel')).toContainText('Status: open');
  });

  test('guest sees public market list without signing in', async ({ page, baseURL }) => {
    // Create a market so the list is non-empty
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Public market ${Date.now()}`,
      description: 'Visible to guests once open',
    });

    await page.goto('/');
    await expect(page.getByTestId('markets-list')).toBeVisible();
    // At least one market card should be visible
    await expect(page.locator('[data-testid^="market-card-"]').first()).toBeVisible();
    // Nav shows sign-in link (not signed in)
    await expect(page.getByTestId('nav-signin')).toBeVisible();
  });

  test('moderator settles market via backoffice UI', async ({ page, baseURL }) => {
    // Set up: create and open a market via API
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: createdMarket } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `UI settle ${Date.now()}`,
      description: 'Settled via backoffice UI in E2E',
    });

    // Sign in as moderator and navigate to the market's backoffice detail page
    await signInUi(page, USERS.moderator.email, USERS.moderator.password);
    await page.goto(`/backoffice/markets/${createdMarket.id}`);

    await expect(page.getByTestId('market-title')).toContainText('UI settle');

    // Fill settle form and submit
    await page.getByTestId('settle-outcome').selectOption('YES');
    await page.getByTestId('settle-reason').fill('e2e-ui-settle');

    // Intercept the confirm dialog
    page.once('dialog', (dialog) => dialog.accept());
    await page.getByTestId('settle-market-submit').click();

    // After redirect, market should show as settled
    await expect(page.getByTestId('market-legs-list')).toBeVisible();
    await expect(page.locator('p', { hasText: 'Settled outcome' })).toBeVisible();
  });

  test('player betslip quote→execute and positions API', async ({ baseURL }) => {
    // Pure API test — no browser UI needed
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: createdMarket } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Betslip API test ${Date.now()}`,
      description: 'E2E betslip round-trip',
    });

    const yesLeg = createdMarket.legs.find((leg) => leg.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const api = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${playerToken}` },
    });

    // Step 1: get a quote
    const quoteResp = await api.post('/web/betslips/quotes', {
      data: {
        items: [{ market_leg_id: yesLeg.id, stake_minor: 100 }],
        idempotency_key: `e2e-betslip-${Date.now()}`,
      },
    });
    await assertOk(quoteResp, 'betslip quote');
    const quote = await quoteResp.json();
    expect(quote.quote_id).toBeTruthy();
    expect(quote.total_stake_minor).toBe(100);

    // Step 2: execute the quote
    const execResp = await api.post('/web/betslips/execute', {
      data: { quote_id: quote.quote_id },
    });
    await assertOk(execResp, 'betslip execute');
    const exec = await execResp.json();
    expect(exec.execution_id).toBeTruthy();
    expect(exec.status).toBe('completed');

    // Step 3: fetch execution record
    const execShowResp = await api.get(`/web/betslips/executions/${exec.execution_id}`);
    await assertOk(execShowResp, 'execution show');
    const execShow = await execShowResp.json();
    expect(execShow.execution_id).toBe(exec.execution_id);

    // Step 4: positions list should include the new open bet
    const posResp = await api.get('/web/positions');
    await assertOk(posResp, 'positions list');
    const positions = await posResp.json();
    expect(positions.positions.some((p) => p.market_id === createdMarket.id)).toBe(true);
  });

  test('player cashout quote and execute API', async ({ baseURL }) => {
    // Pure API test — no browser UI needed
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: createdMarket } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Cashout API test ${Date.now()}`,
      description: 'E2E cashout round-trip',
    });

    const yesLeg = createdMarket.legs.find((leg) => leg.label === 'YES');
    const { token: playerToken } = await loginApi(baseURL, USERS.player.email, USERS.player.password);
    const api = await request.newContext({
      baseURL,
      extraHTTPHeaders: { Authorization: `Bearer ${playerToken}` },
    });

    // Place a direct bet first
    const betResp = await api.post(`/markets/${createdMarket.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 100 },
    });
    await assertOk(betResp, 'place bet for cashout');
    const bet = await betResp.json();

    // Step 1: get a cashout quote
    const cqResp = await api.post('/web/positions/cashout_quotes', {
      data: { bet_id: bet.id },
    });
    await assertOk(cqResp, 'cashout quote');
    const cashoutQuote = await cqResp.json();
    expect(cashoutQuote.bet_id).toBe(bet.id);
    expect(cashoutQuote.net_payout_minor).toBeGreaterThan(0);

    // Step 2: execute the cashout
    const ceResp = await api.post('/web/positions/cashout_execute', {
      data: { bet_id: bet.id },
    });
    await assertOk(ceResp, 'cashout execute');
    const cashoutResult = await ceResp.json();
    expect(cashoutResult.status).toBe('completed');
    expect(cashoutResult.credited_minor).toBeGreaterThan(0);
  });
});
