require 'test_helper'

module Clob
  class OrderCancellationServiceTest < ActiveSupport::TestCase
    setup do
      @market = markets(:clob_market)
      @leg = @market.market_legs.find_by!(label: 'YES')
      @user = users(:player)
      @actor = users(:admin)
      @user.wallet.update!(available_minor: 99_800, reserved_minor: 200)
      @order = Order.create!(
        market: @market, market_leg: @leg, user: @user,
        side: 'YES', price_cents: 40, quantity: 5,
        status: :open, time_in_force: :gtc
      )
    end

    test 'cancels open order and releases reserved funds under lock' do
      result = Clob::OrderCancellationService.call(order: @order, actor: @actor)

      assert_predicate result, :success?
      assert_equal 200, result.released_minor
      assert_predicate @order.reload, :cancelled?
      assert_equal 100_000, @user.wallet.reload.available_minor
      assert_equal 0, @user.wallet.reserved_minor
      assert AuditEvent.exists?(action: 'order.cancel', target_type: 'Order', target_id: @order.id)
    end

    test 'rejects already filled order without releasing funds' do
      @order.update!(status: :filled, filled_quantity: 5)

      result = Clob::OrderCancellationService.call(order: @order, actor: @actor)

      assert_not result.success?
      assert_includes result.errors, 'Order cannot be cancelled'
      assert_equal 200, @user.wallet.reload.reserved_minor
    end
  end
end
