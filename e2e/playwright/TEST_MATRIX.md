# Adivento E2E Test Matrix

## How to read this matrix

Each section below describes one spec file's scenarios in framework-agnostic language.
The information here is sufficient to port the suite to Cypress, Jest+Supertest, or any
HTTP-level test framework. See the **Porting guide** at the bottom for the exact auth
conventions, seed users, and API shapes a porter needs to know.

All tests run against a live Rails server seeded with `db/seeds.rb`.
Tests create isolated data (markets, bets) with unique names using `Date.now()` to
avoid collisions. No test depends on data created by another test.

---

## 1. Role / Permission Access Matrix

**Source file:** `tests/permissions.spec.js`

| # | Scenario | Role | Method | Path | Auth type | Expected status | Notes |
|---|----------|------|--------|------|-----------|-----------------|-------|
| 1 | Valid credentials | unauthenticated | POST | /auth/login | none | 200 | Returns JWT token in `token` field |
| 2 | Wrong password | unauthenticated | POST | /auth/login | none | 401 | Error message in `error` field |
| 3 | Me without token | unauthenticated | GET | /auth/me | none | 401 | — |
| 4 | Me as player | player | GET | /auth/me | JWT Bearer | 200 | Response body `role == "player"` |
| 5 | Me as admin | admin | GET | /auth/me | JWT Bearer | 200 | Response body `role == "admin"` |
| 6 | Web market index public | unauthenticated | GET | / | none | 200 | HTML page, no auth required |
| 7 | Web markets list public | unauthenticated | GET | /web/markets | none | 200 | HTML page, no auth required |
| 8 | Create market without token | unauthenticated | POST | /admin/markets | none | 401 | — |
| 9 | Create market as player | player | POST | /admin/markets | JWT Bearer | 403 | Player has no `market.create` permission |
| 10 | Create market as moderator | moderator | POST | /admin/markets | JWT Bearer | 403 | Moderator has no `market.create` permission |
| 11 | Create market as admin | admin | POST | /admin/markets | JWT Bearer | 201 | Admin has `market.create` permission |
| 12 | Settle via admin API as moderator | moderator | POST | /admin/markets/:id/settle | JWT Bearer | 200 | Moderator HAS `market.settle` permission |
| 13 | Settle via admin API as player | player | POST | /admin/markets/:id/settle | JWT Bearer | 403 | Player has no `market.settle` permission |
| 14 | Read risk as player | player | GET | /admin/markets/:id/risk | JWT Bearer | 403 | Player has no `risk.read` permission |
| 15 | Read risk as moderator | moderator | GET | /admin/markets/:id/risk | JWT Bearer | 200 | Moderator has `risk.read` permission |
| 16 | Void bet as player | player | POST | /admin/bets/:id/void | JWT Bearer | 403 | Player has no `bet.void` permission |
| 17 | Void bet as admin | admin | POST | /admin/bets/:id/void | JWT Bearer | 200 | Admin has `bet.void` permission |
| 18 | Place bet without token | unauthenticated | POST | /markets/:id/bets | none | 401 | — |
| 19 | Place bet as player | player | POST | /markets/:id/bets | JWT Bearer | 201 | Player has `bet.place` permission |
| 20 | Betslip quote without token | unauthenticated | POST | /web/betslips/quotes | none | 401 | — |
| 21 | Access backoffice without session | unauthenticated | GET | /backoffice | session cookie | redirect to /signin | HTML redirect, not 401 |
| 22 | Access backoffice as player | player | GET | /backoffice | session cookie | redirect away | Player has no `backoffice.access` permission |
| 23 | Access backoffice as moderator | moderator | GET | /backoffice | session cookie | 200 | Moderator has `backoffice.access` permission |
| 24 | Access permissions page as player | player | GET | /backoffice/permissions | session cookie | redirect to /signin | No `backoffice.access` → early redirect |
| 25 | Access permissions page as moderator | moderator | GET | /backoffice/permissions | session cookie | redirect away | Has `backoffice.access` but not `permission.manage` |
| 26 | Access permissions page as admin | admin | GET | /backoffice/permissions | session cookie | 200 | Admin has both `backoffice.access` and `permission.manage` |

