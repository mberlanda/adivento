# Tech Debt & Backlog

This file tracks known gaps, deferred implementation decisions, and open design questions. It is the single source of truth for "things we know we need but haven't built yet."

Update this file when a gap is closed or a decision is made.

---

## Upcoming features (prioritised)

| ID | Feature | Status | Depends on |
|----|---------|--------|-----------|
| F-009 | Automated market close (`CloseExpiredMarketsJob` + `closed` status) | ✅ done (PR #28) | — |
| F-010 | Market close UX (player-facing "Betting closed" state on market page) | ✅ done (shipped in F-009/PR #28) | F-009 |
| F-011 | LMSR individual settlement payouts | ✅ done (PR #35, DD-002) | — |
| F-012 | Player positions HTML view (currently JSON-only) | ✅ done (PR #29) | — |
| F-013 | Betslip execution confirmation HTML view (currently JSON-only) | ✅ done (PR #29) | — |
| F-014 | Market edit form in backoffice | ✅ done (PR #31) | — |
| F-015 | Cross-mechanism leaderboard P&L aggregation | ✅ done (PR #29) | — |
| F-016 | LMSR subsidy exhaustion guard | ✅ done (PR #30) | — |
| F-017 | Market list pagination (web + backoffice) | ✅ done (PR #29) | — |
| F-018 | Switch test DB to PostgreSQL | ✅ done (PR #33, DD-004) | — |

---

## Active tech debt (implementation gaps)

### TD-001 · LMSR individual settlement payouts

**Status:** ✅ Done (PR #35, DD-002). `lmsr_positions` table tracks per-player YES/NO contract holdings; `LmsrSettlementHandler` pays out 100 minor/winning contract.

---

### TD-002 · Parimutuel per-bettor history model

**Status:** Deferred from v1.
**Problem:** Parimutuel stakes are recorded in `LedgerEntry` (entry_type `PARIMUTUEL_STAKE`, metadata contains market_id and side) but there is no dedicated `ParimutuelBet` model. Querying bet history or reconstructing pool positions requires scanning ledger entries.
**Impact:** Low for now (settlement works via pool totals, not per-bettor records). Becomes a problem if you need to show individual bet history, void individual parimutuel bets, or support partial pools.

---

### TD-003 · LMSR subsidy exhaustion guard

**Status:** ✅ Done (PR #30). `lmsr_realized_loss_minor` column on markets; guard in `LmsrTradeService` rejects trades that would push realized loss past `liquidity_subsidy_minor`.

---

### TD-004 · CLOB cashout (sell contracts before settlement)

**Status:** ✅ Done (PR #36, DD-006). Option A (sell limit orders) + Option B (operator buyback at mid-price). `direction` column on orders; `NetPositionService`; `ClobCashoutService`; `OperatorBuybackService`; web + backoffice endpoints.

---

### TD-005 · Cross-mechanism leaderboard P&L

**Status:** ✅ Done (PR #29). Leaderboard now aggregates all ledger entry types across all 4 mechanisms.

---

### TD-006 · Browser matrix in E2E (Firefox / WebKit)

**Status:** Deferred.
**Problem:** The E2E spec originally called for Chromium + Firefox + WebKit. CI only runs Chromium.
**Options:**
- A: Add Firefox and WebKit to `playwright.config.js` projects array (slow, ~3× CI time).
- B: Run Firefox/WebKit on a nightly schedule, Chromium on every PR.
- C: Keep Chromium-only (fast CI, coverage gap on Safari/Firefox rendering).
**Trade-offs:** A/B add confidence on cross-browser rendering; C is pragmatic for a POC.

---

### TD-007 · Backoffice open-market UI test (E2E GAP-7)

**Status:** ✅ Done (PR #31). `e2e/playwright/tests/backoffice-open-market.spec.js` added.
**Problem:** The backoffice open-market form (`POST /backoffice/markets/:id/open`) is not covered by any E2E test. The test that creates a market via admin API opens it immediately, so the UI open path is never exercised.
**Effort:** Low. Needs a test that creates a draft market via admin API (without opening), then opens it via the backoffice UI.

---

### TD-008 · Player positions and execution HTML views (E2E GAP-9, GAP-10)

**Status:** ✅ Done (PR #29). `GET /web/positions` and `GET /web/betslips/executions/:id` now render HTML alongside JSON responses.

---

### TD-009 · SQLite ILIKE + jsonb test fidelity gap

**Status:** ✅ Resolved (PR #33, DD-004). Test DB switched to PostgreSQL; ILIKE and jsonb work correctly in all tests.

---

### TD-010 · Binary line trigger not exercised in SQLite tests

**Status:** ✅ Resolved (PR #33, DD-004). PostgreSQL test DB exercises the `enforce_max_two_market_legs` trigger; trigger condition also fixed (`>= 2`).

---

### TD-011 · Market edit form (backoffice)

**Status:** ✅ Done (PR #31). DD-007 resolved as Option B. Edit Details panel in `show.html.erb` supports `description`, `close_at`, `resolution_criteria`, `resolution_source`, `category`, `tags`. Financial fields locked once open.
**Problem:** Operators cannot update a market's `description`, `close_at`, `resolution_criteria`, or `resolution_source` through the backoffice UI after creation. The admin JSON API (`PATCH /admin/markets/:id`) supports updates, but backoffice has no edit form.
**Effort:** Low. Standard Rails edit/update pattern identical to the existing create form.
**Impact:** Operators must use the API directly for any correction after creation.

---

### TD-012 · Market list pagination

**Status:** ✅ Done (PR #29, F-017). Web 12/page, backoffice 20/page with Previous/Next controls.

---

### TD-013 · BetPlacementService missing wallet lock (race condition)

**Status:** Resolved 2026-05-29 (scope expanded). Wallet rows are now locked (`lock!`) inside the transaction with an authoritative balance re-check in `BetPlacementService`, and `lock!` added to every other unlocked wallet mutation: `BetVoidService`, `CashoutExecutionService`, `SettlementService#settle_fixed_odds!`, `Settlement::ClobSettlementHandler` Pass 1, `WalletGrantService#approve!`, and `Parimutuel::ParimutuelSettlementService#refund_all!`. `Admin::OrdersController#destroy` now re-loads and locks the order row inside the transaction (partial TD-021). Concurrency regression test: `test/services/bet_placement_concurrency_test.rb` (two concurrent placements on a one-bet balance create exactly one bet).
**Problem:** `BetPlacementService` reads `user.wallet` without `lock!` before the balance check, then debits inside a transaction. Two concurrent requests can both pass the balance check on the stale value, resulting in a negative balance. The model validates `available_minor >= 0` but uses the pre-lock stale value, so the guard does not prevent the race. Same issue exists in `BetVoidService`, `CashoutExecutionService`, and `SettlementService#settle_fixed_odds!`.
**Fix:** Replace `user.wallet` with `user.wallet.lock!` inside the transaction in all four services. Pattern is already correct in `LmsrTradeService`, `ParimutuelPoolService`, and the CLOB handlers.
**Impact:** High — double-spend possible under concurrent load.

---

### TD-014 · LMSR positions not shown on positions page

**Status:** Open. Identified 2026-05-29.
**Problem:** `lmsr_positions` table is populated on every LMSR trade and is the source of truth for settlement payouts, but `PositionsController#index` never queries it. Players who trade LMSR see an empty positions page.
**Fix:** Add `@lmsr_positions` query to `PositionsController#index` (analogous to `@clob_positions`). Add section to positions view.
**Impact:** High — live player state is invisible on the UI.

---

### TD-015 · Leaderboard P&L missing CLOB_SELL_CREDIT, LMSR_FEE, CLOB_FEE

**Status:** Open. Identified 2026-05-29.
**Problem:** `RETURN_TYPES` in `LeaderboardController` omits `CLOB_SELL_CREDIT` (proceeds from selling CLOB contracts) and `PARIMUTUEL_REFUND`. `STAKE_TYPES` omits `LMSR_FEE` and `CLOB_FEE`. Players who use LMSR or CLOB sell paths have distorted P&L on the leaderboard.
**Fix:** Add missing entry types to the respective constant arrays.
**Impact:** Medium — leaderboard ranking is wrong for CLOB sellers and LMSR/CLOB players.

---

### TD-016 · Admin API market_params missing category and tags

**Status:** Open. Identified 2026-05-29.
**Problem:** `Admin::MarketsController#market_params` does not permit `:category` or `:tags`. Markets created via the admin API always get category `'other'` (DB default). E2E tests create markets via the admin API, so all E2E fixture markets are `other` — the category filter bar is never exercised in E2E.
**Fix:** Add `:category` and `tags: []` to the `params.permit` call in `Admin::MarketsController`.
**Impact:** Medium — API creates miscategorised markets; E2E category test coverage is vacuous.

---

### TD-017 · Market cancellation (no service, no controller action)

**Status:** Open — **plan written** (D2, 2026-05-30): spec `docs/specs/2026-05-30-market-cancellation.md` + plan `docs/superpowers/plans/2026-05-30-market-cancellation.md`. Full cross-mechanism atomic cancellation/refund service with backoffice cancel action and `market.cancel` permission. Ready to implement.
**Problem:** `Market` has a `cancelled: 3` enum value but no `MarketCancellationService` exists. Operators cannot void a market and refund all bets/positions. There is no recovery path for bad questions or externally cancelled events.
**Fix:** Implement `MarketCancellationService` (atomically refund fixed_odds bets, release CLOB reservations, refund LMSR net costs from audit events, refund parimutuel stakes, mark market `cancelled`). Add `POST /backoffice/markets/:id/cancel` route and action.
**Impact:** Medium — no hard bug now, but no operational safety net.

---

### TD-018 · CLOB settlement pays sold positions as winners

**Status:** Resolved 2026-05-29. `ClobSettlementHandler` Pass 2 now pays each holder's net long position (`Clob::NetPositionService`) instead of raw filled orders; regression test in `test/services/settlement/clob_settlement_handler_test.rb`.
**Problem:** `Settlement::ClobSettlementHandler` pays every order on the winning side with `filled_quantity > 0`, regardless of `direction`. Filled sell orders represent contracts the user exited, but they still receive `SETTLEMENT_WIN` credits. The buyer who filled that sell order also receives settlement, causing double payout on the same contracts.
**Fix:** Settle CLOB using net positions (`Clob::NetPositionService`) or restrict payout to net long contracts after subtracting filled sell orders. Add a regression test where a player buys YES, sells the full YES position, YES wins, and the seller receives no settlement payout for the sold contracts.
**Impact:** High — CLOB markets can overpay at settlement after sell/cashout activity.

---

### TD-019 · CLOB sell orders do not reserve contracts

**Status:** Resolved 2026-05-29. `validate_sell_position!` now reserves contracts already committed to the user's other resting (open/partial) sell orders on the same side: available-to-sell = net − open-unfilled-sells. Regression test in `test/services/clob/order_matching_service_test.rb`. **Remaining:** concurrent fill-time revalidation under a per-position lock is still a follow-up (overlaps TD-013 locking).
**Problem:** `OrderMatchingService#validate_sell_position!` checks current net position only when a sell order is created. Unfilled sell orders do not reserve or otherwise reduce available contracts. A user with 10 contracts can place multiple open sell orders for 10 contracts each; if they later fill, the user can sell more contracts than they own.
**Fix:** Track reserved sell quantity in net-position checks (`bought - filled_sold - open_sell_unfilled`) or add a contract reservation model/column. Validate again under lock when matching sell orders. Add sequence tests for duplicate sell listings.
**Impact:** High — CLOB positions can become negative and settlement/accounting becomes unreliable.

---

### TD-020 · Admin CLOB order API skips market trading-state guards

**Status:** Open — **plan written** (D3, 2026-05-30): `docs/superpowers/plans/2026-05-30-d3-clob-trading-state-guards.md`.
**Problem:** `Web::OrdersController#create` rejects non-open markets and markets past `close_at`, but `Admin::OrdersController#create` only checks `market.clob?`. Admin API callers can place CLOB orders on draft, closed, or settled markets.
**Fix:** Apply the same `open?` and `close_at` checks in `Admin::OrdersController#create`, or move the trading-state guard into `Clob::OrderMatchingService` so all callers share it. Add admin integration tests for draft, closed, and expired markets.
**Impact:** Medium — privileged/API flows can mutate markets outside the intended lifecycle.

---

### TD-021 · CLOB order cancellation is not consistently locked

**Status:** Open — **plan written** (D4, 2026-05-30): `docs/superpowers/plans/2026-05-30-d4-clob-order-cancellation-service.md`. (Admin `destroy` already locks order+wallet as a partial TD-013 follow-up; D4 extracts the shared service.)
**Problem:** `Web::OrdersController#destroy` calls `Order.lock.find` before entering the transaction, and `Admin::OrdersController#destroy` does not lock the order or wallet. Two concurrent cancellations can both compute the same `reserved_minor` and release funds twice unless the order row is locked for the whole state transition.
**Fix:** Move `Order.lock.find` and wallet `lock!` inside the transaction in both controllers. Add a service object for order cancellation so web/admin/settlement release logic uses one implementation.
**Impact:** Medium — duplicate cancellation can corrupt wallet reserved/available balances under concurrent requests.

---

### TD-022 · RuboCop gate has one autocorrectable offense

**Status:** ✅ Done 2026-05-30. `lib/tasks/db_structure.rake` now uses `Rails.root.join('db/structure.sql')`; RuboCop reports no offenses.
**Problem:** `bundle exec rubocop --cache false --format simple` reports one `Rails/FilePath` offense in `lib/tasks/db_structure.rake` for the `Rails.root.join('db', 'structure.sql')` path style.
**Fix:** Apply the autocorrect or change to `Rails.root.join('db/structure.sql')`, then rerun RuboCop.
**Impact:** Low — validation fails on style even though the test suite is green.

---

### TD-034 · Settlement & sell-order idempotency under concurrent operations

**Status:** Open. Raised by Copilot review on PRs #43/#44 (2026-05-30).
**Problem:** Several paths are safe single-threaded but not under truly concurrent calls:
- `Clob::OrderMatchingService#validate_sell_position!` is non-atomic — two concurrent sell placements for the same user/side can both pass the available-to-sell check (TD-019 fixed the deterministic two-open-orders case; the concurrent race remains).
- `Parimutuel::ParimutuelSettlementService` does not lock the market until after `refund_all!`, so two concurrent settlements on a zero-winning-pool market could double-refund.
- `Settlement::ClobSettlementHandler` Pass 1 cancels orders without a per-order row lock, so concurrent settlements of the same market could double-release reservations.
**Fix:** Lock the market row at the start of every settlement handler (matching `LmsrSettlementHandler`) so settlement is serialized per market, and re-validate sell position under a row lock at fill time. Best done as one focused "settlement idempotency" PR alongside the TD-028 settlement-handler unification.
**Impact:** Medium — requires genuine concurrency (two operators / two requests racing on the same market) to trigger; SettlementService already blocks sequential double-settle via the status guard.

---

## Product/UX implementation gap review — 2026-05-29

The backend tasks above are the highest-confidence autonomous implementation work. The remaining product and UX gaps are larger slices and should be scheduled after the data-integrity fixes unless a demo need pulls them forward.

### Planned UX slices

| Slice | Gaps covered | Plan | Status |
|-------|-------------|------|--------|
| PR A: Market browse + detail | UX-001–UX-012 | `docs/superpowers/plans/2026-05-29-ux-market-browse-detail.md` | Planned |
| PR B: Leaderboard + profile + auth + positions | UX-013–UX-024 | `docs/superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md` | Planned |
| PR C: Settlement explainer page | UX-025–UX-026 | `docs/superpowers/plans/2026-05-29-ux-settlement-explainer-page.md` | Planned |
| PR D: Backoffice dashboard + settle + faucet | UX-027–UX-032 | `docs/superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md` | Planned |

### Larger product gaps still needing specs/plans

| Feature | Current gap | Suggested next artifact |
|---------|-------------|-------------------------|
| F-004 Price history and chart | `PriceSnapshot` exists, but no web/admin price-history endpoints or chart UI are exposed. | New spec/plan for endpoint + chart delivery |
| F-008 Watchlist and notifications | No watchlist, notification feed, or notification storage exists. | ADR/spec for notification storage model |
| F-010 Resolution outcome transparency | Settlement records outcome, but no mandatory resolution note, settled timestamp display, or source citation workflow exists. | Spec + migration plan |
| F-011 Platform activity feed | Audit events exist, but there is no player-facing feed visibility model or cached homepage feed. | Spec for event selection and privacy rules |
| F-012 Responsible gambling controls | No daily stake limit or cooling-off model exists. | ADR/spec before implementation |

---

## Open design decisions

For each: short options with trade-offs. These are inputs for the next product/architecture discussion — no code should be written until one option is chosen.

---

### DD-001 · F-009 Automated market close

**Status:** ✅ Done (PR #28, F-009). Option A implemented: `CloseExpiredMarketsJob` + `closed: 4` status.

**Question:** What happens when a market's `close_at` datetime passes?
**Context:** `close_at` field exists on markets (added in F-003). No automated action fires when it passes.

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: `CloseExpiredMarketsJob` (cron) | Background job runs every minute, finds markets where `close_at < now` and `status = open`, transitions to a new `closed` status. Betting blocked on closed markets. | + Simple, auditable. − New enum value needed. Requires operator to then settle manually. |
| B: Gate at bet placement | `BetPlacementService` checks `close_at` at bet time. No new status; market stays `open` until operator settles. | + No job needed. − No signal to players that betting is over. Market appears open. |
| C: Auto-settle on close_at | Job fires and immediately settles the market (requires a resolution source). | + Fully automated. − Needs trusted oracle / resolution source integration. Not viable without external data. |

**Recommendation:** Option A. A `closed` status is semantically correct and clearly communicates state to players. Operator retains control over settlement. Plan already written: `docs/superpowers/plans/2026-05-28-f009-automated-market-close.md`.

---

### DD-002 · LMSR v2 settlement payout model

**Status:** ✅ Done (PR #35). Option A + B implemented: `lmsr_positions` table + `positions_from_ledger` audit path.

**Question:** How should individual LMSR positions be tracked for payout at settlement?

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Position model (new table) | Add `lmsr_positions` table: `(user_id, market_id, side, contracts)`. Update on every trade. Settle by iterating positions. | + Clean model, easy to query. − Extra write on every trade; migration needed. |
| B: Replay ledger entries | Derive positions from `ledger_entries` with `entry_type = LMSR_TRADE`. Settlement replays history. | + No new table. − Slow on large markets; logic in settlement handler. |
| C: `lmsr_contracts_minor` on bets | Re-use the `bets` table with a `contracts` field for LMSR. | + Leverages existing settlement machinery. − `bets` model semantics don't map cleanly to AMM trades. |

**Recommendation:** Option A. Cleanest model. LMSR trades are frequent enough that a dedicated position table is justified. B is acceptable only for low-volume markets.

---

### DD-003 · Parimutuel v2 — migrate to ParimutuelBet model

**Question:** Should parimutuel bets get a dedicated model or stay on LedgerEntry?

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Add `ParimutuelBet` model | Table with `(user_id, market_id, side, stake_minor, status)`. Settlement iterates this table. | + Queryable history, voidable, consistent with other mechanisms. − Migration + backfill. |
| B: Keep LedgerEntry-only | Current approach. Pool totals derived by summing `PARIMUTUEL_STAKE` entries. | + No change needed. − Hard to void individual bets; awkward to display bet history. |

**Recommendation:** Option A when parimutuel markets gain traction. Not urgent for POC.

---

### DD-004 · Test DB adapter (SQLite vs PostgreSQL)

**Status:** ✅ Done (PR #33). Option B implemented: all tests run against PostgreSQL.

**Question:** Should the test suite use SQLite (current) or PostgreSQL?

**Context:** Tests run against SQLite3 (`storage/test.sqlite3`). Production uses PostgreSQL. Schema includes PostgreSQL-specific triggers (binary line invariant), `jsonb` columns, and `ILIKE`. SQLite silently ignores FK constraints and doesn't support these.

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Keep SQLite for tests | Current state. `validate.sh` uses `db:reset` to avoid FK issues. | + Fast, no Docker needed for unit tests. − PostgreSQL-specific features (triggers, jsonb ops, ILIKE) not tested. |
| B: Switch tests to PostgreSQL | All tests run against Docker PostgreSQL. | + Matches production. Catches trigger/constraint issues. − Docker required for all test runs; slower startup. |
| C: Dual adapter (SQLite for unit, PG for integration) | Minitest categories: unit (SQLite), integration (PG). | + Speed for unit tests. − Complex setup; easy to mis-categorize tests. |

**Recommendation:** Option B for correctness (the binary line trigger already tests against PG in the current integration test — but only because the test suite happens to target PG in CI). Option A is acceptable for POC velocity. This is the most consequential pending decision.

---

### DD-005 · ADR-0013 duplicate / numbering conflict

**Status:** ✅ Resolved (2026-05-28). Duplicate `ADR-0013-clob-order-book-migration.md` deleted; ADR-0013 and ADR-0011/ADR-0012 all marked Accepted.

---

### DD-006 · CLOB cashout mechanism

**Status:** ✅ Done (PR #36). Option A (sell limit orders) + Option B (operator buyback at mid-price) both implemented.

**Question:** How should players exit CLOB positions before settlement?
**Context:** `CashoutQuoteService`/`CashoutExecutionService` handle fixed-odds voids only. CLOB players hold contracts (YES/NO) that are only redeemable at settlement.

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Sell limit order on book | Player posts a sell order; matched against buyers on the CLOB. | + Pure market mechanics; price reflects true demand. − Player may be stranded with no buyer; not a guaranteed exit. |
| B: Operator buyback at mid-price | Platform creates a standing buyback offer at `(best_bid + best_ask) / 2`. | + Guaranteed exit at any time. − Operator takes mark-to-market risk; requires a funded buyback wallet. |
| C: No cashout — hold to settlement | Current state. CLOB positions are illiquid until settlement. | + Zero implementation cost. − Player-unfriendly, especially for long-duration markets. |

**Recommendation:** Option A for correctness (exchange semantics). Option C acceptable for short-lived POC markets.

---

### DD-007 · Market edit scope (what fields are updatable after open?)

**Question:** Which market fields should the backoffice be able to edit, and at which lifecycle stages?
**Context:** TD-011 proposes adding an edit form. The question is what can change after the market opens.

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Edit any field while draft | Only pre-open edits. Once open, market is locked. | + Simplest invariant. − Operators can't fix typos in live market descriptions. |
| B: Allow `description`, `close_at`, `resolution_criteria`, `resolution_source` while open | Metadata-only updates on live markets. Mechanism, legs, and fee fields locked once open. | + Practical for real operations. − Need to differentiate which fields are locked. |
| C: Full edit at any status | All fields editable at any time. | + Maximum flexibility. − Risk of changing mechanism/odds on live markets mid-bet. |

**Recommendation:** Option B. Financial fields (`mechanism_type`, `fee_bps`, `liability_cap_minor`, legs) should be immutable once a market is open; metadata is safe to update.
