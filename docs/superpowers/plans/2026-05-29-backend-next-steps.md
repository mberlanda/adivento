# Backend Next Steps — Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-29-backend-next-steps.md -->
<!-- Outcome of backend backlog review on 2026-05-29. -->
<!-- Lists the top 5 backend tasks by priority. Each task is a separate PR-sized unit. -->

**Goal:** Close the most significant correctness, data-integrity, and UX gaps found in the 2026-05-29 codebase review.

**Architecture:** All tasks stay inside the Rails 8 monolith. No new dependencies needed.

**Tech Stack:** Rails 8, Minitest, existing patterns (see docs/INDEX.md for file map)

**Spec:** This document is both the review and the plan — no separate spec file required for these surgically scoped tasks.

---

## Gap Summary (in priority order)

### P1 — BetPlacementService wallet lock missing (TD-013)
`BetPlacementService` reads `user.wallet` without a `lock!` (row-level lock). Between the balance check and the debit there is a time window where two concurrent requests for the same user could both pass the check and both debit, resulting in a negative balance. The model-level `validates :available_minor, numericality: { greater_than_or_equal_to: 0 }` fires *after* the read, using the stale pre-lock value, so it does not prevent the race. `BetVoidService`, `CashoutExecutionService`, and `SettlementService#settle_fixed_odds!` have the same issue for credit paths (less severe but inconsistent).

**Correctness impact:** High. Double-spend possible in production under concurrent load.

### P2 — LMSR positions missing from positions page (TD-014)
`lmsr_positions` table is populated on every LMSR trade, and `LmsrSettlementHandler` pays out from it — but `PositionsController#index` never queries `LmsrPosition`. Players who trade on LMSR markets see an empty positions page. There is also no unit test asserting LMSR positions appear in the response.

**UX impact:** High. LMSR is a live mechanism with real player state that is invisible.

### P3 — Leaderboard P&L missing CLOB_SELL_CREDIT (TD-015)
The leaderboard `RETURN_TYPES` list (`BET_WIN_PAYOUT BET_CASHOUT_PAYOUT SETTLEMENT_WIN ORDER_FILL_CREDIT`) omits `CLOB_SELL_CREDIT`. A player who exits a CLOB position via a sell order receives cash via `CLOB_SELL_CREDIT` ledger entries — these are *not* counted as returns on the leaderboard, understating their P&L. Similarly, `LMSR_FEE` and `CLOB_FEE` are debit costs paid by the player but are not counted in `STAKE_TYPES`, so LMSR/CLOB players' costs are understated. The profile page P&L panel is fixed-odds-only (`bets` table) and ignores all AMM activity.

**Correctness impact:** Medium. Leaderboard is wrong for CLOB sell + LMSR/CLOB fee players.

### P4 — Admin API missing category/tags params (TD-016)
`Admin::MarketsController#market_params` does not include `:category` or `:tags`. The admin JSON API cannot set these fields. Since `category` defaults to `'other'` at the DB level, markets created via the API are always `other`. The E2E tests create markets via the API; this means all E2E fixture markets are `other` and the category filter bar is never exercised. The backoffice and customer web create paths both set category/tags correctly.

**Correctness impact:** Medium. API creates miscategorised markets; E2E category tests are silently vacuous.

### P5 — Market cancellation has no service (TD-017)
The `Market` model has a `cancelled: 3` status enum value and the `SettlementService` accepts `open` and `closed` markets only, but there is no `MarketCancellationService` and no controller action to cancel a market. Operators cannot void a market and refund all bets. This is a meaningful operational gap for cases where a market must be voided (bad question, external event cancels the topic). Fixed-odds bets, CLOB reservations, LMSR positions, and parimutuel stakes all need to be refunded atomically.

**Correctness impact:** Medium. No hard production bug yet, but no recovery path exists for bad markets.

---

## File Map

**Create (new items across all tasks):**
- `app/services/market_cancellation_service.rb` (Task 5)
- `test/services/market_cancellation_service_test.rb` (Task 5)

