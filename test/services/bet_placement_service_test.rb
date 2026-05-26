require "test_helper"

class BetPlacementServiceTest < ActiveSupport::TestCase
  test "places bet and writes ledger and audit" do
    user = users(:player)
    market = markets(:open_market)
    leg = market_legs(:yes_leg)

    assert_difference("Bet.count", 1) do
      assert_difference("LedgerEntry.count", 1) do
        assert_difference("AuditEvent.count", 1) do
          @bet = BetPlacementService.place!(
            user: user,
            market: market,
            market_leg: leg,
            stake_minor: 500
          )
        end
      end
    end

    assert_equal 500, @bet.stake_minor
    assert_equal 5, @bet.fee_minor
    assert_equal 495, @bet.net_stake_minor
    assert_equal 250, @bet.potential_payout_minor
    assert_equal 500, user.wallet.reload.available_minor
  end

  test "rejects bet when risk limit is exceeded" do
    user = users(:player)
    market = Market.create!(
      question: "Risk cap market",
      description: "single sided market for cap test",
      created_by: users(:admin),
      liability_cap_minor: 5
    )
    leg = MarketLeg.create!(market: market, label: "YES", odds_minor: 10_000, active: true)
    MarketLeg.create!(market: market, label: "NO", odds_minor: 10_000, active: true)
    market.update_columns(status: 1)

    assert_raises(BetPlacementService::RiskLimitExceeded) do
      BetPlacementService.place!(
        user: user,
        market: market,
        market_leg: leg,
        stake_minor: 1_000
      )
    end
  end
end
