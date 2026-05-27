require "test_helper"

class ClobOrdersTest < ActionDispatch::IntegrationTest
  setup do
    @market = markets(:clob_market)
    @leg = @market.market_legs.find_by!(label: "YES")
    users(:player).wallet.update!(available_minor: 100_000, reserved_minor: 0)
  end

  test "admin can place order via POST /admin/markets/:id/orders" do
    post "/admin/markets/#{@market.id}/orders",
      headers: auth_headers_for(users(:admin)),
      params: { user_id: users(:player).id, side: "YES", price_cents: 40, quantity: 5, time_in_force: "GTC" },
      as: :json
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "open", body["status"]
    assert_equal 200, body["reserved_minor"]
  end

  test "admin order placement returns 422 for non-CLOB market" do
    non_clob = markets(:open_market)
    post "/admin/markets/#{non_clob.id}/orders",
      headers: auth_headers_for(users(:admin)),
      params: { user_id: users(:player).id, side: "YES", price_cents: 40, quantity: 5 },
      as: :json
    assert_response :unprocessable_entity
  end

  test "admin can cancel order via DELETE /admin/orders/:id" do
    order = Order.create!(
      market: @market, market_leg: @leg, user: users(:player),
      side: "YES", price_cents: 40, quantity: 5,
      status: :open, time_in_force: :gtc
    )
    users(:player).wallet.update!(available_minor: 99_800, reserved_minor: 200)

    delete "/admin/orders/#{order.id}", headers: auth_headers_for(users(:admin)), as: :json
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "cancelled", body["status"]
    assert_equal 200, body["released_minor"]
  end
end