**Permission role mapping (from role_permissions fixtures):**

| Permission | admin | moderator | player |
|------------|-------|-----------|--------|
| backoffice.access | yes | yes | no |
| permission.manage | yes | no | no |
| grant.manage | yes | no | no |
| bet.place | yes | no | yes |
| bet.void | yes | yes | no |
| risk.read | yes | yes | no |
| market.read | yes | yes | no |
| market.create | yes | no | no |
| market.update | yes | no | no |
| market.settle | yes | yes | no |
| market.leg.create | yes | yes | no |
| wallet.faucet.review | yes | yes | no |
| template.manage | yes | yes | no |

---

## 2. Settlement Outcome Matrix

**Source file:** `tests/settlement-scenarios.spec.js`

| # | Scenario | Bet side | Settlement outcome | Expected UI text | Win/Loss |
|---|----------|----------|--------------------|------------------|----------|
| 1 | Win on YES | YES | YES | "Settled outcome: YES" | WIN |
| 2 | Win on NO | NO | NO | "Settled outcome: NO" | WIN |
| 3 | Loss — bet YES, settle NO | YES | NO | "Settled outcome: NO" | LOSS |
| 4 | Loss — bet NO, settle YES | NO | YES | "Settled outcome: YES" | LOSS |
| 5 | No-bet settle | (none) | YES | market status=settled, no error | n/a |
| 6 | Void before settle | YES (voided) | YES | voided bet status=voided, market status=settled | n/a |
| 7 | Double settlement | YES | YES then NO | second attempt → 422 error | n/a |
| 8 | Betslip WIN via API | YES (via betslip) | YES | positions endpoint shows 0 open bets for market | WIN |

**Notes:**
- Tests 1–4 use UI verification: the player signs in and navigates to `/web/markets/:id` to see the trust panel.
- Tests 5–8 are API-only (no browser navigation).
- The trust panel data-testid is `market-trust-panel`. It contains "Settled outcome: YES" or "Settled outcome: NO".
- After settlement, the positions endpoint (`GET /web/positions`) only returns open bets — settled bets are excluded.

---

## 3. Error Path Inventory

**Source file:** `tests/error-paths.spec.js`

| # | Scenario | Setup | Action | Expected HTTP status | Expected error message fragment |
|---|----------|-------|--------|---------------------|--------------------------------|
| 1 | Wrong password | — | POST /auth/login with wrong password | 401 | `error` field truthy |
| 2 | Auth/me without token | — | GET /auth/me with no Authorization header | 401 | — |
| 3 | Create market as player | player JWT | POST /admin/markets | 403 | `error` field truthy |
| 4 | Void bet as player | open bet, player JWT | POST /admin/bets/:id/void | 403 | — |
| 5 | Bet on settled market | settle the market first | POST /markets/:id/bets | 422 | "not open" |
| 6 | Bet with zero stake | open market | POST /markets/:id/bets with stake_minor=0 | 422 | "positive" |
| 7 | Bet with huge stake (insufficient balance) | open market | POST /markets/:id/bets with stake_minor=999999 | 422 | any error |
| 8 | Market not found (/markets) | — | GET /markets/99999 | 404 | — |
| 9 | Market not found (/web/markets) | — | GET /web/markets/99999 | 404 | — |
| 10 | Double void | open bet, first void succeeds | POST /admin/bets/:id/void (second time) | 422 | "not active" |
| 11 | Void without reason | open bet | POST /admin/bets/:id/void with reason="" | 422 | "Reason" |
| 12 | Settle already-settled market | settle first | POST /admin/markets/:id/settle (second time) | 422 | any error |
| 13 | Settle with invalid outcome | open market | POST /admin/markets/:id/settle with outcome="MAYBE" | 422 | "Invalid outcome" |
| 14 | Execute non-existent quote | — | POST /web/betslips/execute with random quote_id | 422 or 404 | — |
| 15 | Get non-existent execution | — | GET /web/betslips/executions/00000000-... | 404 | — |
| 16 | Betslip quote with empty items | — | POST /web/betslips/quotes with items=[] | 422 | — |
| 17 | Cashout voided bet | void the bet first | POST /web/positions/cashout_quotes | 422 | "not open" |
| 18 | Cashout bet on settled market | settle the market first | POST /web/positions/cashout_quotes | 422 | any error |
| 19 | CLOB order on draft market (D3 guard) | create CLOB market, do NOT open | POST /admin/markets/:id/orders | 422 | "Market is not open" |
| 20 | Duplicate web order cancel (D4 guard) | place CLOB order, cancel it | DELETE /web/orders/:id (second time) | 422 | `error` field truthy |

