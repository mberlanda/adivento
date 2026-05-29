# PLAN — Tier 0 implementation (one PR each, sequential)

Base: origin/main (PR #41 deep-review + synthesis already merged).

- [x] **PR1 — TD-018** Settle CLOB by net positions, not raw filled orders. ✅ suite green 92.51%.
  - branch `fix/td-018-clob-net-settlement`
  - RED→GREEN: `ClobSettlementHandler` Pass 2 pays `NetPositionService` net per user.
- [ ] **PR2 — TD-019** Reserve contracts for open CLOB sell orders (no oversell).
  - RED: order_matching test — holder of 10 cannot place two open 10-contract sells.
  - GREEN: account unfilled open sells in available-to-sell; re-validate under lock at fill.
- [ ] **PR3 — TD-013** Lock wallet rows across all mutation paths + concurrency test.
  - Services: BetPlacement, BetVoid, CashoutExecution, settle_fixed_odds!, ClobSettlementHandler pass1,
    WalletGrantService, ParimutuelSettlementService#refund_all!, Admin::OrdersController#destroy.
  - RED: concurrency test (two threads) cannot drive wallet negative / double-credit.
- [ ] **PR4 — UX-036** Web registration form + session-cookie login + "Create account" link.
  - RED: request test GET /register renders form; POST creates user + session.

Next step: PR1 GREEN (test written, verify RED first).
