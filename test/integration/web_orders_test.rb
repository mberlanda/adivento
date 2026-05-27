require 'test_helper'

class WebOrdersTest < ActionDispatch::IntegrationTest
  setup do
    @market = markets(:clob_market)
    @player = users(:player)
    @player.wallet.update!(available_minor: 100_000, reserved_minor: 0)
  end

  test 'player can place order via POST /web/markets/:id/orders' do
    post "/web/markets/#{@market.id}/orders",
         headers: auth_headers_for(@player),
         params: { side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
         as: :json

    assert_response :created
    body = response.parsed_body

    assert_equal 'open', body['status']
  end

  test 'returns 422 for non-CLOB market' do
    post "/web/markets/#{markets(:open_market).id}/orders",
         headers: auth_headers_for(@player),
         params: { side: 'YES', price_cents: 40, quantity: 5 },
         as: :json

    assert_response :unprocessable_entity
  end

  test 'player can cancel own order' do
    leg = @market.market_legs.find_by!(label: 'YES')
    order = Order.create!(
      market: @market, market_leg: leg, user: @player,
      side: 'YES', price_cents: 40, quantity: 5,
      status: :open, time_in_force: :gtc
    )
    @player.wallet.update!(available_minor: 99_800, reserved_minor: 200)

    delete "/web/orders/#{order.id}", headers: auth_headers_for(@player), as: :json

    assert_response :ok
    body = response.parsed_body

    assert_equal 'cancelled', body['status']
  end

  test 'order book endpoint returns bid/ask data' do
    get "/web/markets/#{@market.id}/order_book",
        headers: auth_headers_for(@player), as: :json

    assert_response :ok
    body = response.parsed_body

    assert body.key?('best_bid')
    assert body.key?('best_ask')
    assert body.key?('bids')
    assert body.key?('asks')
  end

  test 'order book returns 422 for non-CLOB market' do
    get "/web/markets/#{markets(:open_market).id}/order_book",
        headers: auth_headers_for(@player), as: :json

    assert_response :unprocessable_entity
  end
end
