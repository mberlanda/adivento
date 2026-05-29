require 'test_helper'

module Clob
  class ClobCashoutServiceTest < ActiveSupport::TestCase
    setup do
      @market = markets(:clob_market)
      @player = users(:player)
      @player.wallet.update!(available_minor: 500_000, reserved_minor: 0)
      @leg = @market.market_legs.find_by!(label: 'YES')
      # Give player 10 filled YES contracts
      Order.create!(market: @market, market_leg: @leg, user: @player,
                    side: 'YES', direction: 'buy', price_cents: 60,
                    quantity: 10, filled_quantity: 10, status: :filled, time_in_force: :gtc)
    end

    test 'fails when player has no position' do
      other = users(:moderator)
      result = ClobCashoutService.call(market: @market, user: other, side: 'YES', contracts: 5, price_cents: 65)

      assert_not result.success?
      assert_includes result.errors.first, 'Insufficient position'
    end

    test 'fails when contracts is zero' do
      result = ClobCashoutService.call(market: @market, user: @player, side: 'YES', contracts: 0, price_cents: 65)

      assert_not result.success?
    end

    test 'places a sell limit order when position is sufficient' do
      result = ClobCashoutService.call(market: @market, user: @player, side: 'YES', contracts: 5, price_cents: 65)

      assert_predicate result, :success?
      assert_not_nil result.order
      assert_equal 'sell', result.order.direction
      assert_equal 'YES', result.order.side
      assert_equal 5, result.order.quantity
    end

    test 'fails on non-CLOB market' do
      result = ClobCashoutService.call(market: markets(:lmsr_market), user: @player, side: 'YES', contracts: 5, price_cents: 65)

      assert_not result.success?
    end
  end
end
