require 'test_helper'

module Clob
  class OrderMatchingServiceTest < ActiveSupport::TestCase
    setup do
      @market = markets(:clob_market)
      @buyer  = users(:player)
      @seller = users(:moderator)
      @buyer.wallet.update!(available_minor: 500_000, reserved_minor: 0)
      @seller.wallet.update!(available_minor: 500_000, reserved_minor: 0)
    end

    test 'YES bid matches NO bid when P + Q >= 100 at maker price' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')
      no_leg  = @market.market_legs.find_by!(label: 'NO')

      seller_order = Order.create!(
        market: @market, market_leg: no_leg, user: @seller,
        side: 'NO', price_cents: 60, quantity: 5,
        status: :open, time_in_force: :gtc
      )
      @seller.wallet.update!(available_minor: 500_000 - 300, reserved_minor: 300)

      result = Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @buyer, side: 'YES', price_cents: 40, quantity: 5,
          market_leg: yes_leg, time_in_force: :gtc
        }
      )

      assert_predicate result, :success?
      assert_equal 'filled', result.incoming_order.status
      assert_equal 5, result.incoming_order.filled_quantity
      seller_order.reload

      assert_equal 'filled', seller_order.status
    end

    test 'partial fill: incoming order fills partially when only fewer resting contracts available' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')
      no_leg  = @market.market_legs.find_by!(label: 'NO')

      Order.create!(
        market: @market, market_leg: no_leg, user: @seller,
        side: 'NO', price_cents: 60, quantity: 3,
        status: :open, time_in_force: :gtc
      )
      @seller.wallet.update!(available_minor: 500_000 - 180, reserved_minor: 180)

      result = Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @buyer, side: 'YES', price_cents: 40, quantity: 5,
          market_leg: yes_leg, time_in_force: :gtc
        }
      )

      assert_predicate result, :success?
      assert_equal 'partial', result.incoming_order.status
      assert_equal 3, result.incoming_order.filled_quantity
      assert_equal 2, result.incoming_order.unfilled_quantity
    end

    test 'IOC order: unfilled remainder cancelled after one pass' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')

      result = Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @buyer, side: 'YES', price_cents: 40, quantity: 5,
          market_leg: yes_leg, time_in_force: :ioc
        }
      )

      assert_predicate result, :success?
      assert_equal 'cancelled', result.incoming_order.status
    end

    test 'FOK order: entire order cancelled if full quantity not available' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')
      no_leg  = @market.market_legs.find_by!(label: 'NO')

      Order.create!(
        market: @market, market_leg: no_leg, user: @seller,
        side: 'NO', price_cents: 60, quantity: 3,
        status: :open, time_in_force: :gtc
      )

      result = Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @buyer, side: 'YES', price_cents: 40, quantity: 5,
          market_leg: yes_leg, time_in_force: :fok
        }
      )

      assert_predicate result, :success?
      assert_equal 'cancelled', result.incoming_order.status
      assert_equal 0, result.incoming_order.filled_quantity
    end

    test 'taker CLOB_FEE ledger entry written on fill' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')
      no_leg  = @market.market_legs.find_by!(label: 'NO')

      Order.create!(
        market: @market, market_leg: no_leg, user: @seller,
        side: 'NO', price_cents: 60, quantity: 5,
        status: :open, time_in_force: :gtc
      )
      @seller.wallet.update!(reserved_minor: 300)

      assert_difference -> { LedgerEntry.where(entry_type: 'CLOB_FEE').count }, 1 do
        Clob::OrderMatchingService.call(
          market: @market,
          incoming_order_params: {
            user: @buyer, side: 'YES', price_cents: 40, quantity: 5,
            market_leg: yes_leg, time_in_force: :gtc
          }
        )
      end

      assert_equal @market.id, LedgerEntry.where(entry_type: 'CLOB_FEE').last.metadata['market_id']
    end

    test 'sell YES order matches against resting buy YES order' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')

      # Buyer has a resting YES buy order at 65¢
      resting = Order.create!(
        market: @market, market_leg: yes_leg, user: @buyer,
        side: 'YES', direction: 'buy', price_cents: 65, quantity: 5,
        status: :open, time_in_force: :gtc
      )
      @buyer.wallet.update!(available_minor: 500_000 - 325, reserved_minor: 325)

      # Seller has 5 YES contracts (from filled buy)
      Order.create!(
        market: @market, market_leg: yes_leg, user: @seller,
        side: 'YES', direction: 'buy', price_cents: 60, quantity: 5,
        status: :filled, time_in_force: :gtc, filled_quantity: 5
      )

      seller_initial = @seller.wallet.reload.available_minor

      result = Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @seller, side: 'YES', price_cents: 60,
          direction: 'sell', quantity: 5, market_leg: yes_leg, time_in_force: :gtc
        }
      )

      assert_predicate result, :success?
      assert_equal 'filled', result.incoming_order.status
      assert_equal 5, result.incoming_order.filled_quantity
      resting.reload

      assert_equal 'filled', resting.status
      # Seller credited at buyer's (maker's) price: 65¢ × 5 = 325
      assert_equal seller_initial + 325, @seller.wallet.reload.available_minor
    end

    test 'sell order rejected when net position is insufficient' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')

      result = Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @seller, side: 'YES', price_cents: 60,
          direction: 'sell', quantity: 5, market_leg: yes_leg, time_in_force: :gtc
        }
      )

      assert_not result.success?
      assert_includes result.errors.first, 'Insufficient position'
    end

    test 'rejects a second open sell order that would oversell held contracts (TD-019)' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')

      # Seller holds exactly 10 YES contracts (from a filled buy)
      Order.create!(
        market: @market, market_leg: yes_leg, user: @seller,
        side: 'YES', direction: 'buy', price_cents: 60, quantity: 10,
        status: :filled, filled_quantity: 10, time_in_force: :gtc
      )

      # First sell for all 10 contracts: no resting buys, so it rests open.
      first = Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @seller, side: 'YES', price_cents: 99,
          direction: 'sell', quantity: 10, market_leg: yes_leg, time_in_force: :gtc
        }
      )

      assert_predicate first, :success?
      assert_equal 'open', first.incoming_order.status

      # Second sell for another 10 must be rejected — the 10 held contracts are
      # already committed to the resting first sell order.
      second = Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @seller, side: 'YES', price_cents: 99,
          direction: 'sell', quantity: 10, market_leg: yes_leg, time_in_force: :gtc
        }
      )

      assert_not second.success?
      assert_includes second.errors.first, 'Insufficient position'
    end

    test 'rejects order when CLOB market is draft' do
      @market.update!(status: :draft)
      yes_leg = @market.market_legs.find_by!(label: 'YES')
      result = nil

      assert_no_difference('Order.count') do
        result = Clob::OrderMatchingService.call(
          market: @market,
          incoming_order_params: {
            user: @buyer, market_leg: yes_leg,
            side: 'YES', price_cents: 40, quantity: 1, time_in_force: :gtc
          }
        )
      end

      assert_not result.success?
      assert_includes result.errors, 'Market is not open'
    end

    test 'rejects order when CLOB market is past close_at' do
      @market.update!(close_at: 1.minute.ago)
      yes_leg = @market.market_legs.find_by!(label: 'YES')
      result = nil

      assert_no_difference('Order.count') do
        result = Clob::OrderMatchingService.call(
          market: @market,
          incoming_order_params: {
            user: @buyer, market_leg: yes_leg,
            side: 'YES', price_cents: 40, quantity: 1, time_in_force: :gtc
          }
        )
      end

      assert_not result.success?
      assert_includes result.errors, 'Market is closed for new bets'
    end

    test 'rejects order when CLOB market is closed, settled, or cancelled' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')

      %i[closed settled cancelled].each do |status|
        @market.update!(status: status, close_at: (status == :closed ? 1.minute.ago : nil))
        result = Clob::OrderMatchingService.call(
          market: @market,
          incoming_order_params: {
            user: @buyer, market_leg: yes_leg,
            side: 'YES', price_cents: 40, quantity: 1, time_in_force: :gtc
          }
        )

        assert_not result.success?, "expected #{status} market to reject CLOB order"
        assert_includes result.errors, 'Market is not open'
      end
    end

    test 'CLOB_SELL_CREDIT ledger entry written on sell fill' do
      yes_leg = @market.market_legs.find_by!(label: 'YES')

      Order.create!(
        market: @market, market_leg: yes_leg, user: @buyer,
        side: 'YES', direction: 'buy', price_cents: 65, quantity: 5,
        status: :open, time_in_force: :gtc
      )
      @buyer.wallet.update!(available_minor: 500_000 - 325, reserved_minor: 325)

      Order.create!(
        market: @market, market_leg: yes_leg, user: @seller,
        side: 'YES', direction: 'buy', price_cents: 60, quantity: 5,
        status: :filled, time_in_force: :gtc, filled_quantity: 5
      )

      assert_difference -> { LedgerEntry.where(entry_type: 'CLOB_SELL_CREDIT').count }, 1 do
        Clob::OrderMatchingService.call(
          market: @market,
          incoming_order_params: {
            user: @seller, side: 'YES', price_cents: 60,
            direction: 'sell', quantity: 5, market_leg: yes_leg, time_in_force: :gtc
          }
        )
      end
    end
  end
end
