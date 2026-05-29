# Architecture Deep Review

**Date:** 2026-05-29
**Reviewer:** Architecture Specialist
**Codebase commit context:** post-PR-#36 (main branch, includes DD-006 CLOB sell + operator buyback)

---

## Scope

### Files / docs inspected

**ADRs (all 14):**
- `docs/adr/ADR-0001` through `ADR-0014`

**Core domain models:**
- `app/models/market.rb` — mechanism enum, pricing engine factory, fee config validation
- `app/models/order.rb` — CLOB order, `reserved_minor`, `unfilled_quantity`
- `app/models/bet.rb`, `wallet.rb`, `ledger_entry.rb`, `lmsr_position.rb`, `user.rb`

**Service layer (full read):**
- `app/services/bet_placement_service.rb`
- `app/services/bet_void_service.rb`
- `app/services/cashout_execution_service.rb`
- `app/services/settlement_service.rb`
- `app/services/clob/order_matching_service.rb`
- `app/services/clob/net_position_service.rb`
- `app/services/clob/clob_cashout_service.rb`
- `app/services/clob/operator_buyback_service.rb`
- `app/services/lmsr/lmsr_trade_service.rb`
- `app/services/lmsr/lmsr_pricing_service.rb` (referenced)
- `app/services/parimutuel/parimutuel_pool_service.rb`
- `app/services/parimutuel/parimutuel_settlement_service.rb`
- `app/services/settlement/clob_settlement_handler.rb`
- `app/services/settlement/lmsr_settlement_handler.rb`
- `app/services/hot_storage/market_snapshot_projector.rb`
- `app/services/hot_storage/store.rb`
- `app/services/house_risk_service.rb`
- `app/services/price_snapshot_recorder.rb`
- `app/services/authorization_service.rb`

**Controllers (full read):**
- `app/controllers/admin/markets_controller.rb`, `orders_controller.rb`, `base_controller.rb`
- `app/controllers/backoffice/markets_controller.rb`, `base_controller.rb`
- `app/controllers/web/orders_controller.rb`, `positions_controller.rb`, `leaderboard_controller.rb`, `base_controller.rb`
- `app/controllers/markets_controller.rb` (legacy root-namespace)
- `app/controllers/concerns/authentication.rb`, `role_authorization.rb`

**Domain catalogs:**
- `app/domain/catalogs/permission_catalog.rb`

**Planning documents:**
- `docs/INDEX.md`
- `docs/wiki/tech-debt-backlog.md`
- `.claude/tasks/ATTENTION.md`
- `docs/superpowers/plans/2026-05-29-backend-next-steps.md`

**Tests (sampled):**
- `test/services/settlement_service_test.rb`
- `test/services/clob/order_matching_service_test.rb`
- `test/services/settlement/lmsr_settlement_handler_test.rb`

**Schema (via migration list):** `db/migrate/` last 20 migrations

### Explicitly out of scope

- E2E Playwright tests (`e2e/playwright/`)
- View templates (HTML/ERB), CSS design system
- `docs/design/` wireframes
- Seed files and fixtures (beyond what was referenced during service investigation)
- External integration (no third-party APIs present)
- Infrastructure / Docker / CI scripts

