require "test_helper"

class BackofficeWebAccessTest < ActionDispatch::IntegrationTest
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
