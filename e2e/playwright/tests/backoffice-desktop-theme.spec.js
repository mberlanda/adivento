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
  test('market controls fill the desktop form and use design-system styling', async ({ page }) => {
    await signInUi(page, USERS.admin.email, USERS.admin.password);
    await page.goto('/backoffice/markets');

    const form = page.getByTestId('create-market-form');
    const question = page.getByTestId('market-question');
    const description = page.getByTestId('market-description');

    await expect(form).toBeVisible();
    await expect(question).toHaveClass(/ds-input/);
    await expect(description).toHaveClass(/ds-textarea/);

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

    const toggle = page.locator('[data-ds-theme-toggle]').first();
    const label = page.locator('[data-ds-theme-label]').first();

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
      link.className = 'ds-btn ds-btn--sm ds-btn--primary';
      link.textContent = 'Readable primary';
      document.body.appendChild(link);
      const expected = document.createElement('span');
      expected.style.color = 'var(--ds-accent-ink)';
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
});
