require 'test_helper'

class WebLeaderboardTest < ActionDispatch::IntegrationTest
  test 'leaderboard is publicly accessible without auth' do
    get '/web/leaderboard'

    assert_response :success
    assert_select '[data-testid="leaderboard-title"]', 'Leaderboard'
  end

  test 'leaderboard shows empty state when no activity ledger entries' do
    LedgerEntry.where(entry_type: Web::LeaderboardController::STAKE_TYPES + Web::LeaderboardController::RETURN_TYPES).delete_all

    get '/web/leaderboard'

    assert_response :success
    assert_select '[data-testid="leaderboard-empty"]'
  end

  test 'leaderboard shows player ranked by net pnl from fixed-odds ledger entries' do
    player = users(:player)
    LedgerEntry.create!(user: player, actor: player, entry_type: 'BET_STAKE',
                        amount_minor: 100, direction: 'debit', metadata: {})
    LedgerEntry.create!(user: player, actor: player, entry_type: 'BET_WIN_PAYOUT',
                        amount_minor: 200, direction: 'credit', metadata: {})

    get '/web/leaderboard'

    assert_response :success
    assert_select '[data-testid="leaderboard-table"]'
    assert_select "[data-testid='leaderboard-player-#{player.id}']", player.email.split('@').first
    assert_select "[data-testid='leaderboard-pnl-#{player.id}']", /ADIV/
  end

  test 'leaderboard includes CLOB and parimutuel players from ledger entries' do
    clob_player = users(:moderator)
    LedgerEntry.create!(user: clob_player, actor: clob_player, entry_type: 'ORDER_FILL_STAKE',
                        amount_minor: 500, direction: 'debit', metadata: {})
    LedgerEntry.create!(user: clob_player, actor: clob_player, entry_type: 'SETTLEMENT_WIN',
                        amount_minor: 900, direction: 'credit', metadata: {})

    get '/web/leaderboard'

    assert_response :success
    assert_select "[data-testid='leaderboard-player-#{clob_player.id}']"
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