---

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|
| P0 | **CLOB settlement double-pays contracts sold before settlement** — `ClobSettlementHandler` pays every order with `filled_quantity > 0` on the winning side regardless of `direction`. A user who buys 10 YES, sells all 10 YES (filling a sell order), then YES wins still receives a `SETTLEMENT_WIN` credit of 1000 minor; the buyer who filled the sell also receives settlement, creating double payment on the same contracts. | `app/services/settlement/clob_settlement_handler.rb:29` — `where(side: @winning_side).where.not(filled_quantity: 0)`; no `direction` filter. Confirmed by TD-018 in `docs/wiki/tech-debt-backlog.md:161`. | Fix `ClobSettlementHandler` to settle net contracts (use `NetPositionService` output or filter `direction = 'buy'` and subtract filled sell quantity per user). Add regression test: buy YES, sell all YES, YES wins → seller gets 0 settlement. |
| P0 | **CLOB sell orders do not reserve contracts** — `NetPositionService` is queried once at order creation (`validate_sell_position!`) but unfilled sell orders never reserve the contracts they represent. A user with 10 bought contracts can post 3 open sell orders of 10 contracts each; as they fill, the user sells 30 contracts while owning only 10. | `app/services/clob/order_matching_service.rb:72-75` — `validate_sell_position!` checks net position at creation only; `NetPositionService` does not subtract `open_sell_unfilled` quantity. Confirmed by TD-019 in `docs/wiki/tech-debt-backlog.md:168`. | Add contract reservation column or subtract unfilled sell orders in `NetPositionService`; re-validate under row lock at fill time. |
| P0 | **Wallet double-spend race condition in `BetPlacementService`** — `user.wallet` is read outside the transaction at line 18 to check balance; the debit happens at line 30 inside the transaction but uses the stale pre-lock reference. Two concurrent requests can both pass the balance check and both debit, creating negative balance. `BetVoidService:11`, `CashoutExecutionService:12`, and `SettlementService#settle_fixed_odds!:59` share the same pattern. `ParimutuelSettlementService#refund_all!:74` also lacks `lock!`. | `app/services/bet_placement_service.rb:18` — `wallet = user.wallet` (no lock, pre-transaction). Compare to correct pattern in `app/services/clob/order_matching_service.rb:63` — `wallet = order.user.wallet.lock!` inside transaction. Confirmed as TD-013 in tech-debt-backlog and planned in `docs/superpowers/plans/2026-05-29-backend-next-steps.md`. | Apply `user.wallet.lock!` inside the transaction block in all four services. Plan already written (Task 1 in backend-next-steps). |
| P1 | **`ClobPricingEngine#order_book_summary` ignores sell order direction** — The engine queries `orders.where(side: 'YES', status: %w[open partial])` for bids without filtering `direction = 'buy'`. After DD-006, CLOB markets contain both buy and sell orders. Open sell YES orders (players offering to sell YES contracts) appear as bids in the book summary, corrupting the best bid price, operator buyback mid-price, unrealised position value computation, and SSE snapshots. | `app/models/market.rb:54-55` — no `direction` filter. Used for snapshot projection (`hot_storage/market_snapshot_projector.rb:45`), positions page unrealised value (`web/positions_controller.rb:111`), and operator buyback mid-price (`clob/operator_buyback_service.rb:43`). | Add `direction: 'buy'` and handle resting sell orders separately (sell YES resting = ask on YES side). Update `order_book_summary` to differentiate `{ bid: best_buy_YES, ask: best_sell_YES }` and include resting sell orders in depth snapshot. |
| P1 | **`Admin::OrdersController` skips all market lifecycle guards** — `Web::OrdersController#create` enforces `market.open?` and `close_at` guards before dispatching to `OrderMatchingService`. `Admin::OrdersController#create` only checks `market.clob?`. Admin API callers can place CLOB orders on draft, closed, or settled markets, bypassing the trading-state machine. Similarly, `Admin::OrdersController#destroy` does not lock the order row or the wallet inside a transaction, enabling duplicate cancellation. | `app/controllers/admin/orders_controller.rb:7` — only `market.clob?` check. Compare `web/orders_controller.rb:13-25`. TD-020 and TD-021 in tech-debt-backlog. | Move trading-state guards into `OrderMatchingService` (single enforcement point shared by all callers) or duplicate web guards in admin controller. Extract order cancellation into a service object so both web and admin use one locking implementation. |
| P1 | **Pluggable mechanism abstraction leaks through the settlement router and `SettlementService`** — ADR-0013 defines a pluggable mechanism model but the settlement router in `SettlementService#settle!` branches with a raw `case market.mechanism_type` string comparison, while CLOB/LMSR get handler objects and parimutuel is called inline with different patterns. Fixed-odds settlement is entirely inlined as a private class method rather than a handler. There is no common handler interface; each mechanism settlement has different return values, status update placement, and SSE call sites. | `app/services/settlement_service.rb:14-46` — `case` on string; parimutuel calls `Parimutuel::ParimutuelSettlementService` (different from handler pattern); fixed-odds is `private_class_method` inline. CLOB/LMSR use `Handler.new(market, outcome, actor).call`. ADR-0013 does not specify a handler protocol. | Define a `Settlement::BaseHandler` interface (or Ruby module/protocol): `call` with uniform return; `market.update!` and `AuditEvent` always in handler. Extract `settle_fixed_odds!` to `Settlement::FixedOddsHandler`. Router becomes a 4-branch factory call with identical surface. |
| P2 | **Pricing engine classes are inner classes on `Market` model, violating the modular-seam ADR** — ADR-0008 commits to service-boundary isolation for future extraction. The four pricing engines (`FixedOddsPricingEngine`, `ClobPricingEngine`, `LmsrPricingEngine`, `ParimutuelPricingEngine`) live as nested classes inside `Market` (market.rb:45-88). Each holds querying logic over `@market.orders` and calls domain services. This embeds business logic in the model and makes pricing untestable independently. | `app/models/market.rb:45-88`. `ClobPricingEngine` issues ActiveRecord queries (`@market.orders.where(...)`). No standalone test for any pricing engine; they are covered only incidentally through controller integration tests. | Extract pricing engines to `app/services/pricing/` (or `app/models/pricing/` if domain logic boundary is preferred). Keep `Market#pricing_engine` as a factory delegating to the extracted class. Each engine is then independently unit-testable. |
| P2 | **Leaderboard P&L is structurally incomplete for non-fixed-odds mechanisms** — `LeaderboardController::RETURN_TYPES` omits `CLOB_SELL_CREDIT` and `PARIMUTUEL_REFUND`; `STAKE_TYPES` omits `LMSR_FEE` and `CLOB_FEE`. The profile P&L panel queries only the `bets` table and is entirely fixed-odds-only. As CLOB sell, LMSR, and parimutuel activity grows, leaderboard rankings diverge from reality. There is no single authoritative P&L calculation shared between leaderboard and profile. | `app/controllers/web/leaderboard_controller.rb:6-7`. TD-015 in tech-debt-backlog; plan written in backend-next-steps Task 3. | Apply planned constants fix (Task 3 in backend-next-steps). Additionally, extract a `UserPnlService` or `LedgerAggregator` shared by both leaderboard and profile so P&L semantics are defined in one place. |
| P2 | **LMSR positions never appear on the player positions page** — `lmsr_positions` table is the primary store for LMSR settlement (used by `LmsrSettlementHandler`), but `Web::PositionsController#index` never queries `LmsrPosition`. Players with LMSR positions see an empty page. | `app/controllers/web/positions_controller.rb:1-14` — no `@lmsr_positions` variable. `lmsr_settlement_handler.rb:39` confirms `lmsr_positions` drives payouts. TD-014 in tech-debt-backlog; plan written in backend-next-steps Task 2. | Apply planned fix (Task 2 in backend-next-steps). |
| P2 | **`Admin::MarketsController#market_params` missing `:category` and `:tags`** — E2E tests create markets via the admin API, so all E2E fixture markets default to `category: 'other'`. The category filter bar is never exercised in E2E. | `app/controllers/admin/markets_controller.rb:81-84`. TD-016 in tech-debt-backlog; plan written (Task 4). | One-line fix (Task 4 in backend-next-steps). |
| P2 | **`MarketCancellationService` is absent despite `Market` enum having `cancelled: 3`** — No operator recovery path exists for bad markets. `SettlementService` only accepts `open` or `closed` markets. CLOB reservations, LMSR positions, and parimutuel stakes are stranded if a market must be voided. | `app/models/market.rb:5` — `cancelled: 3` present. `app/services/settlement_service.rb:5` — guards exclude `cancelled`. `config/routes.rb` — no `:cancel` route in backoffice namespace. TD-017 in tech-debt-backlog; planned in backend-next-steps Task 5. | Implement `MarketCancellationService` (plan already written). |
| P3 | **`OperatorBuybackService` assumes the operator has sufficient wallet balance but does not enforce it** — The service delegates to `OrderMatchingService` which does call `wallet.lock!` and checks `available_minor >= reservation`. However, the backoffice UI gives no feedback about the operator's wallet balance before placing a buyback order, and there is no designated operator-funding mechanism or separate liquidity wallet. The operator's personal `User` wallet is used as the funding source, mixing platform operator funds with player accounts. | `app/services/clob/operator_buyback_service.rb:24-31` — passes `@operator` (a `User`) to `OrderMatchingService`. No wallet pre-check or operator-specific wallet. | Document the operator-wallet funding requirement. For a production system, introduce an `OperatorAccount` or platform reserve wallet separate from user wallets. |
| P3 | **`PriceSnapshot` table is written on every trade but never read by any controller or endpoint** — The `RecordPriceSnapshotJob` and `PriceSnapshotRecorder` correctly capture price history per mechanism. No `/web/markets/:id/price_history` or `/admin/markets/:id/price_snapshots` endpoint exposes the data. The table accumulates without any consumer. | `app/models/price_snapshot.rb` exists. No controller references `PriceSnapshot` (verified by grep). F-004 in `docs/wiki/tech-debt-backlog.md` notes "no web/admin price-history endpoints." | Either wire a price-history endpoint or remove snapshot recording until it is needed (cost of writes at scale is non-trivial). This is a spec/plan decision, not a code bug. |
| P3 | **`LMSR_TRADE_STAKE` ledger entries lack `market_id` metadata, complicating LMSR cancellation** — The planned `MarketCancellationService` (Task 5 in backend-next-steps) notes this gap inline: the LMSR refund falls back to `AuditEvent` to derive per-user cost because `LMSR_TRADE_STAKE` ledger entries have no `market_id` in metadata (unlike `PARIMUTUEL_STAKE`). | `app/services/lmsr/lmsr_trade_service.rb:54-60` — `LedgerEntry.create!` for `LMSR_TRADE_STAKE` does not pass `metadata: { market_id: ... }`. Compare `parimutuel_pool_service.rb:18-22` which does. `MarketCancellationService` planned code at docs/superpowers/plans/2026-05-29-backend-next-steps.md:658-665 comments on this explicitly. | Add `metadata: { market_id: @market.id, side: @side, quantity: @quantity }` to `LMSR_TRADE_STAKE` LedgerEntry in `LmsrTradeService`. This makes the ledger self-consistent across all mechanisms and simplifies any future LMSR audit or cancellation logic. |
| P3 | **Hot-storage snapshot TTL (120 s) is misaligned with CLOB order-book semantics** — The Redis snapshot expires in 120 seconds. On a live CLOB market with no new trades, the snapshot falls out of hot storage and the SSE `cold fallback` path rebuilds from PG. The SSE stream continues to publish stale or missing order-book depth data without indication that the snapshot is stale. There is no staleness header or `ETag` on the SSE stream. | `app/services/hot_storage/store.rb:59` — `snapshot_ttl_seconds: 120`. `ReconcileMarketHotStateJob` re-projects all open markets; its schedule is not visible in this review (no cron config found in the inspected files). | Increase TTL on active markets or trigger TTL extension on each new event. Add a `stale_at` field to the snapshot payload so the SSE client can surface a "prices may be delayed" warning. |

