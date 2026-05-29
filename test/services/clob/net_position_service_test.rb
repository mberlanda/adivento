require 'test_helper'

module Clob
  class NetPositionServiceTest < ActiveSupport::TestCase
    setup do
      @market = markets(:clob_market)
      @player = users(:player)
      @leg    = @market.market_legs.find_by!(label: 'YES')
    end

    test 'returns zero when no orders' do
      assert_equal 0, NetPositionService.call(user: @player, market: @market, side: 'YES')
    end

    test 'counts filled buy orders' do
      Order.create!(market: @market, market_leg: @leg, user: @player,
                    side: 'YES', direction: 'buy', price_cents: 60,
                    quantity: 10, filled_quantity: 10, status: :filled, time_in_force: :gtc)

      assert_equal 10, NetPositionService.call(user: @player, market: @market, side: 'YES')
    end

    test 'subtracts filled sell orders' do
      Order.create!(market: @market, market_leg: @leg, user: @player,
                    side: 'YES', direction: 'buy', price_cents: 60,
                    quantity: 10, filled_quantity: 10, status: :filled, time_in_force: :gtc)
      Order.create!(market: @market, market_leg: @leg, user: @player,
                    side: 'YES', direction: 'sell', price_cents: 65,
                    quantity: 4, filled_quantity: 4, status: :filled, time_in_force: :gtc)

      assert_equal 6, NetPositionService.call(user: @player, market: @market, side: 'YES')
    end

    test 'ignores unfilled orders' do
      Order.create!(market: @market, market_leg: @leg, user: @player,
                    side: 'YES', direction: 'buy', price_cents: 60,
                    quantity: 10, filled_quantity: 3, status: :partial, time_in_force: :gtc)

      assert_equal 3, NetPositionService.call(user: @player, market: @market, side: 'YES')
    end
  end
end
