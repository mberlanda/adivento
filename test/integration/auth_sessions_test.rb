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
    assert body["actions"].is_a?(Array)
    refute_includes body["actions"].map { |action| action["key"] }, "navigation.backoffice"
  end

  test "register rejects duplicate email" do
    assert_no_difference("User.count") do
      post "/auth/register", params: { email: users(:player).email, password: "password123" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"].join(" ").downcase, "email"
  end

  test "login returns token" do
    post "/auth/login", params: { email: users(:player).email, password: "password123" }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert payload["token"].present?
    assert payload["actions"].any? { |action| action["key"] == "navigation.sign_out" }
    assert payload["actions"].none? { |action| action["key"] == "navigation.sign_in" }
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
    player = User.create!(
      email: "me_actions_player@example.com",
      password: "password123",
      role: :player,
      active: true
    )

    get "/auth/me", headers: auth_headers_for(player)

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal player.email, payload["email"]
    assert payload["actions"].is_a?(Array)
    assert payload["actions"].any? { |action| action["key"] == "capability.bet.place" }
    refute payload["actions"].any? { |action| action["key"] == "navigation.backoffice" }
  end
end
