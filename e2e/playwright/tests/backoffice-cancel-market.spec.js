// backoffice-cancel-market.spec.js — E2E tests for the market cancellation flow (D2 / TD-017).
// Covers: admin cancels open market via backoffice UI with wallet refund verified;
//         moderator cannot cancel (no market.cancel permission).

const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi, createTestPlayer, fundPlayer, walletBalance } = require('./helpers/api');
const { USERS, signInUi, assertOk } = require('./helpers/common');

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
});

test.describe('Backoffice market cancellation', () => {
  test('admin cancels open market and player bet stake is refunded', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { token: adminJwt } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);

    // Create a fixed-odds market
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Cancel refund E2E ${Date.now()}`,
      description: 'Market cancellation refund test',
      mechanism_type: 'fixed_odds',
      fee_bps: 100,
      liability_cap_minor: 500000,
    });

    const yesLeg = market.legs.find((l) => l.label === 'YES');

    // Create a fresh player and fund them
    const player = await createTestPlayer(baseURL, 'cancel');
    await fundPlayer(baseURL, player.token, adminToken, 10000);

    const balanceBefore = await walletBalance(baseURL, player.token);

    // Player places a bet
    const ctx = await request.newContext({ baseURL });
    const betResp = await ctx.post(`/markets/${market.id}/bets`, {
      data: { market_leg_id: yesLeg.id, stake_minor: 500 },
      headers: { Authorization: `Bearer ${player.token}` },
    });
    await assertOk(betResp, 'place bet before cancel');
    await ctx.dispose();

    const balanceAfterBet = await walletBalance(baseURL, player.token);
    expect(balanceAfterBet).toBeLessThan(balanceBefore);

    // Admin signs in via session and navigates to the backoffice market page
    await signInUi(page, USERS.admin.email, USERS.admin.password);
    await page.goto(`/backoffice/markets/${market.id}`);

    await expect(page.getByTestId('market-title')).toContainText('Cancel refund E2E');
    await expect(page.getByTestId('cancel-market-panel')).toBeVisible();

    await page.getByTestId('cancel-market-reason').fill(
      'E2E test: event abandoned due to unforeseen circumstances.',
    );

    page.once('dialog', (dialog) => dialog.accept());
    await page.getByTestId('cancel-market-submit').click();

    // After redirect, market status shows CANCELLED and action forms are gone
    await expect(page.locator('strong', { hasText: /cancelled/i }).first()).toBeVisible();
    await expect(page.getByTestId('cancel-market-panel')).not.toBeVisible();
    await expect(page.getByTestId('settle-market-form')).not.toBeVisible();

    // Player's stake is refunded
    const balanceAfterCancel = await walletBalance(baseURL, player.token);
    expect(balanceAfterCancel).toBe(balanceBefore);
  });

  test('moderator cancel attempt is rejected and market stays open', async ({ page, baseURL }) => {
    const { token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const { payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question: `Mod cancel E2E ${Date.now()}`,
      description: 'Permission check for market cancel',
    });

    await signInUi(page, USERS.moderator.email, USERS.moderator.password);
    await page.goto(`/backoffice/markets/${market.id}`);

    await expect(page.getByTestId('market-title')).toBeVisible();

    // The cancel form is rendered (not view-level permission-gated), fill and submit
    await page.getByTestId('cancel-market-reason').fill(
      'Moderator attempt to cancel — should be blocked by permission check.',
    );
    page.once('dialog', (dialog) => dialog.accept());
    await page.getByTestId('cancel-market-submit').click();

    // Should redirect back with an alert — market still open
    await expect(page.locator('strong', { hasText: /open/i }).first()).toBeVisible();
    await expect(page.locator('.alert, [data-testid="flash-alert"]').first()).toBeVisible();
  });
});
