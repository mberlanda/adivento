# CLOB Order Book Completion Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-27-clob-order-book.md -->

**Goal:** Complete the CLOB order book feature per the spec: add per-fill ledger entries, enrich the order book response with last trade price and spread, and expose CLOB contract positions in the web positions endpoint.

**Architecture:** 3 PRs targeting `main`. PR 1 is pure service-layer (no migration). PR 2 adds a single nullable column. PR 3 extends an existing controller. Each PR is independently deployable.

**Spec:** [docs/specs/2026-05-27-clob-order-book.md](../../specs/2026-05-27-clob-order-book.md)

---

## PR 1 — CLOB Ledger Completeness

**Files:**
- Modify: `app/services/clob/order_matching_service.rb`
- Modify: `app/services/settlement/clob_settlement_handler.rb`
- Modify: `test/integration/web_orders_test.rb` (or service test)

### Task 1.1: Add ORDER_FILL_STAKE + ORDER_FILL_CREDIT ledger entries

Per fill in `execute_fill!`, write two ledger entries:
- `ORDER_FILL_STAKE` debit for taker: `amount_minor = taker.price_cents * qty`
- `ORDER_FILL_CREDIT` credit for maker: `amount_minor = maker.price_cents * qty`

Both entries get `metadata: { market_id: market_id, fill_price: price, fill_qty: qty }`.

- [ ] **Step 1.1.1:** Add ledger entries in `execute_fill!` after order status updates, before fee write

```ruby
# in execute_fill!, after updating taker/maker order statuses
LedgerEntry.create!(
  user: taker.user, actor: taker.user,
  entry_type: 'ORDER_FILL_STAKE', direction: 'debit',
  amount_minor: taker_stake,
  metadata: { market_id: @market.id, fill_price: price, fill_qty: qty }
)
LedgerEntry.create!(
  user: maker.user, actor: maker.user,
  entry_type: 'ORDER_FILL_CREDIT', direction: 'credit',
  amount_minor: maker_stake,
  metadata: { market_id: @market.id, fill_price: price, fill_qty: qty }
)
```

- [ ] **Step 1.1.2:** Add `wallet.lock!` in `ClobSettlementHandler` pass 2

```ruby
# pass 2 — change:  w = order.user.wallet
# to:               w = order.user.wallet.lock!
```

- [ ] **Step 1.1.3:** Run full suite

```bash
bin/rails test
```
Expected: 0 failures, ≥90% coverage.

- [ ] **Step 1.1.4:** Commit

```bash
git add app/services/clob/order_matching_service.rb app/services/settlement/clob_settlement_handler.rb
git commit -m "feat(clob): add ORDER_FILL_STAKE and ORDER_FILL_CREDIT ledger entries per fill"
```

---

## PR 2 — Order Book Enrichment + Docs

**Files:**
- Create: `db/migrate/20260527100006_add_last_fill_price_cents_to_markets.rb`
- Modify: `db/schema.rb` (auto-updated)
- Modify: `app/services/clob/order_matching_service.rb`
- Modify: `app/controllers/web/order_books_controller.rb`
- Rename+commit: `docs/adr/ADR-0013-clob-order-book-migration.md` → `docs/adr/ADR-0014-clob-order-book-migration.md`
- Commit: `docs/specs/2026-05-27-clob-order-book.md` (currently untracked)
- Modify: `docs/INDEX.md`

### Task 2.1: Migration for last_fill_price_cents

- [ ] **Step 2.1.1:** Create migration

```ruby
# db/migrate/20260527100006_add_last_fill_price_cents_to_markets.rb
class AddLastFillPriceCentsToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :last_fill_price_cents, :integer
  end
end
```

- [ ] **Step 2.1.2:** Run migration

```bash
bin/rails db:migrate
```

- [ ] **Step 2.1.3:** Update `execute_fill!` to set `@market.last_fill_price_cents` after each fill

```ruby
# after order status updates and ledger entries, inside execute_fill!:
@market.update_columns(last_fill_price_cents: price, updated_at: Time.current)
```

### Task 2.2: Enrich order book controller response

- [ ] **Step 2.2.1:** Add `last_trade_price` and `spread` to order books controller response

