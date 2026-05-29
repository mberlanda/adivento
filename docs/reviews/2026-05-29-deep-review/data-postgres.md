# Data / Postgres Deep Review

## Scope

### Files / docs inspected

| Category | Files |
|----------|-------|
| Schema | `db/structure.sql` (full), `db/migrate/` (all 27 migrations) |
| Models | `app/models/wallet.rb`, `market.rb`, `order.rb`, `lmsr_position.rb`, `ledger_entry.rb`, `bet.rb` |
| Financial services | `bet_placement_service.rb`, `bet_void_service.rb`, `cashout_execution_service.rb`, `settlement_service.rb` |
| CLOB services | `clob/order_matching_service.rb`, `clob/net_position_service.rb`, `clob/clob_cashout_service.rb`, `clob/operator_buyback_service.rb` |
| LMSR services | `lmsr/lmsr_trade_service.rb`, `lmsr/lmsr_pricing_service.rb` |
| Parimutuel services | `parimutuel/parimutuel_pool_service.rb`, `parimutuel/parimutuel_settlement_service.rb` |
| Settlement handlers | `settlement/clob_settlement_handler.rb`, `settlement/lmsr_settlement_handler.rb` |
| Controllers | `backoffice/markets_controller.rb`, `web/orders_controller.rb`, `admin/orders_controller.rb`, `web/markets_controller.rb` |
| Docs | `docs/INDEX.md`, `.claude/tasks/ATTENTION.md`, `docs/wiki/tech-debt-backlog.md` |

### Explicitly out of scope

- Hot storage / Redis projection layer (`app/services/hot_storage/`)
- Auth / JWT / session token mechanics
- E2E test suite
- Deployment infrastructure, Dockerfile, CI yaml

