# Plan Review: Pluggable Market Mechanisms

<!-- File location: docs/superpowers/plans/2026-05-27-pluggable-market-mechanisms-review.md -->
<!-- Written AFTER the plan, BEFORE execution. Quick sanity check. -->

## Plan reviewed: [2026-05-27-pluggable-market-mechanisms.md](2026-05-27-pluggable-market-mechanisms.md)
## Spec reviewed: [docs/specs/2026-05-27-pluggable-market-mechanisms.md](../../specs/2026-05-27-pluggable-market-mechanisms.md)

---

## Findings

### Coverage gaps

- [x] **Spec FR-2a-6 (admin JSON API `mechanism_type` param)** — The plan modifies the backoffice HTML form (Task 14) but does not explicitly add `mechanism_type` to the admin JSON API `POST /admin/markets` strong params. **Required addition:** Task 14 should include updating `Admin::MarketsController` permitted params in addition to the backoffice controller.
- [x] **Spec invariant 9 (lmsr_b_parameter persisted at open time)** — Task 7 stores `lmsr_b_parameter` only when a trade is placed; the spec requires it to be computed and stored when the market transitions to `open`. **Required fix:** Add a `before_save` callback or service call in the market open transition to compute `b = LmsrPricingService.b_from_subsidy(liquidity_subsidy_minor)` and write it to `lmsr_b_parameter` when `status` changes from `draft` to `open`.
- [x] **Spec FR-2d-3 (`ParimutuelBet` model)** — The parimutuel settlement math references individual bettor stake records to compute pro-rata payouts, but the plan does not create a `ParimutuelBet` model or migration. Task 9's `ParimutuelSettlementService` notes this as "delegated to settlement router" but there is no `ParimutuelBet` table to iterate. **Resolution option:** For v1, scope the settlement to iterate `LedgerEntry` rows with `entry_type = "PARIMUTUEL_STAKE"` keyed by `metadata.market_id` — avoid a new model if the stake amount is already in ledger entries. This must be made explicit in Task 9.
- [x] **Spec FR-2b-9 (`order_book` controller)** — Routes add `order_books#show` but no `Web::OrderBooksController` is in the create list. **Required addition:** Add `app/controllers/web/order_books_controller.rb` to Task 5's file list and implement it.
- [ ] **Web LMSR and parimutuel endpoints** — Tasks 8 and 7 implement services but the matching web controllers (`web/lmsr_trades_controller.rb`, `web/parimutuel_bets_controller.rb`) listed in the File Map have no corresponding task steps. These controllers need to be added to Tasks 7 and 8 respectively, or as a new Task 7b/8b.

### Placeholder scan

- [x] **Task 9, Step 9.3 comment** — `"In production this iterates ParimutuelBet records; stub for unit test"` is effectively a placeholder. It must either (a) be implemented with ledger-entry iteration as noted above, or (b) be explicitly called out as a known v1 limitation in FINDINGS.md with the exact query to use when the `ParimutuelBet` model is added later.
- [x] **Task 10, Step 10.2** — "Locate the entry method and add" is slightly underspecified. The exact method name in `settlement_service.rb` should be confirmed before execution (it is `call` in the existing implementation; confirm the method signature matches).
- [ ] All other steps contain real code with no TBD/placeholder language.

### Type/signature consistency

- [x] `Clob::OrderMatchingService.call` returns a `Result` struct with `.success?`, `.incoming_order`, `.fills`. Task 5's controller calls `result.success?` and `result.incoming_order` — **consistent**.
- [x] `Lmsr::LmsrPricingService.new(b:, q_yes:, q_no:)` is used identically in Tasks 6, 7, 12 — **consistent**.
- [x] `Lmsr::LmsrPricingService.b_from_subsidy(liquidity_subsidy_minor)` is defined in Task 6 and called in Task 7's setup — **consistent**.
- [x] `Parimutuel::ParimutuelPoolService.yes_probability(market)` (class method) used in Tasks 8, 12, 15 — **consistent**.
- [x] `Parimutuel::ParimutuelSettlementService.call(market:, winning_side:, settled_by:)` used in Tasks 9 and 10 — **consistent**.
- [x] `Market#pricing_engine` factory defined in Task 2; used in Tasks 12, 14, 15 — **consistent**.
- [x] `Market.mechanism_type` used as a string throughout (not symbol enum) — **consistent** with existing `mechanism_type` string column in schema.rb.
- [x] `Order.status` enum values (`open`, `partial`, `filled`, `cancelled`) used consistently across Tasks 3, 4, 5, 10 — **consistent**.
- [x] `HotStorage::MarketSnapshotProjector.project(market)` called in Task 13; assumed to exist from ADR-0012 hot-storage work — **verify method name matches existing projector before execution**.

