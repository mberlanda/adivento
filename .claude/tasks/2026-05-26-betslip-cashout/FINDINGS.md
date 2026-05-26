# Findings

## 2026-05-26 — Plan written, review approved with cautions

Plan approved. Before implementing Task 4, verify:
- `BetPlacementService.place!` exact signature and exception class names (`InvalidBet`, `RiskLimitExceeded`)
- `Web::BaseController` auth pattern — does it redirect (HTML) or render JSON 401 for unauthenticated requests?

## 2026-05-26 — Implementation complete

All 7 tasks implemented by subagent. Key adaptations:
- `t.jsonb` → `t.json` in migrations (SQLite test env, matches existing audit_events/ledger_entries pattern)
- `Web::BaseController` uses `authenticate_request!` which renders JSON 401 for non-HTML — used base controller directly
- Cashout test odds 4_000 (not 20_000) due to `odds_minor <= 10_000` validation
- 167 tests, 0 failures, 95.77% line / 76.56% branch coverage after this feature
