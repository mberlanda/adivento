require 'test_helper'

class HouseRiskServiceTest < ActiveSupport::TestCase
  test 'computes pnl by outcome for open bets' do
    market = markets(:open_market)

    pnl = HouseRiskService.pnl_by_outcome(market).transform_keys(&:label)

    assert_equal 247, pnl.fetch('YES')
    assert_equal 197, pnl.fetch('NO')
  end

  test 'computes worst case liability with simulated bet' do
    market = Market.create!(
      question: 'Isolated risk market',
      description: 'used for risk simulation',
      created_by: users(:admin)
    )
    yes_leg = MarketLeg.create!(market: market, label: 'YES', odds_minor: 10_000, active: true)
    MarketLeg.create!(market: market, label: 'NO', odds_minor: 10_000, active: true)
    market.update_columns(status: 1)

    liability = HouseRiskService.worst_case_liability(
      market,
      extra_bet_attrs: {
        market_leg_id: yes_leg.id,
        net_stake_minor: 99,
        potential_payout_minor: 200
      }
    )

    assert_equal 101, liability
  end
end
