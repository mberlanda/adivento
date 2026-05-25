require "test_helper"

class TemplatesAndSseTest < ActionDispatch::IntegrationTest
  test "moderator can create market from template in backoffice" do
    post "/signin", params: { email: users(:moderator).email, password: "password123" }

    assert_difference("Market.count", 1) do
      post "/backoffice/templates/#{market_templates(:binary).id}/create_market",
           params: { question: "Template Q", description: "Template D" }
    end

    market = Market.order(:created_at).last
    assert_equal ["NO", "YES"], market.market_legs.order(:label).pluck(:label)
  end

  test "market sse endpoint returns stream format" do
    get "/sse/markets/#{markets(:open_market).id}"

    assert_response :success
    assert_equal "text/event-stream", response.media_type
    assert_match "event: market.snapshot.v1", response.body
  end
end