### Risk flags

- [x] **Migration ordering risk** — Five migrations are numbered `20260527100001` through `20260527100005`. If any prior migration (e.g. `20260525122614`) modifies `markets`, the column additions in Task 1 must not conflict. Verified: existing schema has no `taker_fee_bps`, `lmsr_q_yes`, or `parimutuel_pool_yes_minor` — no conflict.
- [x] **Existing `fixed_odds` markets unaffected** — All new columns are nullable (or have defaults of 0). No existing market record requires a value. The new validations are conditional on `mechanism_type`, so existing `fixed_odds` markets pass validation unchanged. **Safe.**
- [x] **Partially-filled CLOB orders at settlement** — Task 10 (ClobSettlementHandler) explicitly iterates `orders.where(status: %w[open partial])` and calls `cancel_remainder!`. Orders with `status: :partial` have `filled_quantity > 0`; their winning contracts are still credited by the second loop (`orders.where(side: winning_side).where.not(filled_quantity: 0)`). **Edge case handled.**
- [x] **LMSR subsidy exhaustion** — The plan does not add a check that `lmsr_q_yes` / `lmsr_q_no` growth would cause the operator's loss to exceed `liquidity_subsidy_minor`. For v1, this is acceptable (spec marks it out-of-scope); the FINDINGS.md should note this as a known gap for v2.
- [x] **Parimutuel late bets** — After the market closes (`status != open`), `ParimutuelPoolService.add_stake` will fail at the market open check in `BetPlacementService` (shared). No explicit guard is in `ParimutuelPoolService` itself. **Required fix:** Add `raise "Market is not open" unless market.open?` at the top of `add_stake`.
- [x] **Concurrent LMSR trades** — `lmsr_q_yes` and `lmsr_q_no` are updated with `market.lock!` (`SELECT FOR UPDATE`). This prevents a race condition where two concurrent trades read the same q values and both apply their delta. **Handled.**
- [x] **Double-spend on CLOB order placement** — `reserve_funds!` does `wallet.lock!` before reading `available_minor`. This prevents two concurrent orders from both passing the funds check and draining the wallet below zero. **Handled.**
- [x] **FOK test creates resting NO order but FOK order wants 5, only 3 available** — Test correctly expects `cancelled` with 0 fills. The implementation cancels the whole order before any fill. **Consistent.**
- [x] **`Market.mechanism_type` immutability check** — The validation `mechanism_type_immutable_when_open` fires on every save. The condition `status_changed? == false && mechanism_type_changed?` is checked. However, on the `draft → open` transition, both `status` and `mechanism_type` may be unchanged (the mechanism is fine to keep); the check correctly allows this. **Safe.**
- [ ] **`clob?` helper method** — Task 5 uses `market.clob?` but no such method is defined in Task 2. Rails does not auto-generate string column predicates. **Required fix:** Add `def clob? = mechanism_type == "clob"` (and similarly `lmsr?`, `parimutuel?`, `fixed_odds?`) to the `Market` model in Task 2.

---

## Required Changes Before Execution

1. **Task 2** — Add `clob?`, `lmsr?`, `parimutuel?`, `fixed_odds?` predicate helpers to `Market` model. Add `lmsr_b_parameter` computation to the `draft → open` transition (via callback or service).
2. **Task 5** — Add `Web::OrderBooksController` to the file list and implement `show` action returning order book depth.
3. **Task 7 / Task 8** — Add web controller implementations (`Web::LmsrTradesController`, `Web::ParimutuelBetsController`) as explicit steps, not just file-map entries.
4. **Task 9** — Replace "stub for unit test" in `refund_all!` with a concrete ledger-entry iteration pattern. Document `ParimutuelBet` model as deferred v2 work in FINDINGS.md.
5. **Task 14** — Also update `Admin::MarketsController` strong params to permit `mechanism_type` and all fee fields.
6. **Task 8, `add_stake`** — Add guard `raise "Market is not open" unless market.open?` at entry.

---

## Decision

**Approved with required changes** — proceed to execution after the six items above are resolved. The core logic (migrations, pricing services, matching engine, settlement router) is sound and all edge cases are handled. The gaps are additive (missing guards, missing controllers, missing model helpers) and do not require architectural changes.

Proceed using `superpowers:subagent-driven-development`.
