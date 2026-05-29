require 'test_helper'

module Settlement
  class ClobSettlementHandlerTest < ActiveSupport::TestCase
    setup do
      @market = markets(:clob_market)
      @market.update!(status: :open)
      @yes_leg = @market.market_legs.find_by!(label: 'YES')
      @actor = users(:admin)

      # Seller acquired 10 YES then sold all 10 → net 0 YES.
      @seller = users(:player)
      # Buyer acquired those 10 YES via the sell fill → net 10 YES.
      @buyer = users(:moderator)
      @seller.wallet.update!(available_minor: 0, reserved_minor: 0)
      @buyer.wallet.update!(available_minor: 0, reserved_minor: 0)

      # Seller's original filled buy (acquired 10 YES)
      Order.create!(
        market: @market, market_leg: @yes_leg, user: @seller,
        side: 'YES', direction: 'buy', price_cents: 60, quantity: 10,
        status: :filled, filled_quantity: 10, time_in_force: :gtc
      )
      # Seller's filled sell (exited all 10 YES)
      Order.create!(
        market: @market, market_leg: @yes_leg, user: @seller,
        side: 'YES', direction: 'sell', price_cents: 65, quantity: 10,
        status: :filled, filled_quantity: 10, time_in_force: :gtc
      )
      # Buyer's filled buy that absorbed the sell (acquired 10 YES)
      Order.create!(
        market: @market, market_leg: @yes_leg, user: @buyer,
        side: 'YES', direction: 'buy', price_cents: 65, quantity: 10,
        status: :filled, filled_quantity: 10, time_in_force: :gtc
      )
    end

    test 'pays each holder for net long contracts, not gross filled orders' do
      Settlement::ClobSettlementHandler.new(@market, 'YES', @actor).call

      # Seller exited (net 0 YES) → no settlement payout.
      assert_equal 0, @seller.wallet.reload.available_minor
      # Buyer holds net 10 YES → 10 × 100 = 1000.
      assert_equal 1000, @buyer.wallet.reload.available_minor
    end

    test 'writes no SETTLEMENT_WIN entry for a holder with zero net position' do
      Settlement::ClobSettlementHandler.new(@market, 'YES', @actor).call

      assert_equal 0,
                   LedgerEntry.where(user: @seller, entry_type: 'SETTLEMENT_WIN').count
      assert_equal 1,
                   LedgerEntry.where(user: @buyer, entry_type: 'SETTLEMENT_WIN').count
    end
  end
end
