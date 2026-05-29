# PLAN — Tier 0 implementation (one PR each, sequential)

Base: origin/main (PR #41 deep-review + synthesis already merged).

- [x] **PR1 — TD-018** Settle CLOB by net positions, not raw filled orders. ✅ suite green 92.51%.
  - branch `fix/td-018-clob-net-settlement`
  - RED→GREEN: `ClobSettlementHandler` Pass 2 pays `NetPositionService` net per user.
- [x] **PR2 — TD-019** Reserve contracts for open CLOB sell orders. ✅ suite green 92.51%.
  - branch `fix/td-019-clob-sell-reservation` (stacked on PR1)
  - GREEN: `validate_sell_position!` subtracts unfilled open sells. Fill-time concurrency = follow-up.
- [x] **PR3 — TD-013** Lock wallet rows across all mutation paths + concurrency test. ✅ suite green 92.48%.
  - branch `fix/td-013-wallet-locking` (stacked on PR2). All 8 sites locked; concurrency test reliable RED→GREEN.
- [x] **PR4 — UX-036** Web registration form + session-cookie login + "Create account" link. ✅ suite green 92.59%.
  - branch `feat/ux-036-web-registration` (stacked on PR3). `Web::RegistrationsController` + `/register` routes + view.

**All four Tier 0 PRs complete (stacked #42 ← #43 ← #44 ← #45). Each green locally + RuboCop clean.**