---

## 4. Workflow Scenarios

**Source file:** `tests/workflow.spec.js`

### 4.1 Moderator creates market from template in backoffice UI

**Purpose:** Verify the full template → market creation UI flow.

**Steps:**
1. Sign in as moderator via the `/signin` HTML form.
2. Navigate to backoffice via the `nav-backoffice` link.
3. Click "Templates" in the nav.
4. Locate the first template card (data-testid matching `template-card-*`).
5. Fill in the `question` input and `description` textarea on the create-market-from-template form.
6. Submit the form.
7. Assert the market detail page shows the correct title, and both "YES" and "NO" legs are visible.

### 4.2 Player sees settled YES outcome after betting YES (win path)

**Purpose:** Verify that the player UI reflects a WIN settlement.

**Setup (via API):** Admin creates + opens a market → Player places a YES bet → Admin settles YES.

**Verification (via UI):** Player signs in → navigates to `/web/markets/:id` → the `market-trust-panel` shows "Settled outcome: YES".

### 4.3 Player sees settled YES outcome after betting NO (loss path)

**Purpose:** Verify that the player UI reflects a LOSS settlement.

**Setup (via API):** Admin creates + opens a market → Player places a NO bet → Admin settles YES.

**Verification (via UI):** Same as 4.2. The settled outcome "YES" is shown regardless of which side the player was on.

### 4.4 Voided scenario — SSE reachable, market still open

**Purpose:** Verify that voiding a bet does not close the market, and the SSE endpoint is reachable.

**Setup (via API):** Admin creates + opens a market → Player places a YES bet → Admin voids the bet.

**Verification:**
- GET /sse/markets/:id returns (or the request eventually times out — both are acceptable, the endpoint should not 500).
- Player signs in → navigates to `/web/markets/:id` → `market-trust-panel` shows "Status: open".

### 4.5 Guest sees public market list without signing in

**Purpose:** Verify unauthenticated market browsing works.

**Setup:** Admin creates and opens a market.

**Verification:** Navigate to `/` without signing in → `markets-list` is visible → at least one `market-card-*` element is present → `nav-signin` link is visible (user is not signed in).

### 4.6 Moderator settles market via backoffice UI

**Purpose:** Verify the backoffice settlement form.

**Setup (via API):** Admin creates + opens a market.

**Steps:**
1. Sign in as moderator.
2. Navigate to `/backoffice/markets/:id`.
3. Select "YES" in the `settle-outcome` dropdown.
4. Fill `settle-reason` input.
5. Accept the confirm dialog and click `settle-market-submit`.
6. Assert the redirect destination shows the legs list and a "Settled outcome" paragraph.

### 4.7 Player betslip quote → execute and positions API

**Purpose:** Verify the full betslip round-trip and positions listing.

**Setup (via API):** Admin creates + opens a market.

