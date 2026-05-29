# Rails / Code Correctness Deep Review

## Scope

### Files/docs inspected

- `CLAUDE.md`, `docs/INDEX.md`, `.claude/tasks/ATTENTION.md`, `docs/wiki/tech-debt-backlog.md`
- `docs/reviews/2026-05-29-deep-review/market-mechanics.md` (read to avoid duplication)
- `config/routes.rb`
- All files under `app/controllers/` (admin, backoffice, web, auth, sse, legacy roots)
- All files under `app/models/`
- All files under `app/services/` (bet placement, void, cashout, settlement, CLOB, LMSR, parimutuel, hot storage, betslip, wallet, JWT)
- All files under `app/jobs/`
- All files under `test/services/` and `test/integration/` (full list)

### Explicitly out of scope

- Financial invariants, ledger accounting correctness, mechanism overpay/underpay logic — covered in `market-mechanics.md`
- Database schema migrations, index strategy, Postgres constraint coverage — reserved for `data-postgres.md`
- Security audit (pen-test posture, secrets at rest) — reserved for `security-trust.md`

---

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|
| P0 | `BetPlacementService` reads and compares wallet balance **outside** the transaction then debits inside. Two concurrent bets on the same wallet can both pass the balance check on a stale value, producing a negative balance. | `app/services/bet_placement_service.rb:18-30` — `wallet = user.wallet` at line 18 before `ApplicationRecord.transaction do` at line 29; no `lock!` call; debit at line 30 uses the same stale object. `Wallet` validates `available_minor >= 0` but the validation fires against the already-cached value. | TD-013 (planned): wrap `wallet = user.wallet.lock!` inside the transaction and remove the pre-transaction balance check. |
| P0 | `SettlementService#settle_fixed_odds!` iterates every winning bet and credits wallets **without locking** the wallet row, so concurrent settlement + a concurrent cashout can produce a double credit to the same wallet. | `app/services/settlement_service.rb:59-60` — `wallet = bet.user.wallet` (no `lock!`). Every other wallet debit/credit path in LMSR, parimutuel settlement, and CLOB matching already uses `wallet.lock!`. The same pattern repeats in `BetVoidService` (line 11) and `CashoutExecutionService` (line 12). | Add `.lock!` to every wallet mutation that lacks it: `settlement_service.rb:59`, `bet_void_service.rb:11`, `cashout_execution_service.rb:12`, and `wallet_grant_service.rb:6`. |
| P0 | `ClobSettlementHandler` Pass 1 (cancel open orders) updates wallet **without locking** the wallet row. A concurrent cashout or trade against the same wallet during settlement can corrupt `reserved_minor` / `available_minor`. | `app/services/settlement/clob_settlement_handler.rb:18` — `w = order.user.wallet` (no `lock!`). Pass 2 at line 33 does use `wallet.lock!`, creating an inconsistency within the same handler. | Add `.lock!` at line 18 and also use `order.lock!` or ensure the order row itself is locked before computing `released`. |
| P0 | `Admin::OrdersController#destroy` reads the order and computes `released_minor` **before** entering the transaction, and acquires no row lock on either the order or the wallet. A concurrent fill or dual-cancel request can see an already-cancelled order and release funds a second time. | `app/controllers/admin/orders_controller.rb:32-43` — `order = Order.find(...)` at line 31 with no `lock`, `released = order.reserved_minor` at line 37 outside transaction. Compare to `Web::OrdersController#destroy` at line 58, which correctly calls `Order.lock.find`. | Move `Order.lock.find` and `wallet.lock!` inside the transaction in `Admin::OrdersController#destroy`. Extract shared cancel logic into a `Clob::OrderCancellationService` to prevent future divergence. |
| P1 | `BetslipExecutionService` acquires a lock on the `BetslipQuote` row but calls `BetPlacementService.place!` inside the same transaction, which itself does **not** lock the wallet. With multiple betslip legs, each leg's placement races against other concurrent wallet mutations. | `app/services/betslip_execution_service.rb:16-31` — the outer transaction wraps multiple `BetPlacementService.place!` calls; placement debits wallet without lock (see P0). The quote lock prevents double-execution of the same quote, but does not protect against wallet over-spend from concurrent independent bets. | Fix propagates from TD-013: once `BetPlacementService` locks the wallet, betslip execution is safe. |
| P1 | `ParimutuelSettlementService#refund_all!` (zero-winning-pool path) updates wallets **without locking**. A player's wallet could receive a double refund if the method is called twice (e.g., due to a retry or operator error). | `app/services/parimutuel/parimutuel_settlement_service.rb:74` — `w = entry.user.wallet` (no `lock!`). The same service at line 37 (winning path) correctly uses `wallet.lock!`, creating an inconsistency. `Market#status` is updated only after payouts complete (line 20–21 / 53–54), so a retry before `status: :settled` is committed can re-execute refund. | Add `.lock!` to `refund_all!` wallet access; move `market.update!(status: :settled)` to the **top** of the transaction (similar to `LmsrSettlementHandler`) so retries are idempotent. |
| P1 | `WalletGrantService#approve!` debits the wallet without locking it, and the faucet approval endpoint does not prevent double-approval race. A second admin clicking "Approve" before the first request commits could approve the same request twice. | `app/services/wallet_grant_service.rb:6-7` — `wallet = faucet_request.user.wallet` (no `lock!`); `app/controllers/backoffice/faucet_requests_controller.rb:17-20` — pending check and `WalletGrantService.approve!` are not atomic (no row lock on `faucet_request`). | Use `FaucetRequest.lock.find(params[:id])` inside the transaction; add `wallet.lock!`. |
| P1 | N+1 queries in `ClobSettlementHandler`: `find_each` on orders (no `includes`) triggers one `user` load and one `wallet` load **per order row** across both passes. On a busy market with hundreds of orders this can be thousands of queries inside one settlement transaction. | `app/services/settlement/clob_settlement_handler.rb:11-26` and `29-40` — both loops call `order.user.wallet` (or `.lock!`) per iteration with no eager loading. | Add `.includes(user: :wallet)` to both queries, then call `.lock!` only when mutating (use `User.where(id: user_ids).lock.includes(:wallet)` or a scoped lock approach). |
| P1 | `Admin::OrdersController#create` does not check whether the market is `open?` or has passed `close_at` before placing a CLOB order. Admin users can inject orders onto draft, closed, cancelled, or settled markets, bypassing all lifecycle guards that `Web::OrdersController` enforces. | `app/controllers/admin/orders_controller.rb:6-21` — only `market.clob?` is checked. `Web::OrdersController#create` at lines 13-25 also checks `market.open?` and `close_at`. TD-020 confirms this gap. | Move market open/close_at guards into `Clob::OrderMatchingService` so all callers share them, or duplicate the checks in `Admin::OrdersController#create`. Add integration tests for draft/closed/expired CLOB order attempts via admin API. |
| P2 | `CloseExpiredMarketsJob#system_actor` queries the database inside `find_each` on each loop iteration if `@system_actor` is nil (only memoized per job object). Also, if no admin user exists, it falls back to `User.first`, which may be a player — creating audit events attributed to the wrong role. | `app/jobs/close_expired_markets_job.rb:26-28` — `@system_actor ||= User.where(role: User.roles[:admin]).first || User.first`. `rescue StandardError => e` at line 19 swallows all errors per market without re-raising; failures are logged but the job succeeds, hiding systematic errors. | Memoize `system_actor` before the `find_each` loop; raise or alert (Sentry/Honeybadger) if no admin exists rather than silently falling back to `User.first`. Consider re-raising after logging so Solid Queue records the failure properly. |
| P2 | `Web::MarketsController#index` shows all markets (including drafts) to authenticated users but limits unauthenticated users to `open/settled/closed`. An authenticated player (not admin/moderator) can see draft market titles and descriptions they should not see. | `app/controllers/web/markets_controller.rb:10-14` — `if current_user` removes the status filter entirely; any authenticated user (including `role: :player`) sees draft markets. | Restrict draft visibility to users with `market.read` permission or a backoffice role; add a scope test verifying players cannot see draft market data. |
| P2 | `ProfileController#show` computes P&L using only the `bets` table (`net_stake_minor`, `potential_payout_minor`). LMSR, CLOB, and parimutuel activity (costs and payouts stored as `LedgerEntry` rows) are entirely absent, so a player who used any non-fixed-odds mechanism sees incorrect win rates and P&L totals. | `app/controllers/web/profile_controller.rb:21-34` — all queries are on `Bet` model only; no ledger-based aggregation. Contrast with `LeaderboardController` which aggregates across entry types. | Rewrite profile P&L to aggregate `LedgerEntry` by mechanism-aware stake/return entry types, mirroring `LeaderboardController::STAKE_TYPES` and `RETURN_TYPES` (and fix those constants per TD-015 first). |
| P2 | `LeaderboardController::RETURN_TYPES` omits `CLOB_SELL_CREDIT` and `PARIMUTUEL_REFUND`; `STAKE_TYPES` omits `LMSR_FEE` and `CLOB_FEE`. Players who sell CLOB contracts or receive parimutuel refunds have their P&L understated as returns, and LMSR/CLOB fee payers have costs understated. | `app/controllers/web/leaderboard_controller.rb:6-7` — constant definitions. TD-015 documents this gap. | Add missing entry types to both constants; add a leaderboard integration test covering each mechanism type. |
| P3 | `ClobSettlementHandler` Pass 2 overpays holders of filled **sell** orders: every order on the winning side with `filled_quantity > 0` receives a `SETTLEMENT_WIN` credit regardless of direction. A seller who exited their position receives payout for contracts they no longer hold. | `app/services/settlement/clob_settlement_handler.rb:29-39` — query is `where(side: @winning_side).where.not(filled_quantity: 0)` with no filter on `direction`. TD-018 documents this. Note: the market-mechanics review already covers the double-payout economic impact; this entry notes the **code bug** (missing `direction: 'buy'` filter). | Add `direction: 'buy'` filter to Pass 2 query (or switch to `NetPositionService`); add a regression test: player buys YES, sells all YES, YES wins, player receives no settlement payout. |
| P3 | `LmsrTradeService#upsert_position` uses `find_or_initialize_by` + `save!` without a row lock, so two concurrent LMSR trades by the same user on the same market/side can create a race on the `lmsr_positions` row (or fail the unique index). | `app/services/lmsr/lmsr_trade_service.rb:96-100` — `find_or_initialize_by` is not atomic. The `lmsr_positions` table has a unique index on `(user_id, market_id, side)`, so the second writer will raise `RecordNotUnique`, which is caught by the outer `rescue StandardError` and returned as an error result — silent to the caller but the trade is lost. | Replace with `LmsrPosition.lock.find_or_create_by!(...)` and increment inside the same lock, or use `upsert` with `conflict_target`. |
| P3 | `BetslipQuoteService` validates market open-ness at quote time but does not re-check at execution time inside `BetslipExecutionService`. If a market closes or is cancelled in the 60-second TTL window, execution proceeds until `BetPlacementService.place!` raises, which rolls back the whole transaction — but only after deducting wallet balances for earlier legs, reverting them in the rollback. The atomicity is correct, but the error message surfaced is `ExecutionFailed` with the inner message, which may confuse callers. | `app/services/betslip_execution_service.rb:20-30` — no market state re-check before placement; `app/services/betslip_quote_service.rb:18` — open check only at quote time. | Document the intended behavior explicitly; consider adding a pre-flight market-status check at execution time to surface a clearer error before any wallet operations begin. |

