require "test_helper"

class WebSessionsTest < ActionDispatch::IntegrationTest
  test "signin fails with invalid credentials" do
    post "/signin", params: { email: users(:admin).email, password: "bad" }

    assert_response :unprocessable_entity
    assert_match "Invalid credentials", response.body
  end

  test "signin and signout flow" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    assert_response :redirect

    delete "/signout"
    assert_response :redirect
  end
end
