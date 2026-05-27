# Findings: E2E Coverage Gap Analysis (2026-05-27)

## CI Status
`gh` CLI is not authenticated — cannot check CI run status from local shell.

## Current Coverage (4 tests in workflow.spec.js)
1. Moderator creates market from template in backoffice UI
2. Player sees settled YES outcome (win path, setup via API)
3. Player sees settled YES outcome after betting NO (loss path, setup via API)
4. Voided scenario — void a bet, check SSE reachable, check UI shows market still open

---

## Gaps Found

### GAP-1: Guest market browsing (index page)
`GET /` and `GET /web/markets` — publicly accessible, no sign-in required.
Views have `data-testid="markets-list"` and `data-testid="market-card-{id}"`.
**Status: IMPLEMENTED** (added in this session as "guest sees market list")

### GAP-2: Backoffice settle-market via UI
Full UI path: sign in as moderator → backoffice → markets → open market detail →
fill settle form → submit. Views have `data-testid="settle-market-form"`,
`data-testid="settle-outcome"`, `data-testid="settle-reason"`, `data-testid="settle-market-submit"`.
**Status: IMPLEMENTED** (added in this session)

### GAP-3: Betslip API round-trip (quote → execute → fetch execution)
`POST /web/betslips/quotes` → `POST /web/betslips/execute` → `GET /web/betslips/executions/:id`.
These are JSON-only endpoints (no HTML views). Can be tested as API-only without UI.
**Status: IMPLEMENTED** (added in this session as pure API test)

### GAP-4: Positions list API
`GET /web/positions` — JSON-only endpoint, no HTML view. Returns array of open bets.
Can be API-tested after placing a bet.
**Status: IMPLEMENTED** (added in this session, bundled with GAP-3)

### GAP-5: Cashout quote + execute API
`POST /web/positions/cashout_quotes` → `POST /web/positions/cashout_execute`.
JSON-only endpoints. Requires an open bet on a non-settled market.
**Status: IMPLEMENTED** (added in this session as pure API test)

### GAP-6: Backoffice market create directly (not via template)
Backoffice UI form with `data-testid="create-market-form"`. Second path to create markets.
**Status: NOT IMPLEMENTED** — low priority since template path is already covered.

### GAP-7: Backoffice open-market via UI
`POST /backoffice/markets/:id/open` — view has `data-testid="open-market-form"`.
The `createMarketViaAdminApi` helper already opens the market, so this UI path is unexercised.
**Status: NOT IMPLEMENTED** — needs a test that creates a draft market then opens it via UI.

### GAP-8: Faucet request approve/reject UI
Backoffice view has dynamic `data-testid="approve-{id}"` and `data-testid="reject-{id}"`.
**Status: NOT IMPLEMENTED** — needs a static `data-testid="faucet-row-{id}"` on the table row
so the row can be located before clicking approve/reject.

### GAP-9: Player positions page (HTML view)
`GET /web/positions` currently returns JSON only. No HTML view exists.
**Status: BLOCKED** — needs an HTML view with `data-testid` attributes added first.

### GAP-10: Player betslip execution confirmation page (HTML view)
`GET /web/betslips/executions/:id` currently returns JSON only. No HTML view exists.
**Status: BLOCKED** — needs an HTML view with `data-testid` attributes added first.

### GAP-11: SSE settlements endpoint
`GET /sse/settlements/:id` — not yet exercised by any test.
**Status: LOW PRIORITY** — same pattern as the SSE market endpoint already tested in test 4.

### GAP-12: Sign-out flow
Nav has `data-testid="nav-signout"`. Quick win but low value; existing tests don't need it.
**Status: NOT IMPLEMENTED**

---

## Summary
- **Implemented this session:** GAP-1 (guest browsing), GAP-2 (settle UI), GAP-3+4+5 (betslip/cashout API)
- **Needs view changes first:** GAP-9 (positions HTML view), GAP-10 (execution confirmation HTML view)
- **Small view additions needed:** GAP-8 (static row testid on faucet table), GAP-7 (open-market UI standalone)
- **Low priority / already covered by other means:** GAP-6, GAP-11, GAP-12
