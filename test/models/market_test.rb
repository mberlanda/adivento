require "test_helper"

class MarketTest < ActiveSupport::TestCase
  test "has valid fixture" do
    assert markets(:open_market).valid?
  end

  test "requires question" do
    market = markets(:open_market)
    market.question = nil
    assert_not market.valid?
  end
end