---

## Detailed Notes

### Wallet locking — systematic gap

The project's ledger-first architecture (ADR-0003) requires every wallet mutation to be atomic. The pattern is established and correct in: `LmsrTradeService`, `ParimutuelPoolService`, `ParimutuelSettlementService` (win path), `ClobSettlementHandler` (Pass 2), and all `OrderMatchingService` fill paths.

The same pattern is **missing** in five places:

1. `BetPlacementService:18` — pre-transaction read, no `lock!` inside transaction
2. `BetVoidService:11` — `wallet = locked_bet.user.wallet` (no `lock!`)
3. `CashoutExecutionService:12` — `wallet = locked_bet.user.wallet` (no `lock!`)
4. `SettlementService#settle_fixed_odds!:59` — `wallet = bet.user.wallet` (no `lock!`)
5. `ClobSettlementHandler` Pass 1 `:18` — `w = order.user.wallet` (no `lock!`)
6. `WalletGrantService#approve!:6` — `wallet = faucet_request.user.wallet` (no `lock!`)
7. `ParimutuelSettlementService#refund_all!:74` — `w = entry.user.wallet` (no `lock!`)

The consistent fix: load the wallet with `wallet = user.wallet.lock!` **inside** the transaction. The balance check (if any) must also be inside the transaction and after the lock.