---

## Detailed Notes

### ADR Adherence

All 14 ADRs are marked Accepted and the implementations are broadly consistent with their decisions:

- ADR-0001 (modular monolith): Correct. The three namespaces (`admin/`, `backoffice/`, `web/`) enforce surface separation. No cross-namespace write coupling observed.
- ADR-0003 (ledger-first wallet): Correct. Every financial state change is dual-tracked: wallet `available_minor` update + `LedgerEntry`. However, the wallet balance (`available_minor`) and the ledger do not have a programmatic reconciliation check — they can diverge if any code path mutates the wallet without creating a ledger entry.
- ADR-0005 (RBAC): Correct. `AuthorizationService` resolves deny → allow → role → implicit deny. `PermissionCatalog` is the single source of permission keys.
- ADR-0008 (modular seams): Partially diverging. The ADR states "enforce service boundaries by context, explicit event contracts." In practice, the settlement router in `SettlementService` uses raw strings for branching and handles parimutuel inline, not through a handler. Pricing engines are inner classes on the model. These are not extraction-ready seams.
- ADR-0012 (hot/cold storage): Correct. Redis used for snapshots and SSE; PG is system of record. `NullRedis` ensures tests and environments without Redis work. TTL concern noted above.
- ADR-0013 (pluggable mechanisms): Largely correct. Four mechanisms implemented. The ADR checklist items are all ticked. The `pricing_engine` factory is on `Market`. The remaining divergence is the inconsistent settlement handler pattern (noted as P1 finding).
- ADR-0014 (CLOB): Correct at the order-book level. The two critical gaps (settlement overpay TD-018, sell reservation TD-019) were identified post-implementation and are tracked.

