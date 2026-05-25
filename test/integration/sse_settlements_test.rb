require "test_helper"

class SseSettlementsTest < ActionDispatch::IntegrationTest
  test "settlement sse endpoint returns expected event" do
    get "/sse/settlements/#{markets(:open_market).id}"

    assert_response :success
    assert_equal "text/event-stream", response.media_type
    assert_match "event: settlement.changed.v1", response.body
  end
end
