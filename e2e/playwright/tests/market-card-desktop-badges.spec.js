const { test, expect } = require('@playwright/test');

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  await page.setViewportSize({ width: 1440, height: 900 });
});

test.describe('Market card desktop badges', () => {
  test('settled cards render one non-overflowing settled badge', async ({ page }) => {
    await page.goto('/web/markets');

    const issues = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('.adv-market')).flatMap((card) => {
        const settledBadges = Array.from(card.querySelectorAll('.adv-badge--settled'));
        if (settledBadges.length === 0) return [];

        const top = card.querySelector('.adv-market__top');
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
