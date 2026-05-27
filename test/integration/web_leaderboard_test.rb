require 'test_helper'

class WebLeaderboardTest < ActionDispatch::IntegrationTest
  test 'leaderboard is publicly accessible without auth' do
    get '/web/leaderboard'

    assert_response :success
    assert_select '[data-testid="leaderboard-title"]', 'Leaderboard'
  end

  test 'leaderboard shows empty state when no settled bets' do
    Bet.where(status: %i[settled_win settled_loss]).delete_all

    get '/web/leaderboard'

    assert_response :success
    assert_select '[data-testid="leaderboard-empty"]'
  end

  test 'leaderboard shows settled player ranked by net pnl' do
    player = users(:player)
    won_bet = Bet.create!(
      user: player, market: markets(:open_market), market_leg: market_legs(:yes_leg),
      stake_minor: 100, fee_minor: 1, net_stake_minor: 99,
      odds_minor: 5000, potential_payout_minor: 200, status: :settled_win
    )

    get '/web/leaderboard'

    assert_response :success
    assert_select '[data-testid="leaderboard-table"]'
    assert_select "[data-testid='leaderboard-player-#{player.id}']", player.email.split('@').first
    assert_select "[data-testid='leaderboard-pnl-#{player.id}']", /ADIV/
    won_bet.destroy
  end

  test 'leaderboard is accessible while authenticated' do
    post '/signin', params: { email: users(:player).email, password: 'password123' }
    get '/web/leaderboard'

    assert_response :success
    assert_select '[data-testid="leaderboard-title"]'
  end

  test 'nav includes leaderboard link' do
    get '/web/leaderboard'

    assert_response :success
    assert_select '[data-testid="nav-leaderboard"]'
  end
end
