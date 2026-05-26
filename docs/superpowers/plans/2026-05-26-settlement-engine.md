# Settlement Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a market is settled, automatically transition all open bets to WON or LOST, credit payout ledger entries to winners, and project the updated market state to hot storage — completing the betting loop that currently leaves bets stuck in "open" after settlement.

**Architecture:** `SettlementService.settle!` is the single entry point. It wraps everything in a transaction: updates market status, transitions each open bet, writes ledger entries for winners, creates audit events, then projects hot storage. Both `Admin::MarketsController#settle` (JSON API) and `Backoffice::MarketsController#settle` (HTML) call this service.

**Tech Stack:** Rails 8, ActiveRecord transactions, existing `HotStorage::MarketSnapshotProjector`, `HotStorage::Store`, `LedgerEntry`, `AuditEvent`, Minitest.

---

## File Map

**Create:**
- `app/services/settlement_service.rb`
- `test/services/settlement_service_test.rb`
- `test/fixtures/bets.yml` — may need open bets on open_market

**Modify:**
- `app/controllers/admin/markets_controller.rb` — replace inline settle logic with `SettlementService.settle!`
- `test/integration/admin_market_risk_test.rb` — add settlement integration test

---

## Task 1: SettlementService

**Files:**
- Create: `app/services/settlement_service.rb`

- [ ] **Step 1.1: Write the failing test first**

Create `test/services/settlement_service_test.rb`:
```ruby
require "test_helper"

class SettlementServiceTest < ActiveSupport::TestCase
  setup do
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
    @actor = users(:admin)

    @winner_user = users(:player)
    @winner_user.create_wallet!(available_minor: 10_000, reserved_minor: 0) unless @winner_user.wallet
    @loser_user = users(:moderator)
    @loser_user.create_wallet!(available_minor: 10_000, reserved_minor: 0) unless @loser_user.wallet

    @winner_bet = Bet.create!(
      user: @winner_user,
      market: @market,
      market_leg: @yes_leg,
      stake_minor: 1000,
      fee_minor: 10,
      net_stake_minor: 990,
      odds_minor: 5000,
      potential_payout_minor: 5000,
      status: :open
    )
    @loser_bet = Bet.create!(
      user: @loser_user,
      market: @market,
      market_leg: @no_leg,
      stake_minor: 1000,
      fee_minor: 10,
      net_stake_minor: 990,
      odds_minor: 5000,
      potential_payout_minor: 5000,
      status: :open
    )
  end

  test "settles market and transitions bets" do
    SettlementService.settle!(market: @market, outcome: "YES", actor: @actor)

    @market.reload
    assert_predicate @market, :settled?
    assert_equal "YES", @market.settled_outcome

    @winner_bet.reload
    assert_predicate @winner_bet, :settled_win?

    @loser_bet.reload
    assert_predicate @loser_bet, :settled_loss?
  end

  test "credits payout to winner wallet" do
    initial_balance = @winner_user.wallet.available_minor

    SettlementService.settle!(market: @market, outcome: "YES", actor: @actor)

    @winner_user.wallet.reload
    assert_equal initial_balance + @winner_bet.potential_payout_minor, @winner_user.wallet.available_minor
  end

  test "does not change loser wallet on settlement" do
    initial_balance = @loser_user.wallet.available_minor

    SettlementService.settle!(market: @market, outcome: "YES", actor: @actor)

    @loser_user.wallet.reload
    assert_equal initial_balance, @loser_user.wallet.available_minor
  end

  test "creates ledger entry for each winner" do
    assert_difference("LedgerEntry.where(entry_type: 'BET_WIN_PAYOUT').count", 1) do
      SettlementService.settle!(market: @market, outcome: "YES", actor: @actor)
    end
  end

  test "creates audit events for market settle and each bet" do
    assert_difference("AuditEvent.count", 3) do
      SettlementService.settle!(market: @market, outcome: "YES", actor: @actor)
    end
  end

  test "raises on invalid outcome" do
    assert_raises(SettlementService::InvalidSettlement) do
      SettlementService.settle!(market: @market, outcome: "DRAW", actor: @actor)
    end
  end

  test "raises if market is not open" do
    @market.update!(status: :draft)
    assert_raises(SettlementService::InvalidSettlement) do
      SettlementService.settle!(market: @market, outcome: "YES", actor: @actor)
    end
  end

  test "skips already-settled or voided bets" do
    @loser_bet.update!(status: :voided)

    assert_nothing_raised do
      SettlementService.settle!(market: @market, outcome: "YES", actor: @actor)
    end

    @loser_bet.reload
    assert_predicate @loser_bet, :voided?
  end
end
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
bin/rails test test/services/settlement_service_test.rb -v 2>&1 | head -20
```
Expected: FAIL with `uninitialized constant SettlementService`.

- [ ] **Step 1.3: Implement SettlementService**

