require 'test_helper'

class ClobOrdersTest < ActionDispatch::IntegrationTest
  setup do
    @market = markets(:clob_market)
    @leg = @market.market_legs.find_by!(label: 'YES')
    users(:player).wallet.update!(available_minor: 100_000, reserved_minor: 0)
  end

  test 'admin can place order via POST /admin/markets/:id/orders' do
    post "/admin/markets/#{@market.id}/orders",
         headers: auth_headers_for(users(:admin)),
         params: { user_id: users(:player).id, side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
         as: :json

    assert_response :created
    body = response.parsed_body

    assert_equal 'open', body['status']
    assert_equal 200, body['reserved_minor']
  end

  test 'admin order placement returns 422 for non-CLOB market' do
    non_clob = markets(:open_market)
    post "/admin/markets/#{non_clob.id}/orders",
         headers: auth_headers_for(users(:admin)),
         params: { user_id: users(:player).id, side: 'YES', price_cents: 40, quantity: 5 },
         as: :json

    assert_response :unprocessable_entity
  end

  test 'admin order placement rejects draft CLOB market through service guard' do
    @market.update!(status: :draft)

    post "/admin/markets/#{@market.id}/orders",
         headers: auth_headers_for(users(:admin)),
         params: { user_id: users(:player).id, side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
         as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body['errors'], 'Market is not open'
  end

  test 'admin order placement rejects expired CLOB market through service guard' do
    @market.update!(close_at: 1.minute.ago)

    post "/admin/markets/#{@market.id}/orders",
         headers: auth_headers_for(users(:admin)),
         params: { user_id: users(:player).id, side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
         as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body['errors'], 'Market is closed for new bets'
  end

  test 'admin order placement rejects closed, settled, and cancelled CLOB markets through service guard' do
    %i[closed settled cancelled].each do |status|
      @market.update!(status: status, close_at: (status == :closed ? 1.minute.ago : nil))

      post "/admin/markets/#{@market.id}/orders",
           headers: auth_headers_for(users(:admin)),
           params: { user_id: users(:player).id, side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
           as: :json

      assert_response :unprocessable_content
      assert_includes response.parsed_body['errors'], 'Market is not open'
    end
  end

  test 'admin duplicate cancel does not release funds twice' do
    order = Order.create!(
      market: @market, market_leg: @leg, user: users(:player),
      side: 'YES', price_cents: 40, quantity: 5,
      status: :open, time_in_force: :gtc
    )
    users(:player).wallet.update!(available_minor: 99_800, reserved_minor: 200)

    delete "/admin/orders/#{order.id}", headers: auth_headers_for(users(:admin)), as: :json
    assert_response :ok

    delete "/admin/orders/#{order.id}", headers: auth_headers_for(users(:admin)), as: :json
    assert_response :unprocessable_content

    assert_equal 100_000, users(:player).wallet.reload.available_minor
    assert_equal 0, users(:player).wallet.reserved_minor
  end

  test 'admin can cancel order via DELETE /admin/orders/:id' do
    order = Order.create!(
      market: @market, market_leg: @leg, user: users(:player),
      side: 'YES', price_cents: 40, quantity: 5,
      status: :open, time_in_force: :gtc
    )
    users(:player).wallet.update!(available_minor: 99_800, reserved_minor: 200)

    delete "/admin/orders/#{order.id}", headers: auth_headers_for(users(:admin)), as: :json

    assert_response :ok
    body = response.parsed_body

    assert_equal 'cancelled', body['status']
    assert_equal 200, body['released_minor']
  end
end
