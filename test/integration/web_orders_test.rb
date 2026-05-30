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

  test 'web order placement surfaces service lifecycle guard for expired CLOB market' do
    @market.update!(close_at: 1.minute.ago)

    post "/web/markets/#{@market.id}/orders",
         headers: auth_headers_for(@player),
         params: { side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
         as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body['errors'], 'Market is closed for new bets'
  end

  test 'returns 422 for non-CLOB market' do
    post "/web/markets/#{markets(:open_market).id}/orders",
         headers: auth_headers_for(@player),
         params: { side: 'YES', price_cents: 40, quantity: 5 },
         as: :json

    assert_response :unprocessable_entity
  end

  test 'player can cancel own order and audit event is written' do
    leg = @market.market_legs.find_by!(label: 'YES')
    order = Order.create!(
      market: @market, market_leg: leg, user: @player,
      side: 'YES', price_cents: 40, quantity: 5,
      status: :open, time_in_force: :gtc
    )
    @player.wallet.update!(available_minor: 99_800, reserved_minor: 200)

    assert_difference -> { AuditEvent.where(action: 'order.cancel', target_id: order.id).count }, 1 do
      delete "/web/orders/#{order.id}", headers: auth_headers_for(@player), as: :json
    end

    assert_response :ok
    assert_equal 'cancelled', response.parsed_body['status']
  end

  test 'order book endpoint returns bid/ask data with new fields' do
    get "/web/markets/#{@market.id}/order_book",
        headers: auth_headers_for(@player), as: :json

    assert_response :ok
    body = response.parsed_body

    assert body.key?('best_bid')
    assert body.key?('best_ask')
    assert body.key?('last_trade_price')
    assert body.key?('spread')
    assert body.key?('bids')
    assert body.key?('asks')
  end

  test 'order book returns 422 for non-CLOB market' do
    get "/web/markets/#{markets(:open_market).id}/order_book",
        headers: auth_headers_for(@player), as: :json

    assert_response :unprocessable_entity
  end

  test 'matching a YES and NO order writes ORDER_FILL_STAKE and ORDER_FILL_CREDIT ledger entries' do
    buyer  = users(:player)
    seller = users(:moderator)
    seller.wallet.update!(available_minor: 100_000, reserved_minor: 0)
    leg_yes = @market.market_legs.find_by!(label: 'YES')
    leg_no  = @market.market_legs.find_by!(label: 'NO')

    # Place resting NO order at 40 (seller)
    Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: seller, market_leg: leg_no,
        side: 'NO', price_cents: 40, quantity: 3, time_in_force: :gtc
      }
    )

    LedgerEntry.count

    # Place crossing YES order at 60 (buyer) — should match with NO@40 (60+40=100)
    Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: buyer, market_leg: leg_yes,
        side: 'YES', price_cents: 60, quantity: 3, time_in_force: :gtc
      }
    )

    fill_stake  = LedgerEntry.where(entry_type: 'ORDER_FILL_STAKE').last
    fill_credit = LedgerEntry.where(entry_type: 'ORDER_FILL_CREDIT').last

    assert_not_nil fill_stake,  'ORDER_FILL_STAKE entry should be written'
    assert_not_nil fill_credit, 'ORDER_FILL_CREDIT entry should be written'

    assert_equal 'debit',  fill_stake.direction
    assert_equal 'credit', fill_credit.direction
    assert_equal buyer.id,  fill_stake.user_id
    assert_equal seller.id, fill_credit.user_id
    assert_equal buyer.id,  fill_credit.actor_id

    assert_equal 60 * 3, fill_stake.amount_minor   # taker stake = taker price × qty
    assert_equal 40 * 3, fill_credit.amount_minor  # maker credit = maker price × qty
  end

  test 'matching updates market last_fill_price_cents' do
    buyer  = users(:player)
    seller = users(:moderator)
    seller.wallet.update!(available_minor: 100_000, reserved_minor: 0)
    leg_yes = @market.market_legs.find_by!(label: 'YES')
    leg_no  = @market.market_legs.find_by!(label: 'NO')

    Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: seller, market_leg: leg_no,
        side: 'NO', price_cents: 45, quantity: 2, time_in_force: :gtc
      }
    )
    Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: buyer, market_leg: leg_yes,
        side: 'YES', price_cents: 55, quantity: 2, time_in_force: :gtc
      }
    )

    assert_equal 45, @market.reload.last_fill_price_cents
  end
end
