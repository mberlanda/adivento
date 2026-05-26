require "test_helper"

class AdminMarketLegsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @market = markets(:open_market)
  end

  test "returns 422 when market already has 2 legs" do
    assert_equal 2, @market.market_legs.count

    post "/admin/markets/#{@market.id}/legs",
      params: { label: "THIRD", odds_minor: 5000 },
      headers: auth_headers_for(@admin),
      as: :json

    assert_response :unprocessable_entity
    assert_equal "Market already has 2 legs", response.parsed_body["error"]
  end
end
