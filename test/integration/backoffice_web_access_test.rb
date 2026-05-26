require "test_helper"

class BackofficeWebAccessTest < ActionDispatch::IntegrationTest
  test "player is redirected when opening backoffice" do
    player = User.create!(
      email: "no_backoffice_player@example.com",
      password: "password123",
      role: :player,
      active: true
    )

    post "/signin", params: { email: player.email, password: "password123" }

    get "/backoffice"
    assert_response :redirect
    assert_match %r{/$}, response.headers["Location"]

    follow_redirect!
    assert_response :success
    assert_match "Forbidden", response.body
  end

  test "moderator can access backoffice" do
    post "/signin", params: { email: users(:moderator).email, password: "password123" }
    get "/backoffice"

    assert_response :success
    assert_match "Operations Dashboard", response.body
  end

  test "anonymous user is redirected to sign in" do
    get "/backoffice"
    assert_response :redirect
    assert_match "/signin", response.headers["Location"]
  end
end