---

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|
| P0 | `BetPlacementService` reads and tests `user.wallet` **outside** the transaction, then deducts inside it — classic TOCTOU double-spend | `bet_placement_service.rb:18-30`: `wallet = user.wallet` then `wallet.update!` inside `ApplicationRecord.transaction` with no `lock!` anywhere on wallet | TD-013: add `wallet = user.wallet.lock!` as the first statement inside the transaction block |
| P0 | `ClobSettlementHandler` pass 1 releases buy-order reservations with an **unlocked** wallet read (`w = order.user.wallet`) while pass 2 uses `wallet.lock!` — inconsistent within the same settlement loop | `settlement/clob_settlement_handler.rb:18` vs `:33` | Fix pass 1 to call `order.user.wallet.lock!` (same as pass 2) |
| P0 | `ParimutuelSettlementService#refund_all!` refunds wallets with no row lock (`w = entry.user.wallet`, no `lock!`) | `parimutuel/parimutuel_settlement_service.rb:74` — compare with `pay` path at line 37 which does call `.lock!` | Add `.lock!` to the refund path; pattern is already correct on the pay path in the same file |
| P0 | `BetVoidService` locks the bet row (`Bet.lock.find`) but then reads wallet without `lock!` | `bet_void_service.rb:11`: `wallet = locked_bet.user.wallet` — no `.lock!` | Add `.lock!` to wallet read; the bet-lock alone does not prevent two concurrent void+cashout from both crediting the same wallet |
| P0 | `CashoutExecutionService` same pattern: bet is locked but `wallet = locked_bet.user.wallet` at line 12 has no `lock!` | `cashout_execution_service.rb:12` | Add `.lock!` (consistent with `lmsr_trade_service.rb:48`) |
| P0 | `ClobSettlementHandler` pays **all** filled orders on the winning side regardless of `direction`, double-paying sell orders that already transferred contracts | `clob_settlement_handler.rb:29-38`: query has no `direction: 'buy'` filter; filled sell orders receive the same `payout = filled_quantity * 100` as buyers | TD-018: restrict payout query to `direction: 'buy'` (or use `NetPositionService`) |
| P1 | `index_orders_book` composite index does **not include `direction`**, so queries filtering by `direction` (`buy`/`sell`) inside `resting_for` must apply a filter on top of an index scan that already matched by `(market_id, side, price_cents, status)` — correct but a missed covering opportunity now that direction is a first-class filter | `db/structure.sql:1146`: `btree (market_id, side, price_cents, status)`; order matching queries always filter `direction` (`order_matching_service.rb:110-122`) | Add a new index `(market_id, side, direction, status, price_cents)` or update the existing one; direction was added in the latest migration (`20260529030007`) without updating the book index |
| P1 | `ledger_entries.metadata` is typed `json` (not `jsonb`) — the `->>` operator works on both types in PostgreSQL but **GIN indexing is not possible on `json`**, and parimutuel settlement performs a full-table JSON-text scan across ledger_entries filtered only by `entry_type` | `db/structure.sql:235`: `metadata json`; `parimutuel_settlement_service.rb:31-32`: `metadata->>'market_id'` with no index; same at line 72 | Migrate `metadata` columns (`ledger_entries`, `audit_events`) from `json` to `jsonb`; add a GIN index on `ledger_entries(metadata)` or a functional index on `(entry_type, (metadata->>'market_id'))` |
| P1 | `LmsrTradeService#upsert_position` uses `find_or_initialize_by` without a row lock; two concurrent trades by the same user on the same market+side will both read contracts=0, both write, and one update will be silently overwritten (lost-update) | `lmsr_trade_service.rb:97-101`: no `lock!` on the position record; the market is locked but that does not cover position row-level contention | Replace with `LmsrPosition.lock.find_or_create_by!(...)` and then `increment!(:contracts, quantity)`, or use `upsert` with `ON CONFLICT DO UPDATE` |
| P2 | No DB-level `CHECK` constraint guards wallet balances from going negative — only Active Record validations protect `available_minor >= 0` and `reserved_minor >= 0`; those validations are bypassed by `update_column`, `update_columns`, and any bulk SQL | `wallet.rb:5-6`; `db/structure.sql` has no `CHECK` on `wallets`; compare `orders_direction_valid` CHECK which does exist at DB level | Add `ALTER TABLE wallets ADD CONSTRAINT wallets_balances_non_negative CHECK (available_minor >= 0 AND reserved_minor >= 0)` |
| P2 | `orders.price_cents` has no DB-level `CHECK (price_cents BETWEEN 1 AND 99)`; the constraint is only in the Active Record model validator and can be bypassed | `db/structure.sql:431`: `price_cents integer NOT NULL` — no check constraint; `order.rb:11` has the validator | Add `CHECK (price_cents >= 1 AND price_cents <= 99)` and `CHECK (quantity > 0)` to `orders` |
| P2 | `markets.mechanism_type` is unconstrained at the DB level — any string is stored | `db/structure.sql:375`: `mechanism_type character varying DEFAULT 'fixed_odds'::character varying NOT NULL`; no `CHECK` against a list | Add `CHECK (mechanism_type IN ('fixed_odds','clob','lmsr','parimutuel'))` |
| P2 | `ledger_entries` has no composite index on `(user_id, entry_type)` — the leaderboard, profile P&L, and settlement queries filter on both columns, causing scans across all entries for a user | `db/structure.sql:1059,1066`: separate indexes on `entry_type` and `user_id`; no composite; used together in `parimutuel_settlement_service.rb:30-32` and leaderboard queries | Add `CREATE INDEX ON ledger_entries (user_id, entry_type)` |
| P2 | `markets.tags` is `json` instead of `jsonb`, preventing GIN indexing of tag membership; the current ILIKE cast-to-text workaround is a full sequential scan on tag text | `db/structure.sql:393`: `tags json`; `web/markets_controller.rb:19-24`: `CAST(tags AS TEXT) ILIKE ?` | Migrate `tags` to `jsonb`; add `GIN` index; use `@>` operator for membership queries |
| P3 | `ClobSettlementHandler` pass 1 iterates all open/partial orders with `find_each` and N+1 loads wallet for each order (`order.user.wallet`) rather than batch-loading or issuing a single UPDATE | `clob_settlement_handler.rb:11-25`: no `includes(user: :wallet)`; each iteration fires two SELECTs + one UPDATE | Add `includes(user: :wallet)` or refactor to a bulk `UPDATE` with a subquery for the common case |
| P3 | `audit_events.metadata` is `json` rather than `jsonb`; `lmsr_settlement_handler.rb` uses `positions_from_ledger` which iterates all `lmsr_trade.place` audit events in-memory and casts `metadata['quantity']` — this is a Ruby-side aggregation on an unindexed JSON column | `lmsr_settlement_handler.rb:29-35`; `audit_events.metadata json` in `db/structure.sql:53` | Migrate `audit_events.metadata` to `jsonb`; if `positions_from_ledger` is used as a reconciliation path, consider a DB-side aggregation |
| P3 | `lmsr_b_parameter` is stored as `double precision` (IEEE 754 float); cumulative floating-point drift from repeated reads/writes is acceptable for pricing math but should be documented as a known precision limitation | `db/structure.sql:386`; `lmsr_trade_service.rb:33`: `raw_cost_minor = (raw_cost * 100).round` rounds to integer correctly, mitigating drift in the financial ledger | Document as known limitation; no immediate change required |

