const { test, expect, request } = require('@playwright/test');
const { loginApi, createMarketViaAdminApi } = require('./helpers/api');
const { USERS, assertOk } = require('./helpers/common');

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  await page.setViewportSize({ width: 1440, height: 900 });
});

test.describe('Market card desktop badges', () => {
  test('settled cards render one non-overflowing settled badge', async ({ page, baseURL }) => {
    const { context: loginContext, token: adminToken } = await loginApi(baseURL, USERS.admin.email, USERS.admin.password);
    const question = `Desktop settled badge E2E ${Date.now()}`;
    const { context: marketContext, payload: market } = await createMarketViaAdminApi(baseURL, adminToken, {
      question,
      description: 'Settled badge layout regression fixture',
    });
    const settleContext = await request.newContext({ baseURL });

    const settleResp = await settleContext.post(`/admin/markets/${market.id}/settle`, {
      data: { outcome: 'YES', reason: 'badge-layout-e2e' },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    await assertOk(settleResp, 'settle badge fixture market');

    await loginContext.dispose();
    await marketContext.dispose();
    await settleContext.dispose();

    await page.goto('/web/markets');
    await expect(page.getByText(question)).toBeVisible();

    const issues = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('.ds-market')).flatMap((card) => {
        const settledBadges = Array.from(card.querySelectorAll('.ds-badge--settled'));
        if (settledBadges.length === 0) return [];

        const top = card.querySelector('.ds-market__top');
        const cardBox = card.getBoundingClientRect();
        const topBox = top.getBoundingClientRect();
        const rowOverflow = top.scrollWidth > top.clientWidth + 1;
        const badgeProblems = settledBadges.map((badge) => {
          const badgeBox = badge.getBoundingClientRect();
          const styles = getComputedStyle(badge);
          const lineHeight = parseFloat(styles.lineHeight) || parseFloat(styles.fontSize) * 1.45;
          return {
            text: badge.textContent.trim(),
            wraps: badgeBox.height > lineHeight * 1.5,
            overflowsCard: badgeBox.left < cardBox.left || badgeBox.right > cardBox.right + 1,
          };
        });

        return [{
          card: card.textContent.trim().slice(0, 80),
          settledBadgeCount: settledBadges.length,
          topWidth: topBox.width,
          topScrollWidth: top.scrollWidth,
          rowOverflow,
          badgeProblems,
        }];
      });
    });

    expect(issues.length).toBeGreaterThan(0);
    for (const issue of issues) {
      expect(issue.settledBadgeCount, JSON.stringify(issue)).toBe(1);
      expect(issue.rowOverflow, JSON.stringify(issue)).toBe(false);
      for (const badge of issue.badgeProblems) {
        expect(badge.wraps, JSON.stringify(issue)).toBe(false);
        expect(badge.overflowsCard, JSON.stringify(issue)).toBe(false);
      }
    }
  });
});