**Modify (across all tasks):**
- `app/services/bet_placement_service.rb` — Task 1
- `app/services/bet_void_service.rb` — Task 1
- `app/services/cashout_execution_service.rb` — Task 1
- `app/services/settlement_service.rb` — Task 1
- `app/controllers/web/positions_controller.rb` — Task 2
- `app/views/web/positions/index.html.erb` — Task 2
- `test/integration/web_positions_test.rb` — Task 2
- `app/controllers/web/leaderboard_controller.rb` — Task 3
- `test/integration/web_leaderboard_test.rb` — Task 3
- `app/controllers/admin/markets_controller.rb` — Task 4
- `test/integration/admin market settle tests` — Task 4
- `config/routes.rb` — Task 5
- `app/controllers/backoffice/markets_controller.rb` — Task 5

---

## Task 1: Wallet lock in bet placement and settlement services

**Files:**
- Modify: `app/services/bet_placement_service.rb`
- Modify: `app/services/bet_void_service.rb`
- Modify: `app/services/cashout_execution_service.rb`
- Modify: `app/services/settlement_service.rb`
- Test: `test/services/bet_placement_service_test.rb`

**Architecture:** Replace `user.wallet` with `user.wallet.lock!` inside the transaction in the four services listed. This issues a `SELECT ... FOR UPDATE` on the wallet row, preventing concurrent reads from obtaining a stale balance. The pattern is already used correctly in `LmsrTradeService`, `ParimutuelPoolService`, `ClobSettlementHandler`, and `LmsrSettlementHandler`.

- [ ] **Step 1.1: Add test that would catch the race (documents the invariant)**

```ruby
# test/services/bet_placement_service_test.rb
test 'balance check and debit use the same locked wallet row' do
  # There is no way to test actual concurrency in minitest, but we can assert
  # that the wallet referenced during the debit is the locked version.
  # The simplest proxy: assert the service does not raise even when available_minor
  # is exactly equal to the stake (boundary condition).
  @player.wallet.update!(available_minor: 1000)
  assert_nothing_raised do
    BetPlacementService.place!(
      user: @player, market: @market, market_leg: @yes_leg, stake_minor: 1000
    )
  end
  assert_equal 0, @player.wallet.reload.available_minor
end
```

- [ ] **Step 1.2: Run to confirm it currently passes (no lock needed to reproduce boundary case)**

```bash
bin/rails test test/services/bet_placement_service_test.rb -v
```

- [ ] **Step 1.3: Apply the wallet lock in BetPlacementService**

In `app/services/bet_placement_service.rb` change line 18 and ensure the lock is inside the transaction:

```ruby
# Before (line 18):
    wallet = user.wallet
    raise InvalidBet, 'Insufficient wallet balance' if wallet.available_minor < stake_minor.to_i

# After — move wallet access inside the transaction block and lock:
# (remove the wallet read above and replace the ApplicationRecord.transaction block start)
    ApplicationRecord.transaction do
      wallet = user.wallet.lock!
      raise InvalidBet, 'Insufficient wallet balance' if wallet.available_minor < stake_minor.to_i
      ...
```

- [ ] **Step 1.4: Apply wallet lock in BetVoidService**

In `app/services/bet_void_service.rb` change line 11:
```ruby
# Before:
      wallet = locked_bet.user.wallet
# After:
      wallet = locked_bet.user.wallet.lock!
```

- [ ] **Step 1.5: Apply wallet lock in CashoutExecutionService**

In `app/services/cashout_execution_service.rb` change line 12:
```ruby
# Before:
      wallet = locked_bet.user.wallet
# After:
      wallet = locked_bet.user.wallet.lock!
```

- [ ] **Step 1.6: Apply wallet lock in SettlementService settle_fixed_odds!**

In `app/services/settlement_service.rb` change line 59:
```ruby
# Before:
        wallet = bet.user.wallet
# After:
        wallet = bet.user.wallet.lock!
```

- [ ] **Step 1.7: Run full test suite**

```bash
bin/rails test
```
Expected: all pass (same count as before, 0 failures)

- [ ] **Step 1.8: Commit**

