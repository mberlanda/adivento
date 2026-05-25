require "test_helper"

class WebCustomerPagesTest < ActionDispatch::IntegrationTest
  test "home page renders market explorer" do
    get "/"

    assert_response :success
    assert_match "Explore Markets", response.body
  end

  test "guest cannot see draft market page" do
    get "/web/markets/#{markets(:draft_market).id}"

    assert_response :redirect
  end

  test "signed in user can see draft market page" do
    post "/signin", params: { email: users(:player).email, password: "password123" }
    get "/web/markets/#{markets(:draft_market).id}"

    assert_response :success
    assert_match markets(:draft_market).question, response.body
  end
end
