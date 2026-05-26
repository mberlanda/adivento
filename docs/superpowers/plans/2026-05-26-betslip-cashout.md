# Betslip + Cashout Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-26-betslip-cashout.md -->
<!-- Written AFTER the spec is approved. Describes HOW. -->
<!-- Each task = one atomic commit. Each step = one verifiable action. -->

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use `- [ ]` for tracking.

**Goal:** Enable players to submit multi-item betslips via a quote-then-execute flow with idempotency, and to cashout open positions at a current fair value.

**Architecture:**
- Two persisted records: `BetslipQuote` (quote with TTL + idempotency key) and `BetslipExecution` (durable record of execution result).
- Three services: `BetslipQuoteService` (creates / replays quotes), `BetslipExecutionService` (atomic placement via `BetPlacementService` per item), `CashoutQuoteService` + `CashoutExecutionService` (compute + close at fair value).
- Cashout quote is a plain Struct, computed on demand; not persisted.
- All write paths wrap in `ApplicationRecord.transaction`. Stake debits remain owned by `BetPlacementService` (no double-debit in the betslip layer).
- Web surface mounts JSON endpoints under `namespace :web`, authenticated by session cookie (same mechanism as `Web::SessionsController`).

**Tech Stack:** Rails 8, Minitest, existing patterns (see `docs/INDEX.md` for file map).

**Spec:** [docs/specs/2026-05-26-betslip-cashout.md](../../specs/2026-05-26-betslip-cashout.md)

---

## File Map

**Create:**
- `db/migrate/<timestamp>_create_betslip_quotes.rb`
- `db/migrate/<timestamp>_create_betslip_executions.rb`
- `app/models/betslip_quote.rb`
- `app/models/betslip_execution.rb`
- `app/services/betslip_quote_service.rb`
- `app/services/betslip_execution_service.rb`
- `app/services/cashout_quote_service.rb`
- `app/services/cashout_execution_service.rb`
- `app/controllers/web/betslips_controller.rb`
- `app/controllers/web/betslip_executions_controller.rb`
- `app/controllers/web/positions_controller.rb`
- `test/models/betslip_quote_test.rb`
- `test/models/betslip_execution_test.rb`
- `test/services/betslip_quote_service_test.rb`
- `test/services/betslip_execution_service_test.rb`
- `test/services/cashout_quote_service_test.rb`
- `test/services/cashout_execution_service_test.rb`
- `test/integration/web_betslip_test.rb`

**Modify:**
- `config/routes.rb` — add betslip / positions routes under `namespace :web`

---

## Task 1: BetslipQuote model + migration

**Files:**
- Create: `db/migrate/<timestamp>_create_betslip_quotes.rb`
- Create: `app/models/betslip_quote.rb`
- Create: `test/models/betslip_quote_test.rb`

- [ ] **Step 1.1: Write the failing test first**

`test/models/betslip_quote_test.rb`:
```ruby
require "test_helper"

class BetslipQuoteTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
  end

  test "valid quote can be created" do
    quote = BetslipQuote.create!(
      user: @user,
      idempotency_key: "key-1",
      items: [{ "market_leg_id" => 1, "stake_minor" => 500, "potential_payout_minor" => 1000 }],
      total_stake_minor: 500,
      expires_at: 60.seconds.from_now
    )
    assert quote.persisted?
    assert_predicate quote, :pending?
  end

  test "idempotency_key is unique" do
    BetslipQuote.create!(
      user: @user,
      idempotency_key: "dup-key",
      items: [],
      total_stake_minor: 0,
      expires_at: 60.seconds.from_now
    )
    duplicate = BetslipQuote.new(
      user: @user,
      idempotency_key: "dup-key",
      items: [],
      total_stake_minor: 0,
      expires_at: 60.seconds.from_now
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:idempotency_key], "has already been taken"
  end

  test "expired? returns true when expires_at is in the past" do
    quote = BetslipQuote.new(expires_at: 1.second.ago)
    assert quote.expired?
  end

  test "expired? returns false when expires_at is in the future" do
    quote = BetslipQuote.new(expires_at: 60.seconds.from_now)
    assert_not quote.expired?
  end
end
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
bin/rails test test/models/betslip_quote_test.rb -v
```
Expected: FAIL with `uninitialized constant BetslipQuote`.

- [ ] **Step 1.3: Generate migration file**

```bash
bin/rails generate migration CreateBetslipQuotes
```

Replace the generated file content with:
```ruby
class CreateBetslipQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :betslip_quotes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :idempotency_key, null: false
      t.jsonb :items, null: false, default: []
      t.bigint :total_stake_minor, null: false
      t.datetime :expires_at, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :betslip_quotes, :idempotency_key, unique: true
    add_index :betslip_quotes, :status
  end
end
```

- [ ] **Step 1.4: Implement the model**

