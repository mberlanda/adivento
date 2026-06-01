const { test, expect } = require('@playwright/test');
const { USERS, signInUi } = require('./helpers/common');

function parseRgb(value) {
  return value.match(/\d+/g).slice(0, 3).map(Number);
}

function relativeLuminance([red, green, blue]) {
  const [r, g, b] = [red, green, blue].map((channel) => {
    const scaled = channel / 255;
    return scaled <= 0.03928 ? scaled / 12.92 : ((scaled + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrastRatio(foreground, background) {
  const lighter = Math.max(relativeLuminance(foreground), relativeLuminance(background));
  const darker = Math.min(relativeLuminance(foreground), relativeLuminance(background));
  return (lighter + 0.05) / (darker + 0.05);
}

test.beforeEach(async ({ page }) => {
  page.on('console', (msg) => process.stdout.write(`[browser:${msg.type()}] ${msg.text()}\n`));
  page.on('pageerror', (err) => process.stdout.write(`[browser:error] ${err.message}\n`));
  await page.setViewportSize({ width: 1440, height: 900 });
});

test.describe('Backoffice desktop presentation', () => {
  test('sidebar remains visible at desktop and narrow desktop widths', async ({ page }) => {
    await signInUi(page, USERS.admin.email, USERS.admin.password);

    for (const width of [810, 1440]) {
      await page.setViewportSize({ width, height: 900 });
      await page.goto('/backoffice/markets');

      await expect(page.getByTestId('nav-dashboard')).toBeVisible();
      await expect(page.getByTestId('nav-markets')).toBeVisible();

      const metrics = await page.evaluate(() => {
        const sidebar = document.querySelector('.adv-sidebar').getBoundingClientRect();
        const main = document.querySelector('.adv-main').getBoundingClientRect();
        const point = {
          x: sidebar.left + Math.min(sidebar.width / 2, 32),
          y: sidebar.top + Math.min(sidebar.height / 2, 32),
        };
        const topElement = document.elementFromPoint(point.x, point.y);
        return {
          sidebar: {
            width: sidebar.width,
            height: sidebar.height,
            right: sidebar.right,
            bottom: sidebar.bottom,
          },
          topElementIsSidebar: Boolean(topElement?.closest('.adv-sidebar')),
          main: {
            left: main.left,
            top: main.top,
          },
          narrow: matchMedia('(max-width: 900px)').matches,
        };
      });

      expect(metrics.sidebar.width).toBeGreaterThan(0);
      expect(metrics.sidebar.height).toBeGreaterThan(40);
      expect(metrics.topElementIsSidebar).toBe(true);
      if (metrics.narrow) {
        expect(metrics.sidebar.bottom).toBeLessThanOrEqual(metrics.main.top + 1);
      } else {
        expect(metrics.sidebar.right).toBeLessThanOrEqual(metrics.main.left + 1);
      }
    }
  });

  test('market controls fill the desktop form and use design-system styling', async ({ page }) => {
    await signInUi(page, USERS.admin.email, USERS.admin.password);
    await page.goto('/backoffice/markets');

    const form = page.getByTestId('create-market-form');
    const question = page.getByTestId('market-question');
    const description = page.getByTestId('market-description');

    await expect(form).toBeVisible();
    await expect(question).toHaveClass(/adv-input/);
    await expect(description).toHaveClass(/adv-textarea/);

    const widths = await form.evaluate((formEl) => {
      const questionEl = formEl.querySelector('[data-testid="market-question"]');
      const descriptionEl = formEl.querySelector('[data-testid="market-description"]');
      return {
        form: formEl.getBoundingClientRect().width,
        question: questionEl.getBoundingClientRect().width,
        description: descriptionEl.getBoundingClientRect().width,
      };
    });

    expect(widths.form).toBeGreaterThan(900);
    expect(widths.question).toBeGreaterThan(widths.form * 0.8);
    expect(widths.description).toBeGreaterThan(widths.form * 0.8);
  });

  test('theme labels are clickable triggers and primary link buttons stay readable', async ({ page }) => {
    await signInUi(page, USERS.admin.email, USERS.admin.password);
    await page.goto('/backoffice/markets');

    const toggle = page.locator('[data-adv-theme-toggle]').first();
    const label = page.locator('[data-adv-theme-label]').first();

    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');
    await expect(label).toHaveText('Dark');

    await label.click();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
    await expect(toggle).toHaveAttribute('aria-pressed', 'false');
    await expect(label).toHaveText('Light');

    const colors = await page.evaluate(() => {
      const link = document.createElement('a');
      link.href = '#';
      link.className = 'adv-btn adv-btn--sm adv-btn--primary';
      link.textContent = 'Readable primary';
      document.body.appendChild(link);
      const expected = document.createElement('span');
      expected.style.color = 'var(--adv-accent-ink)';
      document.body.appendChild(expected);
      const styles = getComputedStyle(link);
      return {
        color: styles.color,
        backgroundColor: styles.backgroundColor,
        expectedColor: getComputedStyle(expected).color,
      };
    });

    expect(colors.color).toBe(colors.expectedColor);
    expect(contrastRatio(parseRgb(colors.color), parseRgb(colors.backgroundColor))).toBeGreaterThan(4.5);
  });

  test('flush card headings keep table titles inside the card', async ({ page }) => {
    await signInUi(page, USERS.admin.email, USERS.admin.password);
    await page.goto('/web/positions');

    await page.evaluate(() => {
      const card = document.createElement('div');
      card.className = 'adv-card adv-card--flush';
      card.innerHTML = '<div class="adv-card__head"><h3>Table Title</h3></div><table class="adv-table"><tbody><tr><td>Row</td></tr></tbody></table>';
      document.body.appendChild(card);
    });

    const metrics = await page.locator('.adv-card--flush').last().evaluate((card) => {
      const head = card.querySelector('.adv-card__head');
      const heading = head.querySelector('h3');
      const cardBox = card.getBoundingClientRect();
      const headBox = head.getBoundingClientRect();
      const headingBox = heading.getBoundingClientRect();
      const headStyles = getComputedStyle(head);
      const headingStyles = getComputedStyle(heading);
      return {
        headPaddingTop: parseFloat(headStyles.paddingTop),
        headPaddingLeft: parseFloat(headStyles.paddingLeft),
        headingMargin: headingStyles.margin,
        headingInsideTop: headingBox.top - cardBox.top,
        headingInsideLeft: headingBox.left - cardBox.left,
        headHeight: headBox.height,
      };
    });

    expect(metrics.headingMargin).toBe('0px');
    expect(metrics.headPaddingTop).toBeGreaterThanOrEqual(12);
    expect(metrics.headPaddingLeft).toBeGreaterThanOrEqual(12);
    expect(metrics.headingInsideTop).toBeGreaterThanOrEqual(12);
    expect(metrics.headingInsideLeft).toBeGreaterThanOrEqual(12);
    expect(metrics.headHeight).toBeGreaterThan(20);
  });
});
