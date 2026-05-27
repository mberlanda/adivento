# Findings: e2e-matrix (2026-05-27)

## Key decisions

### common.js extraction
`workflow.spec.js` had inline copies of `loginApi`, `createMarketViaAdminApi`, `assertOk`,
`USERS`, and `signInUi`. These were extracted to `helpers/common.js`. The existing `api.js`
was updated to re-export from `common.js` for backward compatibility (no test imports broke).

New helpers added to `common.js` beyond what `api.js` had:
- `createDraftMarketViaAdminApi` - creates a market without opening it (for open-market UI tests)
- `placeBetApi` - single-bet convenience wrapper
- `settleMarketApi` - settle convenience wrapper
- `attachConsoleForwarder` - browser console to Node stdout forwarder

### permissions.spec.js design choices
- "Access backoffice as player" test only verifies the player is NOT on /backoffice/dashboard.
  The controller can redirect to root or flash-redirect; key invariant is access is denied.
- Moderator CAN call POST /admin/markets/:id/settle via admin API - this is intentional
  (role_permissions grants market.settle to moderator). Test 12 documents this.

### settlement-scenarios.spec.js
- After settlement, GET /web/positions returns OPEN bets only. Test 8 (betslip WIN path)
  asserts the market's bets no longer appear in positions, consistent with controller behaviour.

### error-paths.spec.js
- Test 7 (insufficient balance): betting 999,999 may fail with either "Insufficient wallet
  balance" or "Liability cap exceeded". Test accepts any error.
- Test 14 (non-existent quote): service can return 422 or 404. Both are acceptable.

### TEST_MATRIX.md location
Placed at e2e/playwright/TEST_MATRIX.md (alongside playwright.config.js) so it is
co-located with the test suite it describes.

## Routes that needed special handling
- /sse/markets/:id - streaming; tests use short timeout and ignore connection-timeout errors.
- /web/positions - JSON-only, no HTML view. Pure API test.
- Betslip execution show - UUID-shaped IDs; 404 test uses zero UUID to avoid collision.