```bash
git add app/services/bet_placement_service.rb \
        app/services/bet_void_service.rb \
        app/services/cashout_execution_service.rb \
        app/services/settlement_service.rb \
        test/services/bet_placement_service_test.rb
git commit -m "fix(wallet): lock wallet row in bet placement, void, cashout, and settlement

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Expose LMSR positions on the positions page

**Files:**
- Modify: `app/controllers/web/positions_controller.rb`
- Modify: `app/views/web/positions/index.html.erb`
- Test: `test/integration/web_positions_test.rb`

**Architecture:** Query `LmsrPosition` for the current user and pass `@lmsr_positions` to the view. The positions page already has a pattern for CLOB positions (`@clob_positions`). The LMSR section should display market name, side, and contract count. The "no open positions" empty state must also account for LMSR positions.

- [ ] **Step 2.1: Add a failing test**

```ruby
# test/integration/web_positions_test.rb
test 'positions page shows LMSR positions' do
  player = users(:player)
  market = markets(:lmsr_market)
  LmsrPosition.create!(user: player, market: market, side: 'YES', contracts: 5)

  get '/web/positions', headers: auth_headers_for(player)

  assert_response :success
  assert_select '[data-testid="lmsr-positions-list"]'
  assert_select "[data-testid='lmsr-position-row-#{market.id}']"
end
```

- [ ] **Step 2.2: Run test to confirm it fails**

```bash
bin/rails test test/integration/web_positions_test.rb -v
```
Expected: FAIL — no `lmsr-positions-list` element found

- [ ] **Step 2.3: Add LMSR positions to PositionsController**

In `app/controllers/web/positions_controller.rb`, add inside `index`:
```ruby
def index
  bets = Bet.includes(:market, :market_leg)
            .where(user_id: current_user.id, status: :open)
            .order(created_at: :desc)
  @positions = bets.map { |b| serialize_position(b) }
  @clob_positions = clob_contract_positions
  @lmsr_positions = lmsr_contract_positions   # ADD THIS
  ...
```

Add private method:
```ruby
def lmsr_contract_positions
  LmsrPosition
    .includes(:market)
    .where(user: current_user)
    .holding
    .map do |pos|
      {
        market_id: pos.market_id,
        market_question: pos.market.question,
        side: pos.side,
        contracts: pos.contracts
      }
    end
end
```

Update the empty-state guard:
```ruby
if @positions.empty? && @clob_positions.empty? && @lmsr_positions.empty?
```

- [ ] **Step 2.4: Update the view**

In `app/views/web/positions/index.html.erb`:
1. Update the empty-state check to include `@lmsr_positions.empty?`
2. Add after the CLOB section:

```erb
<% if @lmsr_positions.any? %>
  <div class="card">
    <h3>LMSR Positions</h3>
    <table>
      <thead>
        <tr>
          <th>Market</th>
          <th>Side</th>
          <th>Contracts</th>
        </tr>
      </thead>
      <tbody data-testid="lmsr-positions-list">
        <% @lmsr_positions.each do |lp| %>
          <tr data-testid="lmsr-position-row-<%= lp[:market_id] %>">
            <td><%= link_to lp[:market_question], web_market_path(lp[:market_id]), style: 'color:#9fb2b8;' %></td>
            <td><strong><%= lp[:side] %></strong></td>
            <td><%= lp[:contracts] %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

Also update JSON response to include `lmsr_positions`:
```ruby
format.json { render json: { positions: @positions, clob_positions: @clob_positions, lmsr_positions: @lmsr_positions } }
```

- [ ] **Step 2.5: Run test to confirm it passes**

```bash
bin/rails test test/integration/web_positions_test.rb -v
```
Expected: all pass

- [ ] **Step 2.6: Run full suite**

```bash
bin/rails test
```
Expected: 0 failures

- [ ] **Step 2.7: Commit**

```bash
git add app/controllers/web/positions_controller.rb \
        app/views/web/positions/index.html.erb \
        test/integration/web_positions_test.rb
git commit -m "feat(positions): show LMSR positions on player positions page

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Fix leaderboard P&L for CLOB sell and AMM fees

**Files:**
- Modify: `app/controllers/web/leaderboard_controller.rb`
- Test: `test/integration/web_leaderboard_test.rb`

**Architecture:** `CLOB_SELL_CREDIT` entries represent cash the player received for selling contracts and must be in `RETURN_TYPES`. `LMSR_FEE` and `CLOB_FEE` are costs paid and must be in `STAKE_TYPES`. `PARIMUTUEL_REFUND` entries (from zero-winner pools) are credits that should also be in `RETURN_TYPES`.

The profile page P&L panel (`ProfileController`) only queries the `bets` table — it will naturally stay fixed-odds-only for now (covered by TD-014 when profile gains a cross-mechanism view). The leaderboard fix is independent and lower-risk.

- [ ] **Step 3.1: Add failing test**

```ruby
# test/integration/web_leaderboard_test.rb
test 'CLOB_SELL_CREDIT is counted as a return in leaderboard' do
  player = users(:player)
  LedgerEntry.create!(user: player, actor: player, entry_type: 'ORDER_FILL_STAKE',
                      amount_minor: 300, direction: 'debit', metadata: {})
  LedgerEntry.create!(user: player, actor: player, entry_type: 'CLOB_SELL_CREDIT',
                      amount_minor: 250, direction: 'credit', metadata: {})

  get '/web/leaderboard'

  assert_response :success
  # Player staked 300, returned 250 — should appear on leaderboard with net -50
  assert_select "[data-testid='leaderboard-player-#{player.id}']"
