require "test_helper"

class BetsTest < ActionDispatch::IntegrationTest
  test "placing bet requires authentication" do
    post "/markets/#{markets(:open_market).id}/bets",
         params: { market_leg_id: market_legs(:yes_leg).id, stake_minor: 100 },
         as: :json

    assert_response :unauthorized
  end

  test "player can place bet" do
    player = users(:player)

    assert_difference("Bet.count", 1) do
      assert_difference("LedgerEntry.count", 1) do
        assert_difference("AuditEvent.count", 1) do
          post "/markets/#{markets(:open_market).id}/bets",
               params: { market_leg_id: market_legs(:yes_leg).id, stake_minor: 100 },
               headers: auth_headers_for(player),
               as: :json
        end
      end
    end

    assert_response :created
    payload = JSON.parse(response.body)
    assert_equal 100, payload["stake_minor"]
    assert_equal "open", payload["status"]
    assert_equal 900, player.wallet.reload.available_minor

    ledger = LedgerEntry.order(:created_at).last
    assert_equal "BET_STAKE", ledger.entry_type
    assert_equal "debit", ledger.direction
    assert_equal 100, ledger.amount_minor

    audit = AuditEvent.order(:created_at).last
    assert_equal "bet.place", audit.action
  end

  test "deny grant blocks bet placement" do
    UserGrant.create!(
      user: users(:player),
      permission: permissions(:bet_place),
      allow: false,
      reason: "cooldown",
      granted_by: users(:admin)
    )

    post "/markets/#{markets(:open_market).id}/bets",
         params: { market_leg_id: market_legs(:yes_leg).id, stake_minor: 100 },
         headers: auth_headers_for(users(:player)),
         as: :json

    assert_response :forbidden
  end

  test "risk breach blocks writes" do
    market = Market.create!(
      question: "Low cap",
      description: "Risk rejection market",
      status: :open,
      created_by: users(:admin),
      liability_cap_minor: 5
    )
    leg = MarketLeg.create!(market: market, label: "YES", odds_minor: 10_000, active: true)

    assert_no_difference("Bet.count") do
      assert_no_difference("LedgerEntry.count") do
        post "/markets/#{market.id}/bets",
             params: { market_leg_id: leg.id, stake_minor: 1000 },
             headers: auth_headers_for(users(:player)),
             as: :json
      end
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "Liability cap exceeded"
  end
end