`app/models/betslip_quote.rb`:
```ruby
class BetslipQuote < ApplicationRecord
  enum :status, { pending: 0, executed: 1, expired: 2 }, default: :pending

  belongs_to :user
  has_one :betslip_execution, dependent: :restrict_with_exception

  validates :idempotency_key, presence: true, uniqueness: true
  validates :total_stake_minor, numericality: { greater_than_or_equal_to: 0 }
  validates :expires_at, presence: true

  def expired?
    expires_at < Time.current
  end
end
```

- [ ] **Step 1.5: Run migration and re-run test**

```bash
bin/rails db:migrate
bin/rails test test/models/betslip_quote_test.rb -v
```
Expected: 4 tests, 4 assertions, 0 failures.

- [ ] **Step 1.6: Commit**

```bash
git add db/migrate/*_create_betslip_quotes.rb db/schema.rb \
        app/models/betslip_quote.rb test/models/betslip_quote_test.rb
git commit -m "$(cat <<'EOF'
feat(betslip): add BetslipQuote model and migration

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: BetslipExecution model + migration

**Files:**
- Create: `db/migrate/<timestamp>_create_betslip_executions.rb`
- Create: `app/models/betslip_execution.rb`
- Create: `test/models/betslip_execution_test.rb`

- [ ] **Step 2.1: Write the failing test first**

`test/models/betslip_execution_test.rb`:
```ruby
require "test_helper"

class BetslipExecutionTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @quote = BetslipQuote.create!(
      user: @user,
      idempotency_key: "exec-test-key",
      items: [],
      total_stake_minor: 0,
      expires_at: 60.seconds.from_now
    )
  end

  test "valid execution belongs to a quote and user" do
    execution = BetslipExecution.create!(
      betslip_quote: @quote,
      user: @user,
      bet_ids: [1, 2],
      status: :completed
    )
    assert execution.persisted?
    assert_predicate execution, :completed?
    assert_equal [1, 2], execution.bet_ids
  end

  test "BetslipQuote has_one execution" do
    execution = BetslipExecution.create!(
      betslip_quote: @quote,
      user: @user,
      bet_ids: [],
      status: :completed
    )
    assert_equal execution, @quote.reload.betslip_execution
  end
end
```

- [ ] **Step 2.2: Run test to verify it fails**

```bash
bin/rails test test/models/betslip_execution_test.rb -v
```
Expected: FAIL with `uninitialized constant BetslipExecution`.

- [ ] **Step 2.3: Generate migration**

```bash
bin/rails generate migration CreateBetslipExecutions
```

Replace generated file with:
```ruby
class CreateBetslipExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :betslip_executions do |t|
      t.references :betslip_quote, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.jsonb :bet_ids, null: false, default: []
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
```

- [ ] **Step 2.4: Implement the model**

`app/models/betslip_execution.rb`:
```ruby
class BetslipExecution < ApplicationRecord
  enum :status, { completed: 0, failed: 1 }, default: :completed

  belongs_to :betslip_quote
  belongs_to :user
