require "test_helper"

class AuthSessionsTest < ActionDispatch::IntegrationTest
  test "register creates player account" do
    assert_difference("User.count", 1) do
      post "/auth/register", params: { email: "newplayer@example.com", password: "password123" }, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["token"].present?
    assert_equal "player", body.dig("user", "role")
  end

  test "login returns token" do
    post "/auth/login", params: { email: users(:player).email, password: "password123" }, as: :json

    assert_response :success
    assert JSON.parse(response.body)["token"].present?
  end

  test "login fails with wrong password" do
    post "/auth/login", params: { email: users(:player).email, password: "wrong" }, as: :json

    assert_response :unauthorized
  end

  test "me requires auth" do
    get "/auth/me"
    assert_response :unauthorized
  end

  test "me returns current user" do
    get "/auth/me", headers: auth_headers_for(users(:player))

    assert_response :success
    assert_equal users(:player).email, JSON.parse(response.body)["email"]
  end
end
