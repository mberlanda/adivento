# Cross-Mechanism Market Cancellation Implementation Plan (D2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `MarketCancellationService` that atomically refunds every participant across fixed-odds, parimutuel, LMSR, and CLOB, plus a backoffice cancel action, closing TD-017.

**Architecture:** One service wraps a single `ApplicationRecord.transaction`: lock the market row, guard status, dispatch a per-mechanism refund method (each locking wallets and writing `MARKET_CANCEL_REFUND` ledger entries), then set `status: :cancelled` and write one `market.cancel` AuditEvent. Build mechanism paths incrementally (fixed_odds → parimutuel → lmsr → clob) so each is independently tested.

**Tech Stack:** Rails 8, PostgreSQL, Minitest, existing patterns (`ParimutuelSettlementService#refund_all!`, `ClobSettlementHandler` Pass 1 are the templates).

**Spec:** `docs/specs/2026-05-30-market-cancellation.md`

---

## File Map

**Create:**
- `app/services/market_cancellation_service.rb`
- `test/services/market_cancellation_service_test.rb`

**Modify:**
- `config/routes.rb` — `post :cancel` on backoffice markets
- `app/controllers/backoffice/markets_controller.rb` — `cancel` action + `set_market` includes `:cancel`
- `app/views/backoffice/markets/show.html.erb` — cancel form (open/closed only)
- `app/domain/catalogs/permission_catalog.rb` — add `market.cancel` (admin default, not moderator)
- `docs/wiki/tech-debt-backlog.md` — close TD-017
- `docs/WORK_LOG.md`, `docs/INDEX.md`

---

## Task 1: Service skeleton + idempotency guard

**Files:**
- Create: `app/services/market_cancellation_service.rb`, `test/services/market_cancellation_service_test.rb`

- [ ] **Step 1.1: Write the failing test**

```ruby
# test/services/market_cancellation_service_test.rb
require 'test_helper'

class MarketCancellationServiceTest < ActiveSupport::TestCase
  setup { @actor = users(:admin) }

  test 'cancels an open market and writes one market.cancel audit event' do
    market = markets(:open_market)
    assert_difference -> { AuditEvent.where(action: 'market.cancel', target_id: market.id).count }, 1 do
      result = MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')
      assert result.success?
    end
    assert_predicate market.reload, :cancelled?
  end

  test 'raises on a non-open/closed market and changes nothing' do
    market = markets(:draft_market)
    assert_raises(MarketCancellationService::InvalidCancellation) do
      MarketCancellationService.call(market: market, actor: @actor, reason: 'nope reason here')
    end
    assert_not market.reload.cancelled?
  end

  test 'is idempotent — re-cancelling a cancelled market raises' do
    market = markets(:open_market)
    MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')
    assert_raises(MarketCancellationService::InvalidCancellation) do
      MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')
    end
  end
end
```

- [ ] **Step 1.2: Run to verify failure**

```bash
bin/rails test test/services/market_cancellation_service_test.rb -v
```
Expected: FAIL — `uninitialized constant MarketCancellationService`

- [ ] **Step 1.3: Implement the skeleton**

```ruby
# app/services/market_cancellation_service.rb
class MarketCancellationService
  class InvalidCancellation < StandardError; end

  Result = Struct.new(:success?, :refunded_total_minor, :errors, keyword_init: true)

  def self.call(**) = new(**).call

  def initialize(market:, actor:, reason:)
    @market = market
    @actor = actor
    @reason = reason.to_s.strip
  end

  def call
    raise InvalidCancellation, 'Reason is required (min 10 characters)' if @reason.length < 10

    refunded = 0
    ApplicationRecord.transaction do
      m = Market.lock.find(@market.id)
      raise InvalidCancellation, 'Market cannot be cancelled' unless m.open? || m.closed?

      refunded += refund_fixed_odds!(m) if m.fixed_odds?
      refunded += refund_parimutuel!(m) if m.parimutuel?
      refunded += refund_lmsr!(m)       if m.lmsr?
      refunded += refund_clob!(m)       if m.clob?

      m.update!(status: :cancelled)
      AuditEvent.create!(
        actor: @actor, action: 'market.cancel',
        target_type: 'Market', target_id: m.id,
        reason: @reason, metadata: { refunded_total_minor: refunded, mechanism: m.mechanism_type }
      )
      @market = m
    end

    Result.new(success?: true, refunded_total_minor: refunded, errors: [])
  end

  private

  # Filled in by Tasks 2-5. Default no-op keeps the skeleton green.
  def refund_fixed_odds!(_m) = 0
  def refund_parimutuel!(_m) = 0
  def refund_lmsr!(_m) = 0
  def refund_clob!(_m) = 0

  def credit!(user, amount, mechanism)
    return 0 unless amount.positive?

    wallet = user.wallet.lock!
    wallet.update!(available_minor: wallet.available_minor + amount)
    LedgerEntry.create!(user: user, actor: @actor, entry_type: 'MARKET_CANCEL_REFUND',
                        direction: 'credit', amount_minor: amount,
                        metadata: { market_id: @market.id, mechanism: mechanism })
    amount
  end
end
```

