require 'test_helper'

class AdminMarketSettleTest < ActionDispatch::IntegrationTest
  setup do
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
    @player = users(:player)

    @market.bets.delete_all

    if @player.wallet
      @player.wallet.update!(available_minor: 10_000)
    else
      @player.create_wallet!(available_minor: 10_000, reserved_minor: 0)
    end

    @winner_bet = Bet.create!(
      user: @player,
      market: @market,
      market_leg: @yes_leg,
      stake_minor: 1000,
      fee_minor: 10,
      net_stake_minor: 990,
      odds_minor: 5000,
      potential_payout_minor: 5000,
      status: :open
    )
  end

  test 'admin can settle market via API and bets are transitioned' do
    post "/admin/markets/#{@market.id}/settle",
         params: { outcome: 'YES', reason: 'verified' },
         headers: auth_headers_for(users(:admin)), as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal 'settled', body['status']
    assert_equal 'YES', body['settled_outcome']

    @winner_bet.reload

    assert_predicate @winner_bet, :settled_win?

    @player.wallet.reload

    assert_equal 15_000, @player.wallet.available_minor
  end

  test 'invalid outcome returns error' do
    post "/admin/markets/#{@market.id}/settle",
         params: { outcome: 'MAYBE' },
         headers: auth_headers_for(users(:admin)), as: :json

    assert_response :unprocessable_entity
    assert_match 'Invalid outcome', response.parsed_body['error']
  end

  test 'settling non-open market returns error' do
    @market.update!(status: :draft)

    post "/admin/markets/#{@market.id}/settle",
         params: { outcome: 'YES' },
         headers: auth_headers_for(users(:admin)), as: :json

    assert_response :unprocessable_entity
    assert_match 'open', response.parsed_body['error']
  end

  test 'admin can settle a closed market via API' do
    @market.update_columns(status: Market.statuses[:closed], close_at: 1.hour.ago)

    post "/admin/markets/#{@market.id}/settle",
         params: { outcome: 'YES' },
         headers: auth_headers_for(users(:admin)), as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal 'settled', body['status']
    assert_equal 'YES', body['settled_outcome']
  end
end
