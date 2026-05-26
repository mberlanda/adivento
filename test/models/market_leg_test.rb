require "test_helper"

class MarketLegTest < ActiveSupport::TestCase
  test "odds cannot exceed range" do
    leg = market_legs(:yes_leg)
    leg.odds_minor = 15_000
    assert_not leg.valid?
  end

  setup do
    @market = markets(:open_market)
  end

  test "cannot add a 3rd leg to a market that already has 2" do
    assert_equal 2, @market.market_legs.count

    third_leg = MarketLeg.new(market: @market, label: "MAYBE", odds_minor: 5000)
    assert_not third_leg.valid?
    assert_includes third_leg.errors[:base], "Market already has the maximum of 2 legs"
  end

  test "duplicate label in the same market is invalid" do
    dup = MarketLeg.new(market: @market, label: @market.market_legs.first.label, odds_minor: 5000)
    assert_not dup.valid?
  end

  test "can create a leg on a draft market with 0 legs" do
    draft = markets(:draft_market)
    leg = MarketLeg.new(market: draft, label: "YES", odds_minor: 5000)
    assert leg.valid?
  end
end
