require "test_helper"

class MarketTemplateTest < ActiveSupport::TestCase
  test "returns configured legs" do
    assert_equal ["YES", "NO"], market_templates(:binary).legs
  end
end
