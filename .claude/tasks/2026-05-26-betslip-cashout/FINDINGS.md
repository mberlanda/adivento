# Findings

## 2026-05-26 — Plan written, review approved with cautions

Plan approved. Before implementing Task 4, verify:
- `BetPlacementService.place!` exact signature and exception class names (`InvalidBet`, `RiskLimitExceeded`)
- `Web::BaseController` auth pattern — does it redirect (HTML) or render JSON 401 for unauthenticated requests?