- [ ] **Step 1.4: Run to verify pass; Step 1.5: Commit**

```bash
bin/rails test test/services/market_cancellation_service_test.rb -v
git add app/services/market_cancellation_service.rb test/services/market_cancellation_service_test.rb
git commit -m "feat(cancel): MarketCancellationService skeleton with idempotent status guard (TD-017)"
```

---

## Task 2: Fixed-odds refunds

- [ ] **Step 2.1: Write the failing test** (add to the test file)

```ruby
test 'fixed_odds refunds each open bet stake and voids the bet' do
  market = markets(:open_market)
  user = users(:player)
  user.wallet.update!(available_minor: 0)
  bet = Bet.create!(user: user, market: market, market_leg: market.market_legs.find_by!(label: 'YES'),
                    stake_minor: 1000, fee_minor: 10, net_stake_minor: 990, odds_minor: 5000,
                    potential_payout_minor: 5000, status: :open)

  MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')

  assert_equal 1000, user.wallet.reload.available_minor
  assert_predicate bet.reload, :voided?
  assert_equal 1, LedgerEntry.where(user: user, entry_type: 'MARKET_CANCEL_REFUND').count
end
```

- [ ] **Step 2.2: Run → FAIL** (`bin/rails test ... -n "/fixed_odds refunds/"`); wallet stays 0.

- [ ] **Step 2.3: Implement `refund_fixed_odds!`**

```ruby
  def refund_fixed_odds!(market)
    total = 0
    market.bets.where(status: :open).find_each do |bet|
      total += credit!(bet.user, bet.stake_minor, 'fixed_odds')
      bet.update!(status: :voided)
    end
    total
  end
```

- [ ] **Step 2.4: Run → PASS; Step 2.5: Commit** `feat(cancel): refund and void open fixed-odds bets`

---

## Task 3: Parimutuel refunds

- [ ] **Step 3.1: Write the failing test** — stake on a parimutuel market via `Parimutuel::ParimutuelPoolService`, cancel, assert each staker refunded and pools reset to 0. Use `markets(:parimutuel_market)`.

```ruby
test 'parimutuel refunds every stake and resets pools' do
  market = markets(:parimutuel_market)
  user = users(:player)
  user.wallet.update!(available_minor: 5000)
  Parimutuel::ParimutuelPoolService.call(market: market, user: user, side: 'YES', amount_minor: 2000)

  MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')

  assert_equal 5000, user.wallet.reload.available_minor
  assert_equal 0, market.reload.parimutuel_pool_yes_minor
  assert_equal 0, market.parimutuel_pool_no_minor
end
```

- [ ] **Step 3.2: Run → FAIL.**

- [ ] **Step 3.3: Implement `refund_parimutuel!`** (mirror `ParimutuelSettlementService#refund_all!`)

```ruby
  def refund_parimutuel!(market)
    total = 0
    LedgerEntry.where(entry_type: 'PARIMUTUEL_STAKE')
               .where("metadata->>'market_id' = ?", market.id.to_s)
               .find_each do |entry|
      total += credit!(entry.user, entry.amount_minor, 'parimutuel')
    end
    market.update!(parimutuel_pool_yes_minor: 0, parimutuel_pool_no_minor: 0)
    total
  end
```

- [ ] **Step 3.4: Run → PASS; Step 3.5: Commit** `feat(cancel): refund parimutuel stakes and reset pools`

---

## Task 4: LMSR refunds

- [ ] **Step 4.1: Write the failing test** — buy LMSR contracts via `Lmsr::LmsrTradeService`, cancel, assert the trader's paid cost is refunded and their `LmsrPosition` is zeroed. Use `markets(:lmsr_market)`.

