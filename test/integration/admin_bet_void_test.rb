require "test_helper"

class AdminBetVoidTest < ActionDispatch::IntegrationTest
  test "moderator can void active bet" do
    bet = bets(:player_yes_open_bet)
    player = bet.user
    before_balance = player.wallet.available_minor

    post "/admin/bets/#{bet.id}/void",
         params: { reason: "voided by operator" },
         headers: auth_headers_for(users(:moderator)),
         as: :json

    assert_response :success
    assert_equal "voided", bet.reload.status
    assert_equal before_balance + bet.stake_minor, player.wallet.reload.available_minor
  end

  test "voided bet shows in market SSE payload" do
    bet = bets(:moderator_no_open_bet)
    post "/admin/bets/#{bet.id}/void",
         params: { reason: "compliance" },
         headers: auth_headers_for(users(:admin)),
         as: :json
    assert_response :success

    get "/sse/markets/#{bet.market_id}"

    assert_response :success
    assert_match "event: market.bet_voided.v1", response.body
    assert_match "\"voided_bets_count\":", response.body
  end
end