Create `app/services/settlement_service.rb`:
```ruby
class SettlementService
  class InvalidSettlement < StandardError; end

  def self.settle!(market:, outcome:, actor:)
    raise InvalidSettlement, "Market must be open to settle" unless market.open?

    valid_labels = market.market_legs.pluck(:label)
    raise InvalidSettlement, "Invalid outcome: #{outcome}. Valid: #{valid_labels.join(', ')}" unless valid_labels.include?(outcome)

    ApplicationRecord.transaction do
      market.update!(status: :settled, settled_outcome: outcome, settled_by: actor)

      open_bets = market.bets.where(status: :open).includes(:user => :wallet, :market_leg => [])

      open_bets.each do |bet|
        if bet.market_leg.label == outcome
          bet.update!(status: :settled_win)

          wallet = bet.user.wallet
          wallet.update!(available_minor: wallet.available_minor + bet.potential_payout_minor)

          LedgerEntry.create!(
            user: bet.user,
            actor: actor,
            entry_type: "BET_WIN_PAYOUT",
            amount_minor: bet.potential_payout_minor,
            direction: "credit",
            metadata: { bet_id: bet.id, market_id: market.id, outcome: outcome }
          )

          AuditEvent.create!(
            actor: actor,
            action: "bet.settle_win",
            target_type: "Bet",
            target_id: bet.id,
            metadata: { market_id: market.id, outcome: outcome, payout_minor: bet.potential_payout_minor }
          )
        else
          bet.update!(status: :settled_loss)

          AuditEvent.create!(
            actor: actor,
            action: "bet.settle_loss",
            target_type: "Bet",
            target_id: bet.id,
            metadata: { market_id: market.id, outcome: outcome }
          )
        end
      end

      AuditEvent.create!(
        actor: actor,
        action: "market.settle",
        target_type: "Market",
        target_id: market.id,
        metadata: { outcome: outcome, bets_settled: open_bets.size }
      )

      HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: "market.settle")
      HotStorage::Store.current.append_market_event!(
        market_id: market.id,
        event_name: "market.settled.v1",
        payload: { market_id: market.id, outcome: outcome, actor_id: actor.id },
        version: (market.updated_at.to_f * 1000).to_i
      )
    end

    market
  end
end
```

- [ ] **Step 1.4: Run tests**

```bash
bin/rails test test/services/settlement_service_test.rb -v
```
Expected: all tests PASS.

- [ ] **Step 1.5: Commit**

```bash
git add app/services/settlement_service.rb test/services/settlement_service_test.rb
git commit -m "feat(settlement): add SettlementService with bet payout and ledger on market settle"
```

---

## Task 2: Wire SettlementService into Admin::MarketsController

**Files:**
- Modify: `app/controllers/admin/markets_controller.rb`

- [ ] **Step 2.1: Replace inline settle logic**

In `app/controllers/admin/markets_controller.rb`, replace the entire `settle` action:

```ruby
def settle
  require_permission!("market.settle")
  return if performed?

  market = Market.find(params[:id])
  outcome = params[:outcome].to_s.upcase

  market = SettlementService.settle!(market: market, outcome: outcome, actor: current_user)
  render json: { id: market.id, status: market.status, settled_outcome: market.settled_outcome }
rescue SettlementService::InvalidSettlement => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

Also remove the `AuditEvent.create!` and `HotStorage::MarketSnapshotProjector.project!` calls that were previously inside settle (they are now in the service).

- [ ] **Step 2.2: Run admin market tests**

```bash
bin/rails test test/integration/admin_market_risk_test.rb -v
```
Expected: PASS.

- [ ] **Step 2.3: Add a settlement integration test**

Append to `test/integration/admin_market_risk_test.rb` (or create `test/integration/admin_market_settle_test.rb`):

```ruby
require "test_helper"

class AdminMarketSettleTest < ActionDispatch::IntegrationTest
  setup do
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @player = users(:player)
    @player.create_wallet!(available_minor: 10_000, reserved_minor: 0) unless @player.wallet

    @bet = Bet.create!(
      user: @player,
      market: @market,
      market_leg: @yes_leg,
      stake_minor: 1000,
      fee_minor: 10,
      net_stake_minor: 990,
      odds_minor: 5000,
      potential_payout_minor: 5000,
      status: :open
    )
  end

  test "admin can settle market via API and bets are transitioned" do
    token = JsonWebToken.encode(user_id: users(:admin).id)

    post "/admin/markets/#{@market.id}/settle",
      params: { outcome: "YES", reason: "verified" },
      headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    assert_equal "settled", JSON.parse(response.body)["status"]
    assert_equal "YES", JSON.parse(response.body)["settled_outcome"]

    @bet.reload
    assert_predicate @bet, :settled_win?

    @player.wallet.reload
    assert_equal 15_000, @player.wallet.available_minor
  end

  test "invalid outcome returns error" do
    token = JsonWebToken.encode(user_id: users(:admin).id)

    post "/admin/markets/#{@market.id}/settle",
      params: { outcome: "MAYBE" },
      headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unprocessable_entity
    assert_match "Invalid outcome", JSON.parse(response.body)["error"]
  end
end
```

- [ ] **Step 2.4: Run settlement integration test**

```bash
bin/rails test test/integration/admin_market_settle_test.rb -v
```
Expected: PASS.

- [ ] **Step 2.5: Run full test suite**

```bash
bin/rails test -v 2>&1 | tail -20
```
Expected: no failures.

- [ ] **Step 2.6: Commit**

```bash
git add app/controllers/admin/markets_controller.rb test/integration/admin_market_settle_test.rb
git commit -m "feat(admin): wire SettlementService into market settle endpoint"
```

---

## Self-Review Checklist

- [x] SettlementService raises on non-open market
- [x] SettlementService raises on invalid outcome label
- [x] Winners get `settled_win` + payout credited to wallet
- [x] Losers get `settled_loss` + no wallet change
- [x] Already-voided/settled bets are skipped (where(status: :open) filter)
- [x] LedgerEntry written per winner with BET_WIN_PAYOUT type
- [x] AuditEvent written per bet + one for market
- [x] Hot storage projected after settlement
- [x] Admin JSON API uses the service (no duplicate logic)
- [x] Backoffice HTML controller uses `defined?(SettlementService)` guard (will auto-upgrade when service exists)
- [x] Integration test verifies wallet balance after settlement