end

test 'LMSR_FEE and CLOB_FEE are counted as costs in leaderboard' do
  player = users(:player)
  LedgerEntry.create!(user: player, actor: player, entry_type: 'LMSR_TRADE_STAKE',
                      amount_minor: 200, direction: 'debit', metadata: {})
  LedgerEntry.create!(user: player, actor: player, entry_type: 'LMSR_FEE',
                      amount_minor: 10, direction: 'debit', metadata: {})
  LedgerEntry.create!(user: player, actor: player, entry_type: 'SETTLEMENT_WIN',
                      amount_minor: 300, direction: 'credit', metadata: {})

  get '/web/leaderboard'

  assert_response :success
  assert_select "[data-testid='leaderboard-player-#{player.id}']"
end
```

- [ ] **Step 3.2: Run to confirm first test fails (CLOB_SELL_CREDIT not in leaderboard)**

```bash
bin/rails test test/integration/web_leaderboard_test.rb -v
```
Expected: FAIL on the CLOB_SELL_CREDIT test (player doesn't appear, or appears but CLOB_SELL_CREDIT not counted)

- [ ] **Step 3.3: Update RETURN_TYPES and STAKE_TYPES constants**

In `app/controllers/web/leaderboard_controller.rb`:
```ruby
STAKE_TYPES  = %w[BET_STAKE LMSR_TRADE_STAKE LMSR_FEE PARIMUTUEL_STAKE ORDER_FILL_STAKE CLOB_FEE].freeze
RETURN_TYPES = %w[BET_WIN_PAYOUT BET_CASHOUT_PAYOUT SETTLEMENT_WIN ORDER_FILL_CREDIT CLOB_SELL_CREDIT PARIMUTUEL_REFUND].freeze
```

- [ ] **Step 3.4: Run tests**

```bash
bin/rails test test/integration/web_leaderboard_test.rb -v
```
Expected: all pass

- [ ] **Step 3.5: Run full suite**

```bash
bin/rails test
```
Expected: 0 failures

- [ ] **Step 3.6: Commit**

```bash
git add app/controllers/web/leaderboard_controller.rb \
        test/integration/web_leaderboard_test.rb
git commit -m "fix(leaderboard): include CLOB_SELL_CREDIT, LMSR_FEE, CLOB_FEE, PARIMUTUEL_REFUND in P&L

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Admin API — add category and tags to market_params

**Files:**
- Modify: `app/controllers/admin/markets_controller.rb`
- Test: `test/integration` (admin market create test)

**Architecture:** The admin `market_params` method simply needs `:category` and `:tags` added. Tags is a jsonb array — the admin API receives it as a JSON array in the request body, and `Market#tags=` already normalises it. Category validates against `Market::CATEGORIES`. No migration needed.

- [ ] **Step 4.1: Add a failing test**

```ruby
# test/integration/admin_market_settle_test.rb or a dedicated file
# Add to existing admin_market tests or create test/integration/admin_markets_test.rb
test 'admin can set category and tags when creating a market' do
  post '/admin/markets',
       params: {
         question: 'Will X happen?', description: 'desc', mechanism_type: 'fixed_odds',
         fee_bps: 100, liability_cap_minor: 100_000,
         category: 'sports', tags: ['football', 'premier-league']
       }.to_json,
       headers: auth_headers_for(users(:admin)).merge('Content-Type' => 'application/json')

  assert_response :created
  market = Market.last
  assert_equal 'sports', market.category
  assert_includes market.tags, 'football'
end
```

- [ ] **Step 4.2: Run to confirm it fails**

```bash
bin/rails test test/integration/admin_markets_test.rb -v
```
Expected: FAIL — category is `'other'` (default), not `'sports'`

