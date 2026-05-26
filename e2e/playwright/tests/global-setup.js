// global-setup.js — wait for the Rails app to be reachable before tests start.
// In CI/Docker the web service may still be booting when `docker compose run`
// launches the playwright container.

const { request } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://0.0.0.0:3000';
const MAX_RETRIES = 30;
const RETRY_DELAY_MS = 2000;

async function waitForApp() {
  const ctx = await request.newContext({ baseURL: BASE_URL });
  for (let i = 1; i <= MAX_RETRIES; i++) {
    try {
      const res = await ctx.get('/up');
      if (res.ok()) {
        console.log(`[global-setup] App ready after ${i} attempt(s)`);
        await ctx.dispose();
        return;
      }
    } catch (_) {
      // connection refused — not ready yet
    }
    console.log(`[global-setup] Waiting for ${BASE_URL} … attempt ${i}/${MAX_RETRIES}`);
    await new Promise((r) => setTimeout(r, RETRY_DELAY_MS));
  }
  await ctx.dispose();
  throw new Error(`[global-setup] App at ${BASE_URL} did not become ready in time`);
}

module.exports = async function globalSetup() {
  await waitForApp();
};