Note: TD-013 in the backlog addresses items 1-4. Items 5-7 are not captured in existing tasks.

### Admin vs. web controller divergence

Three pairs of controllers handle the same resource with different safety guarantees:

| Resource | Web controller (safer) | Admin controller (weaker) |
|----------|----------------------|--------------------------|
| Order destroy | `Order.lock.find` + `wallet.lock!` inside transaction | `Order.find` outside transaction; `wallet` not locked |
| Order create | checks `open?`, `close_at`, `clob?` | only checks `clob?` |
| Market settle | handled by service | same service, safe |

The divergence is a maintenance hazard: fixing the service later requires remembering both call sites. Extracting `Clob::OrderCancellationService` (suggested in TD-021) and moving lifecycle guards into `OrderMatchingService` directly would eliminate the divergence.

### Hot storage / Redis writes inside DB transactions

`BetVoidService`, `LmsrTradeService`, `ParimutuelPoolService`, and `SettlementService` (fixed-odds and parimutuel paths) all call `HotStorage::MarketSnapshotProjector.project!` and/or `Store.current.append_market_event!` **inside an `ApplicationRecord.transaction` block**. If the DB transaction rolls back (e.g., due to a validation failure after the Redis write), the SSE event has already been emitted and cannot be recalled. Clients will receive a snapshot or event that was never committed to Postgres.