### Service Object Seams

The service layer has a clear and healthy pattern for CLOB and LMSR:
- `Clob::OrderMatchingService` — well-bounded, uses `FOR UPDATE SKIP LOCKED` for concurrency-safe matching.
- `Lmsr::LmsrTradeService` — correct use of `market.lock!` and `user.wallet.lock!` inside transaction.
- `Parimutuel::ParimutuelPoolService` — correct locking.

The gap is the older fixed-odds path (`BetPlacementService`, `BetVoidService`, `CashoutExecutionService`) which was written before the locking pattern was established in the CLOB/LMSR services. These three services collectively represent the most financially dangerous gap in the codebase (P0 finding).

### Settlement Architecture

The settlement pathway has four distinct implementations that should be five uniform ones (including a `FixedOddsSettlementHandler`). The current layout:

```
SettlementService.settle!
  case mechanism_type
  when 'clob'        → Settlement::ClobSettlementHandler.new(...).call
  when 'lmsr'        → Settlement::LmsrSettlementHandler.new(...).call
  when 'parimutuel'  → Parimutuel::ParimutuelSettlementService.call(...)  ← different namespace, different call pattern
  else               → private_class_method settle_fixed_odds!(...)       ← inlined, not a handler
```

`ParimutuelSettlementService` lives in the `Parimutuel::` namespace (not `Settlement::`), calls `market.update!(settled_outcome: outcome)` differently from handlers (which call `market.update!` themselves), and the router has to call `market.update_columns(settled_outcome: outcome)` separately afterward (`settlement_service.rb:27`). This asymmetry is a maintenance hazard.