---

## Detailed Notes

### 1. Wallet-lock consistency (P0 cluster)

The codebase applies `wallet.lock!` correctly in `LmsrTradeService`, `ParimutuelPoolService`, and the CLOB order-matching fill paths. However, four services are inconsistent:

- **`BetPlacementService`** (`bet_placement_service.rb:18`): `wallet = user.wallet` is called *before* `ApplicationRecord.transaction do`, so the balance check at line 19 (`wallet.available_minor < stake_minor.to_i`) uses a snapshot that is not protected by any lock. Two concurrent requests will both pass the check and both debit.
- **`BetVoidService`** (`bet_void_service.rb:11`): The bet is correctly locked (`Bet.lock.find`) but the associated wallet is not. A concurrent cashout on the same bet would also load the same unlocked wallet and both credit it.
- **`CashoutExecutionService`** (`cashout_execution_service.rb:12`): Identical pattern to `BetVoidService`.
- **`ClobSettlementHandler` pass 1** (`clob_settlement_handler.rb:18`): Releases `reserved_minor` from an unlocked wallet. If two settlement calls could race (unlikely via UI but possible via admin API bugs), both would read the same `reserved_minor` and the double-release would push `reserved_minor` negative (bypassing the AR validator because `update!` doesn't re-validate against the DB-committed value).

Also: `ParimutuelSettlementService#refund_all!` (`parimutuel_settlement_service.rb:74`) uses `entry.user.wallet` without `lock!`, while the same service's primary `call` path at line 37 correctly calls `.lock!`. This is a divergence within the same file.

**Fix pattern**: Replace unlocked `user.wallet` with `user.wallet.lock!` as the first statement inside the `ApplicationRecord.transaction` block.

### 2. CLOB settlement overpay (P0 / TD-018)

`ClobSettlementHandler` pass 2 (`clob_settlement_handler.rb:29-38`):

```ruby
@market.orders.where(side: @winning_side).where.not(filled_quantity: 0).find_each do |order|
  payout = order.filled_quantity * 100
  ...
  LedgerEntry.create!(entry_type: 'SETTLEMENT_WIN', direction: 'credit', amount_minor: payout)
end
```

There is no filter on `direction`. A user who bought 10 YES contracts and later sold all 10 via a `direction: 'sell'` order will have `filled_quantity: 10` on the sell order. Settlement credits them `10 * 100 = 1000` again, even though they already received cash for those contracts when the sell order filled. The original buyer who took the other side of that sell also receives `1000`. Total payout for those 10 contracts is `3000` instead of `1000`.

**Fix**: Add `direction: 'buy'` to the pass 2 filter, OR use `NetPositionService` to compute net long position per user and credit only that. The latter is cleaner and handles partial sells.

### 3. Order-book index does not include `direction` (P1)

The `index_orders_book` (`market_id, side, price_cents, status`) was created before the `direction` column existed. Order matching now issues queries of the form:

```ruby
.where(side: incoming.side, direction: 'buy', status: %w[open partial])
.order(price_cents: :desc, created_at: :asc)
```

The index can narrow to `market_id + side + status` but must then filter `direction` via a heap scan, re-sort by `price_cents`, and does not cover `created_at`. The query is correct but not optimal. A revised index `(market_id, side, direction, status, price_cents, created_at)` would allow index-only scans on the hot matching path. Alternatively, replace `index_orders_book` with `(market_id, side, direction, price_cents, status)` — same leading columns, direction added before price — to support the new sell-order matching queries.

### 4. `json` vs `jsonb` for metadata and tags (P1/P2)

All `metadata` columns (`ledger_entries`, `audit_events`) and `markets.tags` use `json`, not `jsonb`. Consequences:

- **No GIN indexing possible** on `json` columns; PostgreSQL requires `jsonb` for `CREATE INDEX USING gin`.
- `ParimutuelSettlementService` performs `metadata->>'market_id'` filter on the entire `ledger_entries` table; the only available index is on `entry_type`. On a market with thousands of parimutuel stakers this becomes O(all PARIMUTUEL_STAKE entries) with a text cast.
- `Web::MarketsController` does `CAST(tags AS TEXT) ILIKE ?` — effectively a sequential scan of the tags JSON column converted to a string.
- `json` preserves duplicate keys and insertion order; `jsonb` normalises and is generally more efficient to traverse.

**Fix**: A single migration: `ALTER TABLE ledger_entries ALTER COLUMN metadata TYPE jsonb USING metadata::jsonb` (and same for `audit_events.metadata`, `markets.tags`). Then add `CREATE INDEX CONCURRENTLY ON ledger_entries USING gin(metadata)` and `CREATE INDEX CONCURRENTLY ON markets USING gin(tags)`.

### 5. LMSR position upsert is not atomic (P1)

`LmsrTradeService#upsert_position` calls `find_or_initialize_by` without holding a row lock on the position, then increments and saves. The outer `@market.lock!` prevents two trades from computing different costs simultaneously, but it does not cover the position row — the market row and the position row are different tables.

In practice, concurrent LMSR trades on the same market by different users are serialised by the market-level `FOR UPDATE` lock, so **inter-user concurrency is actually safe**. However, if ever the market lock is removed or a background job accesses positions directly, the lost-update window opens.

The immediate issue is that `find_or_initialize_by` can race at first insert: two concurrent calls for the same `(user, market, side)` that both find no existing row will both `build` a new record and both try to `save!`. The unique index `index_lmsr_positions_on_user_market_side` will cause one to raise `ActiveRecord::RecordNotUnique`. This is caught by the outer `rescue StandardError` and returns a failed result — a silent data loss.

**Fix**: Use `insert` with `on_conflict: :update` (`upsert`), or rescue `RecordNotUnique` and retry, or use `LmsrPosition.lock.find_or_create_by!(...)` then `increment!(:contracts, quantity)`.

### 6. Missing DB-level wallet balance constraints (P2)

`wallets.available_minor` and `wallets.reserved_minor` have Active Record validations (`>= 0`) but no DB `CHECK` constraint. Any raw SQL, `update_column`, or `update_columns` bypass the AR layer. The codebase already uses `update_columns` in `lmsr_trade_service.rb` (on markets, not wallets, so not directly the issue) but the pattern shows that column-level bypasses are in use. A negative `available_minor` would allow a player to place bets with funds they do not have.

Compare with `orders_direction_valid` which is correctly enforced at the DB level (`CHECK (direction IN ('buy','sell'))`).

### 7. Missing DB-level check constraints on `orders` and `markets` (P2)

- `orders.price_cents` is validated in the model (`1..99`) but has no `CHECK (price_cents BETWEEN 1 AND 99)` in the DB.
- `orders.quantity` is validated as `> 0` but has no `CHECK (quantity > 0)`.
- `markets.mechanism_type` is validated by AR inclusion but has no DB `CHECK` against the four allowed values.

These matter when seeds, admin scripts, or future services bypass the model layer.

### 8. `ledger_entries` composite index gap (P2)

The three hottest query patterns on `ledger_entries` all filter on `(user_id, entry_type)`:

- Profile P&L aggregation
- Leaderboard `RETURN_TYPES`/`STAKE_TYPES` sums
- Parimutuel settlement (`entry_type = 'PARIMUTUEL_STAKE' AND metadata->>'market_id' = ?`)

The current separate indexes on `user_id` and `entry_type` force PostgreSQL to choose one and filter via heap for the other. A composite `(user_id, entry_type)` index would make these queries index-seekable.

---

## Open Questions

1. **CLOB net-position settlement (TD-018 fix scope)**: Should `ClobSettlementHandler` settle based on net positions (via `NetPositionService`) or simply restrict payout to `direction: 'buy'` orders? The net-position approach is semantically correct for partial sells; the simple filter is correct only for full-sell exits.

2. **`json` → `jsonb` migration safety**: The `->>` operator is identical for both types; all existing queries will continue to work. But the migration requires a full table rewrite (not instant on large tables). Is a migration window acceptable for the current dataset size?

3. **Mechanism-type DB constraint**: If `mechanism_type` gains a fifth value in the future, a DB `CHECK` constraint requires a migration. Is that lifecycle constraint acceptable for a POC?

4. **Order book index replacement vs addition**: Replacing `index_orders_book` requires a migration that drops and recreates the index (not instant). Adding a new index alongside it wastes storage. What is the preferred tradeoff?

---

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|---------------|------|------|--------------|-----------------|
| DB-001 | Add `wallet.lock!` inside transaction in `BetPlacementService`, `BetVoidService`, `CashoutExecutionService`, `ClobSettlementHandler` pass 1, and `ParimutuelSettlementService#refund_all!` | S (< 1 day) | None | Concurrent-request test: two simultaneous bet placements on an account with exactly enough balance; one must be rejected |
| DB-002 | Fix `ClobSettlementHandler` to restrict pass 2 payout to `direction: 'buy'` or use `NetPositionService` | S | TD-018 (already identified) | Regression test: buy 10 YES, sell 10 YES, settle YES → player receives zero settlement payout |
| DB-003 | Add DB CHECK constraints on `wallets (available_minor >= 0, reserved_minor >= 0)`, `orders (price_cents BETWEEN 1 AND 99, quantity > 0)`, `markets (mechanism_type IN (...))` | S | None | Migration applies; `rake db:migrate` succeeds; existing valid data passes |
| DB-004 | Migrate `ledger_entries.metadata`, `audit_events.metadata`, and `markets.tags` from `json` to `jsonb`; add GIN index on `ledger_entries(metadata)` and `markets(tags)` | M (migration + review) | None | `EXPLAIN ANALYZE` on parimutuel settlement query shows Index Scan instead of Seq Scan |
| DB-005 | Update or replace `index_orders_book` to include `direction` as a leading column after `side` | S | DB-004 optional | `EXPLAIN ANALYZE` on `resting_for` queries shows Index Only Scan |
| DB-006 | Add composite index `CREATE INDEX ON ledger_entries (user_id, entry_type)` | XS | None | `EXPLAIN ANALYZE` on leaderboard query shows index seek |
| DB-007 | Fix `LmsrTradeService#upsert_position` to be atomic under concurrent inserts (use `upsert` with `ON CONFLICT DO UPDATE`, or rescue `RecordNotUnique` + retry) | S | None | Concurrent LMSR trade test does not raise `RecordNotUnique`; contract total is correct |