The `MarketSnapshotProjector.project!` method silently rescues all Redis errors (`rescue StandardError => e; Rails.logger.warn`), which means a Redis failure does not abort the DB transaction — this is intentional for resilience. The inverse risk (Redis write before DB commit) is real but low-severity at POC scale since the reconciliation job (`ReconcileMarketHotStateJob`) will self-heal mismatches. Flag this for any production hardening plan.

### `CloseExpiredMarketsJob` error handling

The `rescue StandardError => e` at line 19 is **inside** the `find_each` block, scoped to a single market. This is intentional per-market isolation. However, the `system_actor` fallback to `User.first` could attribute audit events to an arbitrary player if no admin exists. The `@system_actor` memoization is per-job-object lifetime, which is correct — the concern is only the nil-admin fallback.

### Profile P&L — fixed-odds only

`ProfileController#show` computes P&L exclusively from the `bets` table. For any player who has used LMSR, CLOB, or parimutuel mechanisms, the profile page shows misleading statistics. The leaderboard avoids this by aggregating `LedgerEntry` by type. The profile page should do the same (after fixing TD-015 constants).

### Draft market visibility to authenticated players

`Web::MarketsController#index:10-14` applies no status filter for authenticated users. A player who is signed in can see the question and description of every draft market. This is likely unintentional — draft markets are "work in progress" and should only be visible to operators with `market.read` permission.

### `LmsrPosition` upsert race