**Steps (all API, no browser):**
1. Player calls POST /web/betslips/quotes with one item → response has `quote_id` and `total_stake_minor=100`.
2. Player calls POST /web/betslips/execute with the `quote_id` → response has `execution_id` and `status="completed"`.
3. Player calls GET /web/betslips/executions/:execution_id → response has same `execution_id`.
4. Player calls GET /web/positions → response includes a bet for the created market.

### 4.9 Admin cancels market via backoffice UI and player is refunded

**Source file:** `tests/backoffice-cancel-market.spec.js`

**Purpose:** Verify the full market cancellation flow: admin cancels via the backoffice form, the market shows as CANCELLED, and the player's original stake is returned to their wallet.

**Setup (via API):** Admin creates + opens a fixed-odds market → fresh player is funded → player places a bet.

**Steps:**
1. Admin signs in via session cookie.
2. Navigate to `/backoffice/markets/:id`.
3. Verify `cancel-market-panel` is visible; `cancel-market-reason` is present.
4. Fill the reason field and click `cancel-market-submit` (accept confirm dialog).
5. Assert redirect: market status text shows "CANCELLED", `cancel-market-panel` and `settle-market-form` are gone.
6. Assert player wallet balance is back to the pre-bet amount (refund applied).

### 4.10 Moderator cancel attempt is rejected

**Source file:** `tests/backoffice-cancel-market.spec.js`

**Purpose:** Verify that a moderator (no `market.cancel` permission) is redirected with an alert when submitting the cancel form.

**Setup (via API):** Admin creates + opens a market.

**Steps:**
1. Moderator signs in via session cookie.
2. Navigate to `/backoffice/markets/:id`.
3. Fill the cancel reason and submit (accept confirm dialog).
4. Assert redirect: market status still shows "OPEN"; flash alert is visible.

### 4.8 Player cashout quote and execute API

**Purpose:** Verify the cashout round-trip.

**Setup (via API):** Admin creates + opens a market → Player places a direct bet.

**Steps (all API):**
1. Player calls POST /web/positions/cashout_quotes with `bet_id` → response has `bet_id` and `net_payout_minor > 0`.
2. Player calls POST /web/positions/cashout_execute with `bet_id` → response has `status="completed"` and `credited_minor > 0`.

---

## 5. Porting guide

A porter needs the following to replicate this suite in another framework.

### 5.1 Auth mechanism

**Admin API (JSON):**
- POST /auth/login with `{ email, password }` → returns `{ token, user, actions }`.
- Include `Authorization: Bearer <token>` header on all protected requests.
- Applies to: `/admin/*`, `/auth/me`, `/markets/:id/bets`, `/web/betslips/*`, `/web/positions/*`, `/sse/*`.

**Backoffice HTML surface:**
- POST /signin with form params `email=...&password=...` sets a session cookie (`_session_id`).
- Subsequent requests to `/backoffice/*` must carry the cookie (browsers do this automatically; programmatic clients must persist the cookie jar).
- Redirects to `/signin` on authentication failure.

**SSE endpoint:**
- GET /sse/markets/:id — no auth required. Returns `text/event-stream` with a single snapshot event and then holds the connection open. In test environments: connect with a short timeout (3 s) and treat both 200 and connection-timeout as "reachable".

### 5.2 Seed data

The test suite relies on three seed users created by `db/seeds.rb`. Their credentials are fixed:

| Email | Role | Password | Initial wallet (minor units) |
|-------|------|----------|------------------------------|
| admin@adivento.local | admin | password123 | 0 |
| moderator@adivento.local | moderator | password123 | 0 |
| player@adivento.local | player | password123 | 10,000 |

Wallet minor units: 100 minor = 1 ADIV. The player starts with 10,000 minor = 100 ADIV.

Seed also creates permissions, role_permissions, and market templates. The seed is idempotent — running it multiple times resets wallets to the amounts above.

### 5.3 API conventions

**Request body:** JSON. Set `Content-Type: application/json` on all write requests.