```ruby
test 'lmsr refunds each trader cost and zeroes positions' do
  market = markets(:lmsr_market)
  user = users(:player)
  user.wallet.update!(available_minor: 100_000)
  before = user.wallet.available_minor
  Lmsr::LmsrTradeService.call(market: market, user: user, side: 'YES', quantity: 5)
  spent = before - user.wallet.reload.available_minor
  assert spent.positive?

  MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')

  # cost (excluding LMSR_FEE) refunded; positions zeroed
  refunded = LedgerEntry.where(user: user, entry_type: 'MARKET_CANCEL_REFUND').sum(:amount_minor)
  staked = LedgerEntry.where(user: user, entry_type: 'LMSR_TRADE_STAKE').sum(:amount_minor)
  assert_equal staked, refunded
  assert_equal 0, LmsrPosition.for_market(market).where(user: user).sum(:contracts)
end
```

- [ ] **Step 4.2: Run → FAIL.**

- [ ] **Step 4.3: Implement `refund_lmsr!`**

LMSR cost lives in `LMSR_TRADE_STAKE` ledger entries. These currently lack `market_id` in metadata (ARCH-005), so attribute via the market's `lmsr_trade.place` AuditEvents to find the participating users, then sum each user's `LMSR_TRADE_STAKE` debits scoped to those audit events' amounts. Simplest robust approach: sum per user from the audit-derived trade list.

```ruby
  def refund_lmsr!(market)
    # user_id => total cost paid (minor), derived from this market's trade audit events
    costs = Hash.new(0)
    AuditEvent.where(action: 'lmsr_trade.place', target_type: 'Market', target_id: market.id).find_each do |ev|
      costs[ev.actor_id] += ev.metadata['cost_minor'].to_i
    end

    total = 0
    costs.each do |user_id, cost|
      total += credit!(User.find(user_id), cost, 'lmsr')
    end
    LmsrPosition.for_market(market).update_all(contracts: 0)
    total
  end
```

> Prerequisite check: confirm `lmsr_trade.place` AuditEvent metadata includes `cost_minor`. If it does not, first land ARCH-005 (add `market_id`/`cost_minor` to `LMSR_TRADE_STAKE` ledger metadata) and sum from ledger entries instead. Adjust this step to whichever attribution source is reliable; the test asserts `refunded == Σ LMSR_TRADE_STAKE`.

- [ ] **Step 4.4: Run → PASS; Step 4.5: Commit** `feat(cancel): refund lmsr trade cost and zero positions`

---

## Task 5: CLOB refunds (reservations + net cash)

- [ ] **Step 5.1: Write the failing tests** — (a) open orders cancelled + reservations released; (b) a net buyer refunded their `ORDER_FILL_STAKE`; (c) a net seller clawed back their `CLOB_SELL_CREDIT`. Build the book with `Clob::OrderMatchingService`. Use `markets(:clob_market)`.

```ruby
test 'clob releases open-order reservations on cancel' do
  market = markets(:clob_market)
  buyer = users(:player)
  buyer.wallet.update!(available_minor: 500_000, reserved_minor: 0)
  Clob::OrderMatchingService.call(market: market, incoming_order_params: {
    user: buyer, side: 'YES', price_cents: 40, quantity: 5,
    market_leg: market.market_legs.find_by!(label: 'YES'), time_in_force: :gtc })
  assert_operator buyer.wallet.reload.reserved_minor, :>, 0

  MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')

  assert_equal 0, buyer.wallet.reload.reserved_minor
  assert market.reload.orders.where(status: %w[open partial]).none?
end
```

(Add a fill-based test where a buy fills against a sell, then assert the net buyer's `ORDER_FILL_STAKE` is refunded via `MARKET_CANCEL_REFUND` and the net seller's `CLOB_SELL_CREDIT` is debited via `MARKET_CANCEL_CLAWBACK`.)

- [ ] **Step 5.2: Run → FAIL.**

- [ ] **Step 5.3: Implement `refund_clob!`**