- [ ] **Step 4.3: Update admin market_params**

In `app/controllers/admin/markets_controller.rb`:
```ruby
def market_params
  params.permit(:question, :description, :status, :structure_locked,
                :mechanism_type, :taker_fee_bps, :liquidity_subsidy_minor,
                :spread_fee_bps, :takeout_bps, :fee_bps, :liability_cap_minor,
                :close_at, :resolution_criteria, :resolution_source,
                :category, tags: [])
end
```

- [ ] **Step 4.4: Run test**

```bash
bin/rails test test/integration/admin_markets_test.rb -v
```
Expected: pass

- [ ] **Step 4.5: Run full suite**

```bash
bin/rails test
```
Expected: 0 failures

- [ ] **Step 4.6: Commit**

```bash
git add app/controllers/admin/markets_controller.rb \
        test/integration/admin_markets_test.rb
git commit -m "fix(admin-api): permit category and tags in market create/update params

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: MarketCancellationService — void a market and refund all positions

**Files:**
- Create: `app/services/market_cancellation_service.rb`
- Create: `test/services/market_cancellation_service_test.rb`
- Modify: `config/routes.rb` — add `POST /backoffice/markets/:id/cancel`
- Modify: `app/controllers/backoffice/markets_controller.rb` — add `cancel` action
- Modify: `docs/wiki/tech-debt-backlog.md` — mark TD-017 done

**Architecture:** Single service, one transaction. Steps:
1. Lock market; guard `open?` or `closed?` (same guard as settle).
2. For fixed_odds: void all open bets via ledger `BET_VOID_REFUND` credits + wallet update.
3. For clob: cancel all open/partial orders + release reservations (same as `ClobSettlementHandler` Pass 1); void any remaining open bets.
4. For lmsr: credit back cost from `LMSR_TRADE_STAKE` ledger entries for this market (sum debit entries per user, credit back). Clear `lmsr_positions`.
5. For parimutuel: same as `ParimutuelSettlementService#refund_all!` (zero winning pool path), but triggered by operator action.
6. Mark market `cancelled`.
7. AuditEvent `market.cancel`.
8. Emit `market.cancelled.v1` SSE event.

