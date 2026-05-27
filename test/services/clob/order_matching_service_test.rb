require "test_helper"

class Clob::OrderMatchingServiceTest < ActiveSupport::TestCase
  setup do
    @market = markets(:clob_market)
    @buyer  = users(:player)
    @seller = users(:moderator)
    @buyer.wallet.update!(available_minor: 500_000, reserved_minor: 0)
    @seller.wallet.update!(available_minor: 500_000, reserved_minor: 0)
  end

  test "YES bid matches NO bid when P + Q >= 100 at maker price" do
    yes_leg = @market.market_legs.find_by!(label: "YES")
    no_leg  = @market.market_legs.find_by!(label: "NO")

    seller_order = Order.create!(
      market: @market, market_leg: no_leg, user: @seller,
      side: "NO", price_cents: 60, quantity: 5,
      status: :open, time_in_force: :gtc
    )
    @seller.wallet.update!(available_minor: 500_000 - 300, reserved_minor: 300)

    result = Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: @buyer, side: "YES", price_cents: 40, quantity: 5,
        market_leg: yes_leg, time_in_force: :gtc
      }
    )

    assert result.success?
    assert_equal "filled", result.incoming_order.status
    assert_equal 5, result.incoming_order.filled_quantity
    seller_order.reload
    assert_equal "filled", seller_order.status
  end

  test "partial fill: incoming order fills partially when only fewer resting contracts available" do
    yes_leg = @market.market_legs.find_by!(label: "YES")
    no_leg  = @market.market_legs.find_by!(label: "NO")

    Order.create!(
      market: @market, market_leg: no_leg, user: @seller,
      side: "NO", price_cents: 60, quantity: 3,
      status: :open, time_in_force: :gtc
    )
    @seller.wallet.update!(available_minor: 500_000 - 180, reserved_minor: 180)

    result = Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: @buyer, side: "YES", price_cents: 40, quantity: 5,
        market_leg: yes_leg, time_in_force: :gtc
      }
    )

    assert result.success?
    assert_equal "partial", result.incoming_order.status
    assert_equal 3, result.incoming_order.filled_quantity
    assert_equal 2, result.incoming_order.unfilled_quantity
  end

  test "IOC order: unfilled remainder cancelled after one pass" do
    yes_leg = @market.market_legs.find_by!(label: "YES")

    result = Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: @buyer, side: "YES", price_cents: 40, quantity: 5,
        market_leg: yes_leg, time_in_force: :ioc
      }
    )

    assert result.success?
    assert_equal "cancelled", result.incoming_order.status
  end

  test "FOK order: entire order cancelled if full quantity not available" do
    yes_leg = @market.market_legs.find_by!(label: "YES")
    no_leg  = @market.market_legs.find_by!(label: "NO")

    Order.create!(
      market: @market, market_leg: no_leg, user: @seller,
      side: "NO", price_cents: 60, quantity: 3,
      status: :open, time_in_force: :gtc
    )

    result = Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: @buyer, side: "YES", price_cents: 40, quantity: 5,
        market_leg: yes_leg, time_in_force: :fok
      }
    )

    assert result.success?
    assert_equal "cancelled", result.incoming_order.status
    assert_equal 0, result.incoming_order.filled_quantity
  end

  test "taker CLOB_FEE ledger entry written on fill" do
    yes_leg = @market.market_legs.find_by!(label: "YES")
    no_leg  = @market.market_legs.find_by!(label: "NO")

    Order.create!(
      market: @market, market_leg: no_leg, user: @seller,
      side: "NO", price_cents: 60, quantity: 5,
      status: :open, time_in_force: :gtc
    )
    @seller.wallet.update!(reserved_minor: 300)

    assert_difference -> { LedgerEntry.where(entry_type: "CLOB_FEE").count }, 1 do
      Clob::OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @buyer, side: "YES", price_cents: 40, quantity: 5,
          market_leg: yes_leg, time_in_force: :gtc
        }
      )
    end
  end
end