```ruby
  def refund_clob!(market)
    # (a) cancel open/partial orders, release reservations (ClobSettlementHandler Pass 1)
    market.orders.where(status: %w[open partial]).find_each do |order|
      released = order.reserved_minor
      order.update!(cancelled_quantity: order.cancelled_quantity + order.unfilled_quantity, status: :cancelled)
      next if released.zero?

      w = order.user.wallet.lock!
      w.update!(reserved_minor: w.reserved_minor - released, available_minor: w.available_minor + released)
    end

    # (b) net cash per user from fills: Σ ORDER_FILL_STAKE − Σ CLOB_SELL_CREDIT
    net = Hash.new(0)
    LedgerEntry.where(entry_type: 'ORDER_FILL_STAKE').where("metadata->>'market_id' = ?", market.id.to_s)
               .find_each { |e| net[e.user_id] += e.amount_minor }
    LedgerEntry.where(entry_type: 'CLOB_SELL_CREDIT').where("metadata->>'market_id' = ?", market.id.to_s)
               .find_each { |e| net[e.user_id] -= e.amount_minor }

    total = 0
    net.each do |user_id, amount|
      user = User.find(user_id)
      if amount.positive?
        total += credit!(user, amount, 'clob')              # net buyer: refund
      elsif amount.negative?
        total -= clawback!(user, -amount)                   # net seller: claw back (floored)
      end
    end
    total
  end

  def clawback!(user, amount)
    wallet = user.wallet.lock!
    taken = [amount, wallet.available_minor].min
    wallet.update!(available_minor: wallet.available_minor - taken)
    LedgerEntry.create!(user: user, actor: @actor, entry_type: 'MARKET_CANCEL_CLAWBACK',
                        direction: 'debit', amount_minor: taken,
                        metadata: { market_id: @market.id, mechanism: 'clob', requested_minor: amount,
                                    shortfall_minor: amount - taken })
    taken
  end
```

> Both `ORDER_FILL_STAKE` and `CLOB_SELL_CREDIT` already carry `market_id` in metadata (`order_matching_service.rb`), so the scoping queries work today. Record any `shortfall_minor > 0` — the cancellation AuditEvent metadata should aggregate it (extend Task 1's audit `metadata` with `clawback_shortfall_minor` summed across users).

- [ ] **Step 5.4: Run → PASS; Step 5.5: Commit** `feat(cancel): release CLOB reservations and net-cash refund/clawback`

---

## Task 6: Backoffice cancel action + permission

**Files:**
- Modify: `config/routes.rb`, `app/controllers/backoffice/markets_controller.rb`, `app/views/backoffice/markets/show.html.erb`, `app/domain/catalogs/permission_catalog.rb`
- Test: `test/integration/backoffice_management_test.rb`

- [ ] **Step 6.1: Write the failing integration test** — admin can cancel an open market via `POST /backoffice/markets/:id/cancel` with a reason; a moderator without `market.cancel` is redirected/forbidden.

- [ ] **Step 6.2: Add the permission** in `app/domain/catalogs/permission_catalog.rb`: define `market.cancel`, grant to `admin` defaults only (follow the existing catalog structure; do **not** add to moderator defaults).

- [ ] **Step 6.3: Add the route** in `config/routes.rb` backoffice markets member block (next to `:settle`): `post :cancel`.

- [ ] **Step 6.4: Add the controller action**

```ruby
    def cancel
      require_permission!('market.cancel')
      return if performed?

      result = MarketCancellationService.call(market: @market, actor: current_user, reason: params[:reason])
      redirect_to backoffice_market_path(@market),
                  notice: "Market cancelled — refunded #{result.refunded_total_minor} minor"
    rescue MarketCancellationService::InvalidCancellation => e
      redirect_to backoffice_market_path(@market), alert: e.message
    end
```

Add `:cancel` to the `set_market` `before_action` `only:` list.

- [ ] **Step 6.5: Add the cancel form** in `show.html.erb` (only when `@market.open? || @market.closed?`), with a required `reason` field and a confirm dialog.

- [ ] **Step 6.6: Run → PASS; Step 6.7: Commit** `feat(cancel): backoffice cancel action, route, and market.cancel permission`

---

## Task 7: Docs

- [ ] Close **TD-017** in `docs/wiki/tech-debt-backlog.md` (MarketCancellationService shipped; reference this plan + spec).
- [ ] Update `docs/WORK_LOG.md` + `docs/INDEX.md`.
- [ ] Commit `docs: update INDEX and WORK_LOG after market cancellation (D2)`

---

## Self-Review Checklist
- [ ] Idempotent: locked market row + status guard; re-cancel raises (Task 1).
- [ ] All four mechanisms refund correctly; conservation holds for fixed_odds/parimutuel/lmsr (Tasks 2-5).
- [ ] Every wallet write under `lock!`; every refund writes `MARKET_CANCEL_REFUND` (Tasks 1-5).
- [ ] CLOB clawback floored at available balance; shortfall recorded (Task 5).
- [ ] One `market.cancel` AuditEvent with reason + totals (Task 1).
- [ ] `market.cancel` permission excludes moderator by default (Task 6).
- [ ] Full suite passes: `bin/rails test`; RuboCop clean.
- [ ] No placeholder steps remain.