```ruby
# in show action:
spread = book[:bid] && book[:ask] ? book[:ask] - (100 - book[:bid]) : nil

render json: {
  market_id: market.id,
  best_bid: book[:bid],
  best_ask: book[:ask],
  last_trade_price: market.last_fill_price_cents,
  spread: spread,
  bids: bids,
  asks: asks
}
```

- [ ] **Step 2.2.2:** Run full suite

```bash
bin/rails test
```
Expected: 0 failures.

- [ ] **Step 2.2.3:** Commit migration + service + controller

```bash
git add db/migrate/20260527100006_add_last_fill_price_cents_to_markets.rb db/schema.rb \
        app/services/clob/order_matching_service.rb \
        app/controllers/web/order_books_controller.rb
git commit -m "feat(clob): track last fill price, add last_trade_price and spread to order book response"
```

### Task 2.3: Commit ADR-0014 and spec

- [ ] **Step 2.3.1:** Rename ADR file from 0013 to 0014

```bash
git mv docs/adr/ADR-0013-clob-order-book-migration.md docs/adr/ADR-0014-clob-order-book-migration.md
# Update status in file: Proposed → Accepted
```

- [ ] **Step 2.3.2:** Update ADR-0014 status to "Accepted", add ADR-0014 row to INDEX.md

- [ ] **Step 2.3.3:** Commit ADR + spec + INDEX

```bash
git add docs/adr/ADR-0014-clob-order-book-migration.md docs/specs/2026-05-27-clob-order-book.md docs/INDEX.md
git commit -m "docs: add ADR-0014 (CLOB order book migration) and CLOB order book spec"
```

---

## PR 3 — CLOB Positions Endpoint

**Files:**
- Modify: `app/controllers/web/positions_controller.rb`
- Modify: `test/integration/web_positions_test.rb` (or create)

### Task 3.1: Extend positions index to include CLOB holdings

CLOB position: for each market where the user has filled orders, return net contract counts and estimated value.

- [ ] **Step 3.1.1:** Add `clob_positions` to the positions response

```ruby
# in PositionsController#index:
clob_positions = Order
  .where(user_id: current_user.id)
  .where('filled_quantity > 0')
  .joins(:market)
  .where(markets: { mechanism_type: 'clob' })
  .group(:market_id)
  .select('market_id, side, sum(filled_quantity) as total_qty, sum(price_cents * filled_quantity) as weighted_price_sum')
  .to_a

# group by market_id to get yes/no breakdown
positions_by_market = clob_positions.group_by(&:market_id)
clob_position_list = positions_by_market.map do |mkt_id, rows|
  market = Market.find(mkt_id)
  yes_row = rows.find { |r| r.side == 'YES' }
  no_row  = rows.find { |r| r.side == 'NO' }
  yes_qty  = yes_row&.total_qty.to_i
  no_qty   = no_row&.total_qty.to_i
  avg_yes  = yes_qty > 0 ? (yes_row.weighted_price_sum.to_f / yes_qty).round : nil
  book = market.pricing_engine.order_book_summary
  current_yes_price = book[:bid]
  unrealised = current_yes_price ? yes_qty * current_yes_price : nil
  {
    market_id: mkt_id,
    market_question: market.question,
    yes_contracts: yes_qty,
    no_contracts: no_qty,
    avg_yes_price_cents: avg_yes,
    unrealised_value_minor: unrealised
  }
end.reject { |p| p[:yes_contracts].zero? && p[:no_contracts].zero? }

render json: { positions: bets.map { |b| serialize_position(b) }, clob_positions: clob_position_list }
```

- [ ] **Step 3.1.2:** Run full suite

```bash
bin/rails test
```
Expected: 0 failures, ≥90% coverage.

- [ ] **Step 3.1.3:** Commit

```bash
git add app/controllers/web/positions_controller.rb test/integration/web_positions_test.rb
git commit -m "feat(clob): add CLOB contract positions to web positions endpoint"
```

---

## Task N: Update docs

- [ ] Append entry to `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` implementation status
- [ ] Commit: `docs: update INDEX and WORK_LOG after clob-order-book`

---

## Self-Review Checklist
- [ ] Every spec invariant has a test
- [ ] ORDER_FILL_STAKE and ORDER_FILL_CREDIT written for every fill
- [ ] wallet.lock! used before every wallet mutation in settlement
- [ ] Full test suite passes: `bin/rails test`
- [ ] ADR-0014 committed and accepted
- [ ] No placeholder steps remain
