# Dockerise E2E Suite — Implementation Plan

**Goal:** Add a `docker-compose.e2e.yml` override file using the official `mcr.microsoft.com/playwright:v1.52.0-noble` image so that `docker compose -f docker-compose.yml -f docker-compose.e2e.yml run --rm playwright` runs the full Playwright suite reproducibly against the `web` service. No test logic changes. No changes to `docker-compose.yml`.

**Architecture:** A separate `docker-compose.e2e.yml` override file (already created at `docker-compose.e2e.yml`) overrides the `web` service environment to `RAILS_ENV=production` and adds the `playwright` service. The `playwright` service mounts `./e2e/playwright` as a bind volume (so `node_modules` and report artefacts are shared with the host), sets `BASE_URL=http://web:3000` and `DOCKER=1`, and waits for the `web` healthcheck before starting. `RAILS_SERVE_STATIC_FILES=true` lets Rails serve assets without a reverse proxy. `SECRET_KEY_BASE` is set to a dummy value (E2E only — not a real secret). The `playwright.config.js` already reads `BASE_URL` and `DOCKER` from the environment — no test file changes needed.

---

## File Map

**Created (already done):**
- `docker-compose.e2e.yml` — Playwright service override

**Modify:**
- `e2e/playwright/playwright.config.js` — fix default `baseURL` from `http://0.0.0.0:3000` to `http://localhost:3000`

**No changes to:** `docker-compose.yml`, any file under `e2e/playwright/tests/`

---

## Task 1: Fix `playwright.config.js` default baseURL

**File:** `e2e/playwright/playwright.config.js`

- [ ] **Step 1.1:** On line 4, change:
  ```js
  const baseURL = process.env.BASE_URL || 'http://0.0.0.0:3000';
  ```
  To:
  ```js
  const baseURL = process.env.BASE_URL || 'http://localhost:3000';
  ```
  Rationale: `0.0.0.0` is a bind address, not a routable hostname. `localhost:3000` works locally and is overridden to `http://web:3000` inside Docker via the `BASE_URL` env var.

- [ ] **Step 1.2:** Verify no other reference:
  ```bash
  grep -rn "0\.0\.0\.0:3000" e2e/
  ```
  Expected: no output.

- [ ] **Step 1.3:** Commit:
  ```bash
  git add e2e/playwright/playwright.config.js
  git commit -m "fix: default playwright baseURL to localhost:3000 (not bind address)"
  ```

---

## Task 2: Commit `docker-compose.e2e.yml`

The file is already created. Review it, then commit.

- [ ] **Step 2.1:** Read `docker-compose.e2e.yml` and confirm it contains:
  - `playwright` service with image `mcr.microsoft.com/playwright:v1.52.0-noble`
  - `volumes: - ./e2e/playwright:/e2e`
  - `environment: BASE_URL: http://web:3000` and `DOCKER: "1"`
  - `depends_on: web: condition: service_healthy`
  - `command: npx playwright test --reporter=list`

- [ ] **Step 2.2:** Validate compose files parse cleanly:
  ```bash
  docker compose -f docker-compose.yml -f docker-compose.e2e.yml config --quiet
  ```
  Expected: exits 0, no output.

- [ ] **Step 2.3:** Commit:
  ```bash
  git add docker-compose.e2e.yml
  git commit -m "feat: add docker-compose.e2e.yml for Playwright E2E in Docker"
  ```

---

## Task 3: Verification run

- [ ] **Step 3.1:** Start main stack:
  ```bash
  docker compose up -d --build
  ```
  Wait for `web` to become healthy:
  ```bash
  docker compose ps
  ```
  Expected: `adivento-web-1` shows `Up (healthy)`.

- [ ] **Step 3.2:** Run the E2E service:
  ```bash
  docker compose -f docker-compose.yml -f docker-compose.e2e.yml run --rm playwright
  ```
  Expected output pattern:
  ```
  Running N tests using 1 worker

    ✓  1 [chromium] › ...
    ...
    ✓  N [chromium] › multi-player-settlement.spec.js:... (Xs)

    N passed (Xm Xs)
  ```
  The final summary line must start with a count and `passed`. Any `failed` count → stop and investigate.

- [ ] **Step 3.3:** Confirm report written to host:
  ```bash
  ls e2e/playwright/playwright-report/
  ```
  Expected: `index.html`, `results.json` present.

- [ ] **Step 3.4:** Tear down:
  ```bash
  docker compose down -v
  ```

---

## Task 4: Update docs

- [ ] Prepend entry to `docs/WORK_LOG.md`:
  ```
  ## 2026-05-28 — Dockerise E2E suite

  Added `docker-compose.e2e.yml` with `playwright` service (mcr.microsoft.com/playwright:v1.52.0-noble).
  Mounts `./e2e/playwright`, sets BASE_URL=http://web:3000 and DOCKER=1.
  Service waits for `web` healthcheck before starting. Run with:
    docker compose -f docker-compose.yml -f docker-compose.e2e.yml run --rm playwright
  Fixed playwright.config.js default baseURL from 0.0.0.0:3000 to localhost:3000.
  Key files: docker-compose.e2e.yml, e2e/playwright/playwright.config.js
  ```

- [ ] Update `docs/INDEX.md` ⏳ Next: mark "Dockerise E2E suite" as done.

- [ ] Commit:
  ```bash
  git add docs/WORK_LOG.md docs/INDEX.md
  git commit -m "docs: update INDEX and WORK_LOG after dockerise-e2e-suite"
  ```

---

## Guardrails

1. **DO NOT** modify `docker-compose.yml` — changes go only into `docker-compose.e2e.yml`.
2. **DO NOT** change any file under `e2e/playwright/tests/` — no test logic changes.
3. **DO NOT** add `npm install` or `npx playwright install` to the container `command` — the bind-mounted volume provides `node_modules` from the host (must be installed locally first: `cd e2e/playwright && npm install`).
4. **DO NOT** use `docker-compose.e2e.yml` standalone (`docker compose -f docker-compose.e2e.yml up`) — it is an overlay; always combine with the base file.
5. **DO NOT** pin the `playwright` image to a version older than `v1.52.0-noble` — this must match the version in `e2e/playwright/package.json`.
6. **DO NOT** change `DOCKER: "1"` to any other value — `playwright.config.js` uses `!!process.env.DOCKER` to restrict to Chromium only and enable CI-style retries.
7. **DO NOT** remove `depends_on: web: condition: service_healthy` — without it Playwright starts before Rails is ready and all tests fail with connection errors.
8. **DO NOT** mount the entire repo root into the container — only `./e2e/playwright:/e2e` to keep the container image lean.
