require 'test_helper'

class WebProfileTest < ActionDispatch::IntegrationTest
  def setup
    @player = users(:player)
    post '/signin', params: { email: @player.email, password: 'password123' }
  end

  test 'profile page requires authentication' do
    delete '/signout'
    get '/web/profile'

    assert_response :redirect
  end

  test 'profile page renders wallet balance and pnl panel' do
    get '/web/profile'

    assert_response :success
    assert_select '[data-testid="profile-title"]', 'My Profile'

    assert_select '[data-testid="wallet-balance-panel"]'
    assert_select '[data-testid="pnl-panel"]'
    assert_select '[data-testid="bets-panel"]'
  end

  test 'profile shows open bet in bets table' do
    get '/web/profile'

    assert_response :success
    bet = bets(:player_yes_open_bet)

    assert_select "[data-testid='bet-row-#{bet.id}']"
    assert_select "[data-testid='bet-market-link-#{bet.id}']"
  end

  test 'status filter restricts bets shown' do
    won_bet = Bet.create!(
      user: @player, market: markets(:open_market), market_leg: market_legs(:yes_leg),
      stake_minor: 100, fee_minor: 1, net_stake_minor: 99,
      odds_minor: 5000, potential_payout_minor: 200, status: :settled_win
    )

    get '/web/profile', params: { status: 'settled_win' }

    assert_response :success

    assert_select "[data-testid='bet-row-#{won_bet.id}']"
    open_bet = bets(:player_yes_open_bet)

    assert_select "[data-testid='bet-row-#{open_bet.id}']", count: 0
  end

  test 'pnl summary reflects won and lost bets' do
    Bet.create!(
      user: @player, market: markets(:open_market), market_leg: market_legs(:yes_leg),
      stake_minor: 200, fee_minor: 2, net_stake_minor: 198,
      odds_minor: 5000, potential_payout_minor: 400, status: :settled_win
    )
    Bet.create!(
      user: @player, market: markets(:open_market), market_leg: market_legs(:no_leg),
      stake_minor: 100, fee_minor: 1, net_stake_minor: 99,
      odds_minor: 5000, potential_payout_minor: 200, status: :settled_loss
    )

    get '/web/profile'

    assert_response :success
    assert_select '[data-testid="pnl-win-rate"]', /50\.0%/
    assert_select '[data-testid="pnl-open-count"]', '1'
  end

  test 'invalid status filter is ignored and shows all bets' do
    get '/web/profile', params: { status: 'invalid_status' }

    assert_response :success

    assert_select '[data-testid="bets-table"]'
    bet = bets(:player_yes_open_bet)

    assert_select "[data-testid='bet-row-#{bet.id}']"
  end
end