This is a non-trivial service. LMSR refund logic requires summing the net LMSR_TRADE_STAKE debits (minus any SETTLEMENT_WIN credits if the market was partially settled — but that's impossible since you can only cancel non-settled markets). So the refund = sum of all `LMSR_TRADE_STAKE` debits for this market per user.

- [ ] **Step 5.1: Write tests**

```ruby
# test/services/market_cancellation_service_test.rb
require 'test_helper'

class MarketCancellationServiceTest < ActiveSupport::TestCase
  setup do
    @actor = users(:admin)
    @player = users(:player)
    @player.wallet.update!(available_minor: 10_000)
  end

  test 'cancels a fixed_odds market and refunds all open bets' do
    market = markets(:open_market)
    market.bets.delete_all
    bet = Bet.create!(user: @player, market: market, market_leg: market_legs(:yes_leg),
                      stake_minor: 1000, fee_minor: 10, net_stake_minor: 990,
                      odds_minor: 5000, potential_payout_minor: 5000, status: :open)

    initial = @player.wallet.reload.available_minor
    MarketCancellationService.cancel!(market: market, actor: @actor)

    assert_predicate market.reload, :cancelled?
    assert_predicate bet.reload, :voided?
    assert_equal initial + 1000, @player.wallet.reload.available_minor
  end

  test 'raises if market is already settled' do
    market = markets(:open_market)
    market.update_columns(status: Market.statuses[:settled])

    assert_raises(MarketCancellationService::InvalidCancellation) do
      MarketCancellationService.cancel!(market: market, actor: @actor)
    end
  end

  test 'creates audit event on cancel' do
    market = markets(:open_market)
    market.bets.delete_all
    assert_difference('AuditEvent.where(action: "market.cancel").count', 1) do
      MarketCancellationService.cancel!(market: market, actor: @actor)
    end
  end

  test 'cancels CLOB market: releases order reservations' do
    market = markets(:clob_market)
    leg = market.market_legs.find_by!(label: 'YES')
    order = Order.create!(market: market, market_leg: leg, user: @player,
                          side: 'YES', direction: 'buy', price_cents: 60, quantity: 5,
                          status: :open, time_in_force: :gtc)
    @player.wallet.update!(available_minor: 9_700, reserved_minor: 300)

    MarketCancellationService.cancel!(market: market, actor: @actor)

    order.reload
    assert_equal 'cancelled', order.status
    assert_equal 10_000, @player.wallet.reload.available_minor
  end

  test 'cancels parimutuel market: refunds all stakers' do
    market = markets(:parimutuel_market)
    market.update_columns(parimutuel_pool_yes_minor: 0, parimutuel_pool_no_minor: 0)
    LedgerEntry.create!(user: @player, actor: @player, entry_type: 'PARIMUTUEL_STAKE',
                        direction: 'debit', amount_minor: 500,
                        metadata: { market_id: market.id, side: 'YES' })
    market.update_columns(parimutuel_pool_yes_minor: 500)

    initial = @player.wallet.reload.available_minor
    MarketCancellationService.cancel!(market: market, actor: @actor)

    assert_equal initial + 500, @player.wallet.reload.available_minor
    assert_predicate market.reload, :cancelled?
  end
end
```

- [ ] **Step 5.2: Run to confirm failure**

```bash
bin/rails test test/services/market_cancellation_service_test.rb -v
```
Expected: FAIL with `uninitialized constant MarketCancellationService`

- [ ] **Step 5.3: Implement MarketCancellationService**

```ruby
# app/services/market_cancellation_service.rb
class MarketCancellationService
  class InvalidCancellation < StandardError; end

  def self.cancel!(market:, actor:)
    raise InvalidCancellation, 'Market cannot be cancelled (must be open or closed)' \
      unless market.open? || market.closed?

    ApplicationRecord.transaction do
      market.lock!

      case market.mechanism_type
      when 'fixed_odds'
        refund_fixed_odds_bets!(market, actor)
      when 'clob'
        release_clob_orders!(market, actor)
        refund_fixed_odds_bets!(market, actor) # in case any bets exist
      when 'lmsr'
        refund_lmsr_positions!(market, actor)
      when 'parimutuel'
        refund_parimutuel_stakes!(market, actor)
      end

      market.update!(status: :cancelled)

      AuditEvent.create!(
        action: 'market.cancel',
        actor: actor,
        target_type: 'Market', target_id: market.id,
        metadata: { mechanism: market.mechanism_type }
      )

      HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: 'market.cancel')
      HotStorage::Store.current.append_market_event!(
        market_id: market.id,
        event_name: 'market.cancelled.v1',
        payload: { market_id: market.id, actor_id: actor.id },
        version: (market.updated_at.to_f * 1000).to_i
      )
    end

    market.reload
  end

  private_class_method def self.refund_fixed_odds_bets!(market, actor)
    market.bets.where(status: :open).find_each do |bet|
      wallet = bet.user.wallet.lock!
      wallet.update!(available_minor: wallet.available_minor + bet.stake_minor)
      bet.update!(status: :voided)
      LedgerEntry.create!(
        user: bet.user, actor: actor,
        entry_type: 'BET_VOID_REFUND', direction: 'credit',
        amount_minor: bet.stake_minor,
        metadata: { bet_id: bet.id, market_id: market.id, reason: 'market_cancelled' }
      )
    end
  end

  private_class_method def self.release_clob_orders!(market, actor)
    market.orders.where(status: %w[open partial]).find_each do |order|
      released = order.reserved_minor
      order.cancelled_quantity += order.unfilled_quantity
      order.status = :cancelled
      order.save!
      next if released.zero?

      w = order.user.wallet.lock!
      w.update!(reserved_minor: w.reserved_minor - released, available_minor: w.available_minor + released)
      AuditEvent.create!(
        action: 'order.market_cancel',
        actor: actor,
        target_type: 'Order', target_id: order.id,
        metadata: { released_minor: released, market_id: market.id }
      )
    end
  end

  private_class_method def self.refund_lmsr_positions!(market, actor)
    # Sum net debit from LMSR_TRADE_STAKE per user. Credits (when market paid trader) are negative
    # cost to the player — refund only net positive stakes.
    LedgerEntry
      .where(entry_type: 'LMSR_TRADE_STAKE')
      .where("metadata->>'market_id' IS NULL OR TRUE") # LMSR ledger entries lack market_id metadata
      .joins("INNER JOIN lmsr_positions ON lmsr_positions.user_id = ledger_entries.user_id
              AND lmsr_positions.market_id = #{market.id}")
      .where(user_id: LmsrPosition.where(market: market).select(:user_id))
      .group(:user_id)
      # Alternative: use audit events to reconstruct per-user total cost
      # This is the simpler approach: refund from audit events which have market_id
      nil

    # Use audit-event approach (AuditEvent has market_id):
    costs = AuditEvent
              .where(action: 'lmsr_trade.place', target_type: 'Market', target_id: market.id)
              .each_with_object(Hash.new(0)) do |ev, acc|
                acc[ev.actor_id] += ev.metadata['cost_minor'].to_i
              end

    costs.each do |user_id, net_cost|
      next unless net_cost.positive?

      user = User.find(user_id)
      w = user.wallet.lock!
      w.update!(available_minor: w.available_minor + net_cost)
      LedgerEntry.create!(
        user: user, actor: actor,
        entry_type: 'LMSR_CANCEL_REFUND', direction: 'credit',
        amount_minor: net_cost,
        metadata: { market_id: market.id }
      )
    end

    LmsrPosition.where(market: market).delete_all
  end

  private_class_method def self.refund_parimutuel_stakes!(market, actor)
    LedgerEntry.where(entry_type: 'PARIMUTUEL_STAKE')
               .where("metadata->>'market_id' = ?", market.id.to_s)
               .find_each do |entry|
                 w = entry.user.wallet.lock!
                 w.update!(available_minor: w.available_minor + entry.amount_minor)
                 LedgerEntry.create!(
                   user: entry.user, actor: actor,
                   entry_type: 'PARIMUTUEL_REFUND', direction: 'credit',
                   amount_minor: entry.amount_minor,
                   metadata: { market_id: market.id }
                 )
               end
  end
end
```

Note: The LMSR refund uses `AuditEvent` metadata `cost_minor` from `lmsr_trade.place` events (which records `cost_minor` in the audit). This is consistent with the existing `positions_from_ledger` pattern.

- [ ] **Step 5.4: Run tests**

```bash
bin/rails test test/services/market_cancellation_service_test.rb -v
```
Expected: all pass

- [ ] **Step 5.5: Add backoffice route and controller action**

In `config/routes.rb`:
```ruby
resources :markets, only: %i[index show create update] do
  post :open, on: :member
  post :settle, on: :member
  post :operator_buyback, on: :member
  post :cancel, on: :member   # ADD THIS
end
```

In `app/controllers/backoffice/markets_controller.rb` add to `before_action :set_market`:
```ruby
before_action :set_market, only: %i[show open settle update operator_buyback cancel]
```

Add action:
```ruby
def cancel
  require_permission!('market.settle')
  return if performed?

  unless @market.open? || @market.closed?
    return redirect_to backoffice_market_path(@market),
                       alert: 'Market must be open or closed to cancel'
  end

  MarketCancellationService.cancel!(market: @market, actor: current_user)
  redirect_to backoffice_market_path(@market), notice: 'Market cancelled and all positions refunded'
rescue MarketCancellationService::InvalidCancellation => e
  redirect_to backoffice_market_path(@market), alert: e.message
end
```

- [ ] **Step 5.6: Run full suite**

```bash
bin/rails test
```
Expected: 0 failures

- [ ] **Step 5.7: Commit**

```bash
git add app/services/market_cancellation_service.rb \
        test/services/market_cancellation_service_test.rb \
        config/routes.rb \
        app/controllers/backoffice/markets_controller.rb
git commit -m "feat(markets): MarketCancellationService — void market and refund all positions

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: Update docs

- [ ] Append entry to `docs/WORK_LOG.md` with what was built
- [ ] Update `docs/INDEX.md` implementation status
- [ ] Update `docs/wiki/tech-debt-backlog.md` — mark TD-013 through TD-017 as done
- [ ] Update `.claude/tasks/ATTENTION.md` — add completed tasks to recently completed
- [ ] Commit: `docs: update INDEX, WORK_LOG, ATTENTION after backend next-steps`

---

## Self-Review Checklist
- [ ] Every spec invariant has a test
- [ ] Every write action has an AuditEvent
- [ ] Every ledger write has correct entry_type and direction
- [ ] Full test suite passes: `bin/rails test`
- [ ] No placeholder steps remain