The `ClobSettlementHandler` (P0 finding) pays winners by iterating `orders.where(side: winning_side).where.not(filled_quantity: 0)` without a `direction` filter. After DD-006, sell orders are in this set. A player who:
1. Buys 10 YES contracts
2. Sells all 10 YES via a sell order (which gets filled by a buyer)
3. At settlement when YES wins

...receives 1000 minor (`10 × 100`) via `SETTLEMENT_WIN` even though they no longer hold any contracts. The buyer who filled the sell order also receives 1000 minor. This is a real double-payment vulnerability on any market that has seen sell activity.

### Hot/Cold Storage Architecture

The hot-storage design is clean and well-isolated. Key observations:

1. **TTL risk**: snapshots expire at 120 s. Active CLOB markets with low trade frequency will cycle through cold fallback frequently. The SSE stream then re-reads from PG on each `XADD`-triggered read, which partially defeats the hot-storage purpose.
2. **Snapshot consistency**: `build_snapshot` at `market_snapshot_projector.rb:28` queries `market.bets.where(status: :open).sum(:net_stake_minor)` for `total_open_interest_minor`. For CLOB markets, bets are empty (CLOB uses orders, not bets). The snapshot field is correct for fixed-odds but semantically empty for CLOB. This is cosmetic but could confuse monitoring or analytics consumers.
3. **`ClobPricingEngine` direction gap** (P1 finding): the projector calls `market.pricing_engine.order_book_summary` to populate the CLOB depth snapshot (`market_snapshot_projector.rb:45`). Because sell orders are not filtered, the published SSE order book can show sell YES orders as bids.

### RBAC and Authorization

The RBAC model (ADR-0005) is faithfully implemented. Notable:
- `AuthorizationService` is the single decision point; no inline role checks found in services.
- The permission catalog correctly restricts `market.update` to `admin` only, while `market.settle` is granted to both `admin` and `moderator`.
- The `backoffice.access` check on `Admin::BaseController` is a useful defense-in-depth gate.
- No privilege escalation paths observed.

