require 'test_helper'

class MarketCancellationServiceTest < ActiveSupport::TestCase
  setup { @actor = users(:admin) }

  test 'cancels an open market and writes one market.cancel audit event' do
    market = markets(:open_market)
    assert_difference -> { AuditEvent.where(action: 'market.cancel', target_id: market.id).count }, 1 do
      result = MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')

      assert_predicate result, :success?
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

  test 'fixed_odds refunds each open bet stake and voids the bet' do
    market = markets(:open_market)
    market.bets.delete_all
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

  test 'parimutuel refunds every stake and resets pools' do
    market = markets(:parimutuel_market)
    user = users(:player)
    user.wallet.update!(available_minor: 5000)
    Parimutuel::ParimutuelPoolService.add_stake(market: market, user: user, side: 'YES', stake_minor: 2000)

    MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')

    assert_equal 5000, user.wallet.reload.available_minor
    assert_equal 0, market.reload.parimutuel_pool_yes_minor
    assert_equal 0, market.parimutuel_pool_no_minor
  end

  test 'lmsr refunds each trader cost and zeroes positions' do
    market = markets(:lmsr_market)
    user = users(:player)
    user.wallet.update!(available_minor: 100_000)
    before = user.wallet.available_minor
    Lmsr::LmsrTradeService.call(market: market, user: user, side: 'YES', quantity: 5)
    spent = before - user.wallet.reload.available_minor

    assert_predicate spent, :positive?

    MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')

    refunded = LedgerEntry.where(user: user, entry_type: 'MARKET_CANCEL_REFUND').sum(:amount_minor)
    staked = LedgerEntry.where(user: user, entry_type: 'LMSR_TRADE_STAKE').sum(:amount_minor)

    assert_equal staked, refunded
    assert_equal 0, LmsrPosition.for_market(market).where(user: user).sum(:contracts)
  end

  test 'clob releases open-order reservations on cancel' do
    market = markets(:clob_market)
    buyer = users(:player)
    buyer.wallet.update!(available_minor: 500_000, reserved_minor: 0)
    Clob::OrderMatchingService.call(market: market, incoming_order_params: {
                                      user: buyer, side: 'YES', price_cents: 40, quantity: 5,
                                      market_leg: market.market_legs.find_by!(label: 'YES'), time_in_force: :gtc
                                    })

    assert_operator buyer.wallet.reload.reserved_minor, :>, 0

    MarketCancellationService.call(market: market, actor: @actor, reason: 'Event was abandoned.')

    assert_equal 0, buyer.wallet.reload.reserved_minor
    assert_predicate market.reload.orders.where(status: %w[open partial]), :none?
  end
end
