const { expect } = require('@playwright/test');

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

async function signInUi(page, email, password) {
  await page.goto('/signin');
  await page.getByTestId('signin-email').fill(email);
  await page.getByTestId('signin-password').fill(password);
  await page.getByTestId('signin-submit').click();
  await expect(page.getByTestId('top-nav')).toBeVisible();
}

async function assertOk(response, label) {
  if (!response.ok()) {
    let body = '';
    try { body = await response.text(); } catch (_) {}
    throw new Error(`${label} failed with HTTP ${response.status()}: ${body.slice(0, 500)}`);
  }
}

module.exports = { USERS, signInUi, assertOk };
