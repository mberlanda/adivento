require "test_helper"

class MarketLegTest < ActiveSupport::TestCase
  test "odds cannot exceed range" do
    leg = market_legs(:yes_leg)
    leg.odds_minor = 15_000
    assert_not leg.valid?
  end
end