`LmsrTradeService` wraps trades in a transaction and locks the market row (`@market.lock!`), but the `upsert_position` helper at the end of the method uses `find_or_initialize_by` + `save!` without a position-row lock. Two simultaneous LMSR buys by the same user on the same market/side (e.g., from two browser tabs) can both attempt to initialize the row, with one succeeding and one hitting the unique-index violation caught by the outer `rescue`. The market lock is sufficient for pricing correctness but does not protect position-row writes.

---

## Open Questions

1. **Idempotency of settlement** — `SettlementService` transitions the market to `settled` inside the transaction, so re-running it raises `InvalidSettlement`. However, if settlement succeeds in the DB but the HTTP response is lost (network error), the operator may retry. Is there a safe way for the backoffice settle action to detect an already-settled market and return success rather than an error?

2. **Solid Queue job retry semantics** — `CloseExpiredMarketsJob` catches and logs errors per-market but returns `nil` (success) for the job overall. Does Solid Queue consider the job successful even when some markets failed to close? If so, failed market closures are silently dropped without retry.

3. **Draft market visibility intentionality** — Is it intentional that authenticated players (not just operators) can browse draft markets? If yes, document it. If no, add a scope filter.

4. **Hot storage eventual consistency** — Is it acceptable that a rolled-back DB transaction can leave a stale Redis snapshot until the next reconciliation job run (~5 minutes)? Any client that received the SSE event would see state that was never persisted.

5. **System actor for automated actions** — Should `CloseExpiredMarketsJob` use a dedicated "system" user record rather than `User.first` as a fallback? A dedicated system user would prevent audit events being attributed to a real player.

---

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|--------------|------|------|-------------|-----------------|
| CC-001 | Add `wallet.lock!` to `BetVoidService`, `CashoutExecutionService`, `SettlementService#settle_fixed_odds!`, `ClobSettlementHandler` Pass 1, `WalletGrantService#approve!`, `ParimutuelSettlementService#refund_all!` | S | TD-013 (wallet lock in BetPlacementService — do together) | Concurrent integration test: two simultaneous void/cashout/settlement requests on same wallet cannot both succeed; wallet balance non-negative after |
| CC-002 | Extract `Clob::OrderCancellationService` shared by web and admin cancel paths; move lifecycle guards into `OrderMatchingService` | M | None | Admin cancel integration test mirrors web cancel test including wallet assertions; `Order.lock.find` and `wallet.lock!` inside transaction in both callers |
| CC-003 | Add `direction: 'buy'` filter to `ClobSettlementHandler` Pass 2 (or switch to `NetPositionService`) | S | TD-018 (already planned — link to that task) | Regression test: player buys YES, sells all YES, YES wins, receives zero settlement payout; player who bought and held YES receives full payout |
| CC-004 | Fix `LmsrTradeService#upsert_position` race: use `upsert`/`find_or_create_by` with row lock | S | None | Concurrent LMSR trade test on same user/market/side does not raise `RecordNotUnique` and results in correct contract count |
| CC-005 | Restrict draft market visibility in `Web::MarketsController#index` to users with `market.read` permission | S | None | Integration test: player cannot see draft markets; moderator can; unauthenticated user cannot |
| CC-006 | Rewrite `ProfileController` P&L to use `LedgerEntry` aggregation (same approach as `LeaderboardController`) | M | TD-015 (fix `STAKE_TYPES`/`RETURN_TYPES` constants first) | Profile page shows correct net P&L for a player who has placed bets via all 4 mechanisms |
| CC-007 | Add pre-flight market-state guard in `Admin::OrdersController#create` (same checks as `Web::OrdersController`) | S | TD-020 (already planned — link to that task) | Integration tests: admin cannot place order on draft, closed, or settled CLOB market |
| CC-008 | Fix `CloseExpiredMarketsJob#system_actor` fallback: require an admin user; raise/alert if none exists | S | None | Test: job raises or logs a critical error when no admin exists, rather than falling back to `User.first` |
| CC-009 | Move Redis/SSE writes outside `ApplicationRecord.transaction` or add a post-commit hook | M | Architectural: ADR decision needed on eventual consistency tolerance | Test: Redis write does not occur when DB transaction rolls back due to validation failure |