end
```

- [ ] **Step 2.5: Run migration and re-run test**

```bash
bin/rails db:migrate
bin/rails test test/models/betslip_execution_test.rb -v
```
Expected: 2 tests, 3 assertions, 0 failures.

- [ ] **Step 2.6: Commit**

```bash
git add db/migrate/*_create_betslip_executions.rb db/schema.rb \
        app/models/betslip_execution.rb test/models/betslip_execution_test.rb
git commit -m "$(cat <<'EOF'
feat(betslip): add BetslipExecution model and migration

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: BetslipQuoteService

**Files:**
- Create: `app/services/betslip_quote_service.rb`
- Create: `test/services/betslip_quote_service_test.rb`

- [ ] **Step 3.1: Write the failing test first**

`test/services/betslip_quote_service_test.rb`:
```ruby
require "test_helper"

class BetslipQuoteServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
  end

  test "builds a quote with potential payouts and total stake" do
    quote = BetslipQuoteService.call(
      user: @user,
      items: [
        { market_leg_id: @yes_leg.id, stake_minor: 500 },
        { market_leg_id: @no_leg.id, stake_minor: 1000 }
      ],
      idempotency_key: "k1"
    )

    assert quote.persisted?
    assert_equal 1500, quote.total_stake_minor
    assert_equal 2, quote.items.length
    assert_equal @yes_leg.id, quote.items.first["market_leg_id"]
    expected_payout = (500 * @yes_leg.odds_minor / 10_000.0).floor
    assert_equal expected_payout, quote.items.first["potential_payout_minor"]
    assert_in_delta 60.0, (quote.expires_at - Time.current), 5.0
  end

  test "replays existing quote when idempotency_key matches and payload matches" do
    quote1 = BetslipQuoteService.call(
      user: @user,
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: "replay-key"
    )
    quote2 = BetslipQuoteService.call(
      user: @user,
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: "replay-key"
    )
    assert_equal quote1.id, quote2.id
  end

  test "raises Conflict when idempotency_key matches but payload differs" do
    BetslipQuoteService.call(
      user: @user,
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: "conflict-key"
    )
    assert_raises(BetslipQuoteService::Conflict) do
      BetslipQuoteService.call(
        user: @user,
        items: [{ market_leg_id: @yes_leg.id, stake_minor: 999 }],
        idempotency_key: "conflict-key"
      )
    end
  end

  test "raises InvalidQuote when leg's market is not open" do
    draft_market = markets(:draft_market)
    draft_leg = MarketLeg.create!(market: draft_market, label: "X", odds_minor: 5000)

    assert_raises(BetslipQuoteService::InvalidQuote) do
      BetslipQuoteService.call(
        user: @user,
        items: [{ market_leg_id: draft_leg.id, stake_minor: 100 }],
        idempotency_key: "draft-key"
      )
    end
  end

  test "raises InvalidQuote when market_leg does not exist" do
    assert_raises(BetslipQuoteService::InvalidQuote) do
      BetslipQuoteService.call(
        user: @user,
        items: [{ market_leg_id: 999_999, stake_minor: 100 }],
        idempotency_key: "missing-leg-key"
      )
    end
  end

  test "raises InvalidQuote when items is empty" do
    assert_raises(BetslipQuoteService::InvalidQuote) do
      BetslipQuoteService.call(user: @user, items: [], idempotency_key: "empty-key")
    end
  end
end
```

- [ ] **Step 3.2: Run test to verify it fails**

```bash
bin/rails test test/services/betslip_quote_service_test.rb -v
```
Expected: FAIL with `uninitialized constant BetslipQuoteService`.

- [ ] **Step 3.3: Implement the service**

`app/services/betslip_quote_service.rb`:
```ruby
class BetslipQuoteService
  class InvalidQuote < StandardError; end
  class Conflict < StandardError; end

  TTL_SECONDS = 60

  def self.call(user:, items:, idempotency_key:)
    raise InvalidQuote, "Items cannot be empty" if items.blank?
    raise InvalidQuote, "idempotency_key is required" if idempotency_key.to_s.strip.empty?

    normalized_items = items.map do |item|
      leg_id = item[:market_leg_id] || item["market_leg_id"]
      stake = (item[:stake_minor] || item["stake_minor"]).to_i
      raise InvalidQuote, "stake_minor must be positive" unless stake.positive?

      leg = MarketLeg.find_by(id: leg_id)
      raise InvalidQuote, "Unknown market_leg #{leg_id}" unless leg
      raise InvalidQuote, "Market #{leg.market_id} is not open" unless leg.market.open?

      payout = (stake * leg.odds_minor / 10_000.0).floor
      { "market_leg_id" => leg.id, "stake_minor" => stake, "potential_payout_minor" => payout }
    end

    total_stake = normalized_items.sum { |i| i["stake_minor"] }

    existing = BetslipQuote.find_by(idempotency_key: idempotency_key)
    if existing
      raise Conflict, "idempotency_key conflict" unless payloads_match?(existing, normalized_items, total_stake)
      return existing
    end

    BetslipQuote.create!(
      user: user,
      idempotency_key: idempotency_key,
      items: normalized_items,
      total_stake_minor: total_stake,
      expires_at: Time.current + TTL_SECONDS.seconds
    )
  rescue ActiveRecord::RecordNotUnique
    # Race: another caller inserted the same key — retry once to fetch and compare.
    existing = BetslipQuote.find_by!(idempotency_key: idempotency_key)
    raise Conflict, "idempotency_key conflict" unless payloads_match?(existing, normalized_items, total_stake)
    existing
  end

  def self.payloads_match?(quote, normalized_items, total_stake)
    quote.total_stake_minor == total_stake &&
      quote.items.length == normalized_items.length &&
      quote.items.zip(normalized_items).all? do |a, b|
        a["market_leg_id"] == b["market_leg_id"] && a["stake_minor"] == b["stake_minor"]
      end
  end
  private_class_method :payloads_match?
end
```

- [ ] **Step 3.4: Run test to verify it passes**

```bash
bin/rails test test/services/betslip_quote_service_test.rb -v
```
Expected: 6 tests, all green.

- [ ] **Step 3.5: Commit**

```bash
git add app/services/betslip_quote_service.rb \
        test/services/betslip_quote_service_test.rb
git commit -m "$(cat <<'EOF'
feat(betslip): add BetslipQuoteService

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: BetslipExecutionService

**Files:**
- Create: `app/services/betslip_execution_service.rb`
- Create: `test/services/betslip_execution_service_test.rb`

- [ ] **Step 4.1: Write the failing test first**

`test/services/betslip_execution_service_test.rb`:
```ruby
require "test_helper"

class BetslipExecutionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @user.wallet.update!(available_minor: 100_000)
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
    @market.bets.delete_all
  end

  def build_quote(stake_yes: 500, stake_no: 1000, key: "exec-#{SecureRandom.hex(4)}")
    BetslipQuoteService.call(
      user: @user,
      items: [
        { market_leg_id: @yes_leg.id, stake_minor: stake_yes },
        { market_leg_id: @no_leg.id, stake_minor: stake_no }
      ],
      idempotency_key: key
    )
  end

  test "execute! creates bets, marks quote executed, writes audit event" do
    quote = build_quote
    initial_balance = @user.wallet.available_minor

    execution = BetslipExecutionService.execute!(quote: quote, actor: @user)

    quote.reload
    assert_predicate quote, :executed?
    assert_predicate execution, :completed?
    assert_equal 2, execution.bet_ids.length

    @user.wallet.reload
    assert_equal initial_balance - 1500, @user.wallet.available_minor

    bets = Bet.where(id: execution.bet_ids)
    assert bets.all?(&:open?)

    assert AuditEvent.where(action: "betslip.execute", target_type: "BetslipExecution", target_id: execution.id).exists?
  end

  test "execute! raises ExpiredQuote when quote has expired" do
    quote = build_quote
    quote.update_column(:expires_at, 1.second.ago)

    initial_balance = @user.wallet.available_minor

    assert_raises(BetslipExecutionService::ExpiredQuote) do
      BetslipExecutionService.execute!(quote: quote, actor: @user)
    end

    @user.wallet.reload
    assert_equal initial_balance, @user.wallet.available_minor
    assert_equal 0, Bet.where(user: @user).where.not(status: :voided).count
  end

  test "execute! raises AlreadyExecuted when quote already executed" do
    quote = build_quote
    BetslipExecutionService.execute!(quote: quote, actor: @user)

    assert_raises(BetslipExecutionService::AlreadyExecuted) do
      BetslipExecutionService.execute!(quote: quote.reload, actor: @user)
    end
  end

  test "execute! is all-or-nothing when one item's market closes mid-flight" do
    quote = build_quote
    # Simulate the market becoming non-open after the quote was created.
    @market.update!(status: :cancelled)
    initial_balance = @user.wallet.available_minor

    assert_raises(BetslipExecutionService::ExecutionFailed) do
      BetslipExecutionService.execute!(quote: quote, actor: @user)
    end

    @user.wallet.reload
    assert_equal initial_balance, @user.wallet.available_minor
    assert_equal 0, Bet.where(market: @market, user: @user).count
    assert_predicate quote.reload, :pending?
  end
end
```

- [ ] **Step 4.2: Run test to verify it fails**

```bash
bin/rails test test/services/betslip_execution_service_test.rb -v
```
Expected: FAIL with `uninitialized constant BetslipExecutionService`.

- [ ] **Step 4.3: Implement the service**

`app/services/betslip_execution_service.rb`:
```ruby
class BetslipExecutionService
  class ExpiredQuote < StandardError; end
  class AlreadyExecuted < StandardError; end
  class ExecutionFailed < StandardError; end

  def self.execute!(quote:, actor:)
    raise AlreadyExecuted, "Quote #{quote.id} already executed" if quote.executed?
    raise ExpiredQuote, "Quote #{quote.id} expired at #{quote.expires_at}" if quote.expired?

    if (existing = BetslipExecution.find_by(betslip_quote_id: quote.id))
      return existing
    end

    bet_ids = []

    ApplicationRecord.transaction do
      quote.lock!
      raise AlreadyExecuted, "Quote #{quote.id} already executed" if quote.executed?

      quote.items.each do |item|
        leg = MarketLeg.find(item["market_leg_id"])
        market = leg.market
        bet = BetPlacementService.place!(
          user: quote.user,
          market: market,
          market_leg: leg,
          stake_minor: item["stake_minor"]
        )
        bet_ids << bet.id
      end

      quote.update!(status: :executed)

      execution = BetslipExecution.create!(
        betslip_quote: quote,
        user: quote.user,
        bet_ids: bet_ids,
        status: :completed
      )

      AuditEvent.create!(
        actor: actor,
        action: "betslip.execute",
        target_type: "BetslipExecution",
        target_id: execution.id,
        metadata: { quote_id: quote.id, bet_count: bet_ids.length }
      )

      execution
    end
  rescue BetPlacementService::InvalidBet, BetPlacementService::RiskLimitExceeded => e
    raise ExecutionFailed, e.message
  end
end
```

- [ ] **Step 4.4: Run test to verify it passes**

```bash
bin/rails test test/services/betslip_execution_service_test.rb -v
```
Expected: 4 tests, all green.

- [ ] **Step 4.5: Commit**

```bash
git add app/services/betslip_execution_service.rb \
        test/services/betslip_execution_service_test.rb
git commit -m "$(cat <<'EOF'
feat(betslip): add BetslipExecutionService

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: CashoutQuoteService + CashoutExecutionService

**Files:**
- Create: `app/services/cashout_quote_service.rb`
- Create: `app/services/cashout_execution_service.rb`
- Create: `test/services/cashout_quote_service_test.rb`
- Create: `test/services/cashout_execution_service_test.rb`

- [ ] **Step 5.1: Write the failing tests first**

`test/services/cashout_quote_service_test.rb`:
```ruby
require "test_helper"

class CashoutQuoteServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @user.wallet.update!(available_minor: 100_000)
    @market = markets(:open_market)
    @market.update!(fee_bps: 100) # 1%
    @yes_leg = market_legs(:yes_leg)
    @yes_leg.update!(odds_minor: 20_000) # 2.0x
    @market.bets.delete_all
    @bet = Bet.create!(
      user: @user,
      market: @market,
      market_leg: @yes_leg,
      stake_minor: 1000,
      fee_minor: 10,
      net_stake_minor: 990,
      odds_minor: @yes_leg.odds_minor,
      potential_payout_minor: 2000,
      status: :open
    )
  end

  test "computes gross, fee, and net payout" do
    quote = CashoutQuoteService.quote(bet: @bet)
    assert_equal @bet.id, quote.bet_id
    assert_equal 2000, quote.gross_payout_minor
    assert_equal 20, quote.fee_minor
    assert_equal 1980, quote.net_payout_minor
    assert_in_delta 60.0, (quote.expires_at - Time.current), 5.0
  end

  test "raises InvalidPosition when bet is not open" do
    @bet.update!(status: :voided)
    assert_raises(CashoutQuoteService::InvalidPosition) do
      CashoutQuoteService.quote(bet: @bet)
    end
  end

  test "raises InvalidPosition when bet's market is not open" do
    @market.update!(status: :cancelled)
    assert_raises(CashoutQuoteService::InvalidPosition) do
      CashoutQuoteService.quote(bet: @bet.reload)
    end
  end
end
```

`test/services/cashout_execution_service_test.rb`:
```ruby
require "test_helper"

class CashoutExecutionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @user.wallet.update!(available_minor: 50_000)
    @market = markets(:open_market)
    @market.update!(fee_bps: 100)
    @yes_leg = market_legs(:yes_leg)
    @yes_leg.update!(odds_minor: 20_000)
    @market.bets.delete_all
    @bet = Bet.create!(
      user: @user,
      market: @market,
      market_leg: @yes_leg,
      stake_minor: 1000,
      fee_minor: 10,
      net_stake_minor: 990,
      odds_minor: @yes_leg.odds_minor,
      potential_payout_minor: 2000,
      status: :open
    )
  end

  test "credits net payout, voids bet, writes ledger and audit" do
    initial_balance = @user.wallet.available_minor

    credited = CashoutExecutionService.execute!(bet: @bet, actor: @user)

    assert_equal 1980, credited
    @bet.reload
    assert_predicate @bet, :voided?

    @user.wallet.reload
    assert_equal initial_balance + 1980, @user.wallet.available_minor

    assert LedgerEntry.where(user: @user, entry_type: "BET_CASHOUT_PAYOUT", direction: "credit", amount_minor: 1980).exists?
    assert LedgerEntry.where(user: @user, entry_type: "BET_CASHOUT_FEE", direction: "debit", amount_minor: 20).exists?
    assert AuditEvent.where(action: "bet.cashout", target_type: "Bet", target_id: @bet.id).exists?
  end

  test "skips fee ledger entry when fee is zero" do
    @market.update!(fee_bps: 0)
    CashoutExecutionService.execute!(bet: @bet.reload, actor: @user)
    assert_not LedgerEntry.where(user: @user, entry_type: "BET_CASHOUT_FEE").exists?
  end

  test "raises InvalidPosition when bet is already voided" do
    @bet.update!(status: :voided)
    assert_raises(CashoutExecutionService::InvalidPosition) do
      CashoutExecutionService.execute!(bet: @bet, actor: @user)
    end
  end

  test "raises InvalidPosition when bet is settled" do
    @bet.update!(status: :settled_win)
    assert_raises(CashoutExecutionService::InvalidPosition) do
      CashoutExecutionService.execute!(bet: @bet, actor: @user)
    end
  end
end
```

- [ ] **Step 5.2: Run tests to verify they fail**

```bash
bin/rails test test/services/cashout_quote_service_test.rb test/services/cashout_execution_service_test.rb -v
```
Expected: FAIL with `uninitialized constant`.

- [ ] **Step 5.3: Implement CashoutQuoteService**

`app/services/cashout_quote_service.rb`:
```ruby
class CashoutQuoteService
  class InvalidPosition < StandardError; end

  Quote = Struct.new(:bet_id, :gross_payout_minor, :fee_minor, :net_payout_minor, :expires_at, keyword_init: true)

  TTL_SECONDS = 60

  def self.quote(bet:)
    raise InvalidPosition, "Bet is not open" unless bet.open?
    raise InvalidPosition, "Market is not open" unless bet.market.open?

    gross = (bet.stake_minor * bet.market_leg.odds_minor / 10_000.0).floor
    fee = (gross * bet.market.fee_bps / 10_000.0).ceil
    net = gross - fee

    Quote.new(
      bet_id: bet.id,
      gross_payout_minor: gross,
      fee_minor: fee,
      net_payout_minor: net,
      expires_at: Time.current + TTL_SECONDS.seconds
    )
  end
end
```

- [ ] **Step 5.4: Implement CashoutExecutionService**

`app/services/cashout_execution_service.rb`:
```ruby
class CashoutExecutionService
  class InvalidPosition < StandardError; end

  def self.execute!(bet:, actor:)
    ApplicationRecord.transaction do
      locked_bet = Bet.lock.find(bet.id)
      raise InvalidPosition, "Bet is not open" unless locked_bet.open?
      raise InvalidPosition, "Market is not open" unless locked_bet.market.open?

      quote = CashoutQuoteService.quote(bet: locked_bet)

      wallet = locked_bet.user.wallet
      wallet.update!(available_minor: wallet.available_minor + quote.net_payout_minor)

      locked_bet.update!(status: :voided)

      LedgerEntry.create!(
        user: locked_bet.user,
        actor: actor,
        entry_type: "BET_CASHOUT_PAYOUT",
        amount_minor: quote.net_payout_minor,
        direction: "credit",
        metadata: { bet_id: locked_bet.id, market_id: locked_bet.market_id }
      )

      if quote.fee_minor.positive?
        LedgerEntry.create!(
          user: locked_bet.user,
          actor: actor,
          entry_type: "BET_CASHOUT_FEE",
          amount_minor: quote.fee_minor,
          direction: "debit",
          metadata: { bet_id: locked_bet.id, market_id: locked_bet.market_id }
        )
      end

      AuditEvent.create!(
        actor: actor,
        action: "bet.cashout",
        target_type: "Bet",
        target_id: locked_bet.id,
        metadata: {
          bet_id: locked_bet.id,
          net_payout_minor: quote.net_payout_minor,
          fee_minor: quote.fee_minor
        }
      )

      quote.net_payout_minor
    end
  end
end
```

- [ ] **Step 5.5: Run tests to verify they pass**

```bash
bin/rails test test/services/cashout_quote_service_test.rb test/services/cashout_execution_service_test.rb -v
```
Expected: 7 tests, all green.

- [ ] **Step 5.6: Commit**

```bash
git add app/services/cashout_quote_service.rb app/services/cashout_execution_service.rb \
        test/services/cashout_quote_service_test.rb test/services/cashout_execution_service_test.rb
git commit -m "$(cat <<'EOF'
feat(betslip): add CashoutQuoteService and CashoutExecutionService

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Routes + controllers + integration tests

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/web/betslips_controller.rb`
- Create: `app/controllers/web/betslip_executions_controller.rb`
- Create: `app/controllers/web/positions_controller.rb`
- Create: `test/integration/web_betslip_test.rb`

- [ ] **Step 6.1: Write the failing integration test first**

`test/integration/web_betslip_test.rb`:
```ruby
require "test_helper"

class WebBetslipTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player)
    @user.wallet.update!(available_minor: 100_000)
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
    @market.bets.delete_all

    post "/signin", params: { email: @user.email, password: "password123" }
  end

  test "quote then execute happy path" do
    post "/web/betslips/quotes", params: {
      items: [
        { market_leg_id: @yes_leg.id, stake_minor: 500 },
        { market_leg_id: @no_leg.id, stake_minor: 1000 }
      ],
      idempotency_key: "happy-1"
    }, as: :json
    assert_response :success
    quote_id = response.parsed_body["quote_id"]
    assert_equal 1500, response.parsed_body["total_stake_minor"]

    post "/web/betslips/execute", params: { quote_id: quote_id }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "completed", body["status"]
    assert_equal 2, body["bet_ids"].length

    get "/web/betslips/executions/#{body['execution_id']}"
    assert_response :success
    assert_equal body["bet_ids"], response.parsed_body["bet_ids"]
  end

  test "idempotency replay returns same quote" do
    payload = {
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: "replay-int"
    }
    post "/web/betslips/quotes", params: payload, as: :json
    id1 = response.parsed_body["quote_id"]

    post "/web/betslips/quotes", params: payload, as: :json
    assert_response :success
    assert_equal id1, response.parsed_body["quote_id"]
  end

  test "idempotency conflict returns 409" do
    post "/web/betslips/quotes", params: {
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: "conflict-int"
    }, as: :json
    assert_response :success

    post "/web/betslips/quotes", params: {
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 999 }],
      idempotency_key: "conflict-int"
    }, as: :json
    assert_response :conflict
  end

  test "expired quote returns 422 on execute" do
    post "/web/betslips/quotes", params: {
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: "expired-int"
    }, as: :json
    quote_id = response.parsed_body["quote_id"]
    BetslipQuote.find(quote_id).update_column(:expires_at, 1.second.ago)

    initial_balance = @user.wallet.reload.available_minor
    post "/web/betslips/execute", params: { quote_id: quote_id }, as: :json
    assert_response :unprocessable_entity
    assert_equal initial_balance, @user.wallet.reload.available_minor
  end

  test "positions index returns only current user's open bets" do
    bet = Bet.create!(
      user: @user, market: @market, market_leg: @yes_leg,
      stake_minor: 1000, fee_minor: 10, net_stake_minor: 990,
      odds_minor: @yes_leg.odds_minor, potential_payout_minor: 2000, status: :open
    )

    get "/web/positions"
    assert_response :success
    ids = response.parsed_body["positions"].map { |p| p["bet_id"] }
    assert_includes ids, bet.id
  end

  test "cashout quote then execute credits wallet and voids bet" do
    @market.update!(fee_bps: 100)
    @yes_leg.update!(odds_minor: 20_000)
    bet = Bet.create!(
      user: @user, market: @market, market_leg: @yes_leg,
      stake_minor: 1000, fee_minor: 10, net_stake_minor: 990,
      odds_minor: @yes_leg.odds_minor, potential_payout_minor: 2000, status: :open
    )

    post "/web/positions/cashout_quotes", params: { bet_id: bet.id }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal 2000, body["gross_payout_minor"]
    assert_equal 20, body["fee_minor"]
    assert_equal 1980, body["net_payout_minor"]

    initial_balance = @user.wallet.reload.available_minor
    post "/web/positions/cashout_execute", params: { bet_id: bet.id }, as: :json
    assert_response :success
    assert_equal "completed", response.parsed_body["status"]
    assert_equal 1980, response.parsed_body["credited_minor"]
    assert_equal initial_balance + 1980, @user.wallet.reload.available_minor
    assert_predicate bet.reload, :voided?
  end

  test "cashout on non-open bet returns 422" do
    bet = Bet.create!(
      user: @user, market: @market, market_leg: @yes_leg,
      stake_minor: 1000, fee_minor: 10, net_stake_minor: 990,
      odds_minor: @yes_leg.odds_minor, potential_payout_minor: 2000, status: :voided
    )
    post "/web/positions/cashout_execute", params: { bet_id: bet.id }, as: :json
    assert_response :unprocessable_entity
  end

  test "execution show 404 for another user's execution" do
    quote = BetslipQuote.create!(
      user: users(:moderator),
      idempotency_key: "other-user",
      items: [],
      total_stake_minor: 0,
      expires_at: 60.seconds.from_now
    )
    execution = BetslipExecution.create!(
      betslip_quote: quote, user: users(:moderator), bet_ids: [], status: :completed
    )
    get "/web/betslips/executions/#{execution.id}"
    assert_response :not_found
  end
end
```

- [ ] **Step 6.2: Run test to verify it fails**

```bash
bin/rails test test/integration/web_betslip_test.rb -v
```
Expected: FAIL with `No route matches` errors.

- [ ] **Step 6.3: Add routes**

Edit `config/routes.rb` — extend `namespace :web` block:
```ruby
  namespace :web do
    resources :markets, only: [:index, :show]

    resources :betslips, only: [] do
      collection do
        post :quotes
        post :execute
      end
    end
    resources :betslip_executions, only: [:show], path: "betslips/executions"

    resources :positions, only: [:index] do
      collection do
        post :cashout_quotes
        post :cashout_execute
      end
    end
  end
```

- [ ] **Step 6.4: Implement betslips controller**

`app/controllers/web/betslips_controller.rb`:
```ruby
module Web
  class BetslipsController < BaseController
    before_action :require_player!

    def quotes
      quote = BetslipQuoteService.call(
        user: current_user,
        items: items_param,
        idempotency_key: params[:idempotency_key].to_s
      )
      render json: serialize_quote(quote)
    rescue BetslipQuoteService::Conflict => e
      render json: { error: e.message }, status: :conflict
    rescue BetslipQuoteService::InvalidQuote => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def execute
      quote = BetslipQuote.where(user_id: current_user.id).find(params[:quote_id])
      execution = BetslipExecutionService.execute!(quote: quote, actor: current_user)
      render json: {
        execution_id: execution.id,
        bet_ids: execution.bet_ids,
        status: execution.status
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Quote not found" }, status: :not_found
    rescue BetslipExecutionService::ExpiredQuote,
           BetslipExecutionService::AlreadyExecuted,
           BetslipExecutionService::ExecutionFailed => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def items_param
      raw = params[:items]
      raw = raw.values if raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)
      Array(raw).map do |item|
        h = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
        { market_leg_id: h[:market_leg_id] || h["market_leg_id"], stake_minor: h[:stake_minor] || h["stake_minor"] }
      end
    end

    def require_player!
      render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
    end

    def serialize_quote(quote)
      {
        quote_id: quote.id,
        items: quote.items,
        total_stake_minor: quote.total_stake_minor,
        expires_at: quote.expires_at.iso8601
      }
    end
  end
end
```

- [ ] **Step 6.5: Implement betslip executions controller**

`app/controllers/web/betslip_executions_controller.rb`:
```ruby
module Web
  class BetslipExecutionsController < BaseController
    def show
      execution = BetslipExecution.where(user_id: current_user.id).find(params[:id])
      render json: {
        execution_id: execution.id,
        quote_id: execution.betslip_quote_id,
        bet_ids: execution.bet_ids,
        status: execution.status
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Execution not found" }, status: :not_found
    end
  end
end
```

- [ ] **Step 6.6: Implement positions controller**

`app/controllers/web/positions_controller.rb`:
```ruby
module Web
  class PositionsController < BaseController
    def index
      bets = Bet.includes(:market, :market_leg)
                .where(user_id: current_user.id, status: :open)
                .order(created_at: :desc)
      render json: { positions: bets.map { |b| serialize_position(b) } }
    end

    def cashout_quotes
      bet = current_user_bet
      quote = CashoutQuoteService.quote(bet: bet)
      render json: {
        bet_id: quote.bet_id,
        gross_payout_minor: quote.gross_payout_minor,
        fee_minor: quote.fee_minor,
        net_payout_minor: quote.net_payout_minor,
        expires_at: quote.expires_at.iso8601
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Bet not found" }, status: :not_found
    rescue CashoutQuoteService::InvalidPosition => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def cashout_execute
      bet = current_user_bet
      credited = CashoutExecutionService.execute!(bet: bet, actor: current_user)
      render json: { status: "completed", credited_minor: credited }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Bet not found" }, status: :not_found
    rescue CashoutExecutionService::InvalidPosition, CashoutQuoteService::InvalidPosition => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def current_user_bet
      Bet.where(user_id: current_user.id).find(params[:bet_id])
    end

    def serialize_position(bet)
      {
        bet_id: bet.id,
        market_id: bet.market_id,
        market_question: bet.market.question,
        market_leg_id: bet.market_leg_id,
        leg_label: bet.market_leg.label,
        stake_minor: bet.stake_minor,
        odds_minor: bet.odds_minor,
        potential_payout_minor: bet.potential_payout_minor,
        status: bet.status
      }
    end
  end
end
```

- [ ] **Step 6.7: Run integration tests to verify they pass**

```bash
bin/rails test test/integration/web_betslip_test.rb -v
```
Expected: 8 tests, all green.

- [ ] **Step 6.8: Run full suite to confirm no regression**

```bash
bin/rails test
```
Expected: all tests pass, SimpleCov ≥ 90%.

- [ ] **Step 6.9: Commit**

```bash
git add config/routes.rb \
        app/controllers/web/betslips_controller.rb \
        app/controllers/web/betslip_executions_controller.rb \
        app/controllers/web/positions_controller.rb \
        test/integration/web_betslip_test.rb
git commit -m "$(cat <<'EOF'
feat(betslip): add web betslip and positions routes and controllers

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Update docs

- [ ] Append a dated entry to `docs/WORK_LOG.md` summarising the betslip + cashout feature, key files, and commit hashes.
- [ ] Update `docs/INDEX.md`: move **PLAN-B Betslip + cashout** from the ⏳ Next section to ✅ Done with the most recent commit hash.
- [ ] Commit:

```bash
git add docs/INDEX.md docs/WORK_LOG.md
git commit -m "$(cat <<'EOF'
docs: update INDEX and WORK_LOG after betslip+cashout

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist
- [ ] Every spec invariant has a test (TTL expiry, idempotency replay, idempotency conflict, all-or-nothing, single execution, cashout math, ledger writes, audit events).
- [ ] Every write action has an `AuditEvent` (`betslip.execute`, `bet.cashout`); per-bet `bet.place` events are produced by `BetPlacementService`.
- [ ] Every ledger write uses the correct `entry_type` and direction (`BET_STAKE` debit via `BetPlacementService`, `BET_CASHOUT_PAYOUT` credit, `BET_CASHOUT_FEE` debit).
- [ ] No double-debit: betslip layer delegates stake deduction to `BetPlacementService`.
- [ ] Full test suite passes: `bin/rails test`.
- [ ] No placeholder steps remain.
