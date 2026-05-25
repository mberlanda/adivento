require "test_helper"

class WalletsTest < ActionDispatch::IntegrationTest
  test "wallet requires authentication" do
    get "/wallet"
    assert_response :unauthorized
  end

  test "authenticated user sees wallet" do
    get "/wallet", headers: auth_headers_for(users(:player))

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal users(:player).id, body["user_id"]
    assert_equal 1000, body["available_minor"]
  end
end