**Market creation:**
```
POST /admin/markets
{ "question": "...", "description": "..." }
→ 201 { "id": <uuid_or_int>, "status": "draft" }
```
Markets are created in `draft` status with two legs (YES, NO) seeded automatically.

**Opening a market:**
```
PUT /admin/markets/:id
{ "status": "open" }
→ 200 { "id": ..., "status": "open" }
```
A market must be open to accept bets.

**Fetching market with leg IDs (needed for placing bets):**
```
GET /admin/markets/:id
→ 200 { "id": ..., "status": "open", "legs": [{ "id": ..., "label": "YES", ... }, { "id": ..., "label": "NO", ... }] }
```

**Placing a bet:**
```
POST /markets/:id/bets
{ "market_leg_id": <leg_id>, "stake_minor": 100 }
→ 201 { "id": ..., "status": "open", ... }
```

**Settling a market:**
```
POST /admin/markets/:id/settle
{ "outcome": "YES", "reason": "..." }
→ 200 { "id": ..., "status": "settled", "settled_outcome": "YES" }
```
Only valid outcome labels are `"YES"` and `"NO"` (the two seeded leg labels). An invalid label returns 422.

**Betslip quote:**
```
POST /web/betslips/quotes
{ "items": [{ "market_leg_id": ..., "stake_minor": 100 }], "idempotency_key": "<unique string>" }
→ 200 { "quote_id": "...", "total_stake_minor": 100, ... }
```

**Betslip execute:**
```
POST /web/betslips/execute
{ "quote_id": "..." }
→ 200 { "execution_id": "...", "status": "completed", ... }
```

**Positions list (open bets only):**
```
GET /web/positions
→ 200 { "positions": [{ "id": ..., "market_id": ..., ... }] }
```

**Cashout quote:**
```
POST /web/positions/cashout_quotes
{ "bet_id": ... }
→ 200 { "bet_id": ..., "net_payout_minor": ..., "expires_at": "..." }
```

**Cashout execute:**
```
POST /web/positions/cashout_execute
{ "bet_id": ... }
→ 200 { "status": "completed", "credited_minor": ... }
```

### 5.4 data-testid attributes used in UI tests

The following `data-testid` values are used in browser tests. Any framework that can
locate elements by test ID can run these scenarios.

| data-testid | Element | Used in |
|-------------|---------|---------|
| `signin-email` | Email input on /signin | sign-in helper |
| `signin-password` | Password input on /signin | sign-in helper |
| `signin-submit` | Submit button on /signin | sign-in helper |
| `top-nav` | Top navigation bar (authenticated) | sign-in confirmation |
| `nav-backoffice` | "Backoffice" link in nav | workflow 4.1 |
| `nav-signin` | "Sign in" link in nav (unauthenticated) | workflow 4.5 |
| `template-card-*` | Template card on backoffice templates list | workflow 4.1 |
| `create-market-from-template-form-*` | Form on template card | workflow 4.1 |
| `market-title` | Market title heading | workflows 4.1, 4.6 |
| `market-legs-list` | List of market legs on market show | workflows 4.1, 4.6 |
| `market-trust-panel` | Trust panel on web market show page | workflows 4.2, 4.3, 4.4 |
| `markets-list` | Container on web markets index | workflow 4.5 |
| `market-card-*` | Individual market card | workflow 4.5 |
| `settle-outcome` | Outcome select on backoffice market show | workflow 4.6 |
| `settle-reason` | Reason input on backoffice market show | workflow 4.6 |
| `settle-market-submit` | Submit button on settle form | workflow 4.6 |
| `cancel-market-panel` | Cancel form container on backoffice market show (open/closed only) | workflow 4.9, 4.10 |
| `cancel-market-reason` | Reason input on cancel form | workflow 4.9, 4.10 |
| `cancel-market-submit` | Submit button on cancel form | workflow 4.9, 4.10 |