One observation: the `OperatorBuybackService` uses `current_user` (an admin or moderator User) as the `operator` parameter. This user's wallet is debited for the buyback order. If the operator's wallet runs dry, the buyback silently fails with an "Insufficient funds" error. There is no audit trail distinguishing "operator acting as liquidity provider" from "operator's personal wallet." This is architectural ambiguity, not a security bug.

### Modular Seam Analysis

The `app/domain/catalogs/` directory contains `PermissionCatalog`, `ActionCatalog`, and `MarketTemplateCatalog`. These are static data catalogs with no dependencies on ActiveRecord. This is the cleanest separation in the codebase and matches the ADR-0008 intent.

The services under `app/services/clob/`, `app/services/lmsr/`, `app/services/parimutuel/`, and `app/services/settlement/` form natural bounded contexts. They do not cross-call each other (CLOB services call CLOB services, LMSR services call LMSR services). This is the correct seam pattern.

The violation is the pricing engines being inner classes on `Market`. If CLOB logic is extracted as a microservice, the pricing engine would need to be extracted too, but it is entangled in the model.

### Missing Ledger Contract for LMSR Trades

`LMSR_TRADE_STAKE` entries carry no `metadata: { market_id: ... }` (confirmed at `lmsr_trade_service.rb:54-60`). Every other mechanism-specific ledger entry carries market context:
- `BET_STAKE` → `metadata: { bet_id, market_id }` (bet_placement_service.rb:47)
- `PARIMUTUEL_STAKE` → `metadata: { market_id, side }` (parimutuel_pool_service.rb:18)
- `CLOB_SELL_CREDIT` → `metadata: { market_id, fill_price, fill_qty }` (order_matching_service.rb:220)

LMSR is the outlier. Consequence: any ledger-based audit, P&L breakdown by market, or cancellation logic must fall back to `AuditEvent` for market attribution, as the planned `MarketCancellationService` does (backend-next-steps.md:659-666).

---

## Open Questions

1. **Operator wallet funding model**: Should the operator who places a buyback order use their personal `User` wallet, or should a platform reserve account exist (separate from all player wallets) to fund operator market-making and subsidy payments? The current model makes no distinction between an admin user's personal ADIV balance and platform-deployed liquidity. This is an architectural decision that affects multi-operator deployments.

2. **Ledger as source of truth**: The wallet `available_minor` is maintained by direct update alongside each ledger entry. There is no programmatic check that `sum(credits) - sum(debits) = wallet.available_minor + wallet.reserved_minor`. Should a background job or constraint enforce this invariant? At present, any code path that updates a wallet without a corresponding ledger entry (e.g., a future service forgetting the pattern) creates a silent divergence.

3. **`PriceSnapshot` table purpose**: Should snapshots be kept, exposed as a price-history endpoint (F-004), or removed until the product needs them? At current write frequency (per-trade), on high-volume CLOB markets this table will grow rapidly. There is no retention policy, no index on `recorded_at`, and no consumer.

4. **Settlement handler protocol**: Should there be a Ruby interface (module with abstract method stubs) for `Settlement::*Handler` or is the duck-type convention (all respond to `.call`) sufficient? Given ADR-0008's extraction intent, an explicit interface contract would make future service extraction safer.

5. **CLOB order book model for sell orders**: When a player posts a sell YES order (resting in the book), from the market's perspective this is an offer to sell YES contracts at a given price — i.e., an ask on YES. The current `ClobPricingEngine` does not distinguish sell-resting from cross-side buy orders in the bid/ask computation. What is the canonical order book display model: two-sided (YES bid / YES ask with separate sell resting) or single-sided cross (only cross-side buy pairs)?

