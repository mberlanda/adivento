require 'test_helper'

module Clob
  class OperatorBuybackServiceTest < ActiveSupport::TestCase
    setup do
      @market   = markets(:clob_market)
      @operator = users(:admin)
      @operator.wallet.update!(available_minor: 1_000_000, reserved_minor: 0)
    end

    test 'fails when order book has no prices' do
      result = OperatorBuybackService.call(market: @market, operator: @operator, side: 'YES', contracts: 10)

      assert_not result.success?
      assert_includes result.errors.first, 'mid-price'
    end

    test 'places a buy order at mid-price when book has both sides' do
      leg_yes = @market.market_legs.find_by!(label: 'YES')
      leg_no  = @market.market_legs.find_by!(label: 'NO')
      player  = users(:player)
      player.wallet.update!(available_minor: 500_000, reserved_minor: 0)

      # bid = 60¢ YES, ask = 40¢ NO → mid = (60 + 40) / 2 = 50¢ for YES side
      Order.create!(market: @market, market_leg: leg_yes, user: player,
                    side: 'YES', direction: 'buy', price_cents: 60,
                    quantity: 5, status: :open, time_in_force: :gtc)
      player.wallet.update!(reserved_minor: 300, available_minor: 499_700)

      Order.create!(market: @market, market_leg: leg_no, user: player,
                    side: 'NO', direction: 'buy', price_cents: 40,
                    quantity: 5, status: :open, time_in_force: :gtc)
      player.wallet.update!(reserved_minor: 500, available_minor: 499_500)

      result = OperatorBuybackService.call(market: @market, operator: @operator, side: 'YES', contracts: 10)

      assert_predicate result, :success?
      assert_equal 1, result.orders.size
      assert_equal 'YES', result.orders.first.side
      assert_equal 'buy', result.orders.first.direction
    end

    test 'fails on non-CLOB market' do
      result = OperatorBuybackService.call(market: markets(:lmsr_market), operator: @operator, side: 'YES', contracts: 10)

      assert_not result.success?
    end
  end
end