---

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|--------------|------|------|--------------|-----------------|
| ARCH-001 | **Fix CLOB settlement overpay (TD-018)**: Update `ClobSettlementHandler#call` Pass 2 to settle only net long contracts per user (use `NetPositionService` output or filter `direction = 'buy'` and subtract filled sell quantity). Add regression test: buy YES → sell all YES → YES wins → assert 0 settlement payout for seller. | S (2–4 h) | TD-019 should be addressed first or in the same PR to avoid confusion about what "net" means | Test passes; E2E multi-player settlement tests still pass |
| ARCH-002 | **Reserve contracts for open sell orders (TD-019)**: Extend `NetPositionService` to subtract unfilled open sell orders (`bought - filled_sold - open_sell_unfilled`). Re-validate net position under row lock inside `execute_sell_fill!`. Add sequence test: place 2 sell orders for all contracts; second should fail. | M (4–8 h) | ARCH-001 should be in the same PR or immediately follow | Tests assert sell order 2 fails when contracts already reserved; no negative net position possible |
| ARCH-003 | **Unify settlement handler pattern**: Extract `Settlement::FixedOddsHandler`; move `ParimutuelSettlementService` call inside a `Settlement::ParimutuelHandler`; define common `call` interface. `SettlementService` becomes a 4-branch factory. | M (4–6 h) | None (refactor, no behavior change) | All existing settlement tests pass; no new branches added |
| ARCH-004 | **Fix `ClobPricingEngine#order_book_summary` to handle sell orders**: Add `direction: 'buy'` filter to bid query; add `direction: 'sell'` filter for resting sell orders to compute ask on same side. Propagate to snapshot projector and operator buyback mid-price. | S (2–4 h) | None | Operator buyback mid-price reflects actual market; SSE order-book depth is correct after a sell order is placed |
| ARCH-005 | **Add `market_id` metadata to LMSR_TRADE_STAKE ledger entries**: Add `metadata: { market_id: @market.id, side: @side, quantity: @quantity }` to `LMSR_TRADE_STAKE` LedgerEntry in `LmsrTradeService`. Write a backfill migration for existing entries (nullable for old rows). | XS (1–2 h) | None | New LMSR trades produce ledger entries with `metadata['market_id']`; `MarketCancellationService` LMSR path can use ledger entries directly |
| ARCH-006 | **Extract pricing engines to standalone classes** (`app/services/pricing/` or `app/models/pricing/`): Move `FixedOddsPricingEngine`, `ClobPricingEngine`, `LmsrPricingEngine`, `ParimutuelPricingEngine` out of `Market` inner class scope. Keep `Market#pricing_engine` as a factory. Add unit tests per engine. | M (4–6 h) | ARCH-004 should be done first so the new engine is already correct before extraction | Each pricing engine has at least 2 isolated unit tests; no existing test changes |
| ARCH-007 | **Extract order cancellation into a service object** (`Clob::OrderCancellationService`): Share one locking implementation between `Web::OrdersController#destroy`, `Admin::OrdersController#destroy`, and `ClobSettlementHandler` Pass 1. Fix admin controller to use `Order.lock.find` inside transaction. | S (2–4 h) | None | Admin destroy no longer has dual-cancellation vulnerability; web and admin use same service |
| ARCH-008 | **`UserPnlService` — single P&L calculation for leaderboard + profile**: Extract `LeaderboardController` STAKE_TYPES / RETURN_TYPES constants (with the TD-015 fix applied) into a shared service/module used by both `LeaderboardController` and profile P&L. | S (2–3 h) | TD-015 fix (Task 3 in backend-next-steps) | Both leaderboard and profile show identical P&L for the same user; covered by integration tests |
| ARCH-009 | **Add staleness indicator to Redis snapshot**: Add `stale_at` (TTL expiry timestamp) to snapshot payload. SSE client can display "prices may be delayed" if `stale_at < now`. | XS (1 h) | None | SSE payload includes `stale_at` field; no behavior change in existing consumers |
| ARCH-010 | **`PriceSnapshot` retention policy**: Either expose a `/web/markets/:id/price_history` endpoint (fulfilling F-004) or add a `prune_price_snapshots` job (retain last N per market) to prevent unbounded table growth. Decision must be made before volume scales. | L (8–16 h for endpoint; S for prune job) | F-004 spec needed for endpoint path | Table size stays bounded; or endpoint returns historical prices correctly |
