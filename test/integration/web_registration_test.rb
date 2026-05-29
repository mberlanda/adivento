require 'test_helper'

class WebRegistrationTest < ActionDispatch::IntegrationTest
  test 'GET /register renders the registration form' do
    get '/register'

    assert_response :success
    assert_select 'form'
    assert_select 'input[type=email]'
  end

  test 'POST /register creates a player account and signs them in' do
    assert_difference 'User.count', 1 do
      post '/register', params: { email: 'newbie@example.com', password: 'password123' }
    end

    assert_redirected_to root_path
    user = User.find_by(email: 'newbie@example.com')

    assert_not_nil user
    assert_predicate user, :player?

    # Session cookie is set: a protected web page is reachable without redirect to sign-in.
    get '/web/positions'

    assert_response :success
  end

  test 'POST /register rejects a password shorter than 8 characters' do
    assert_no_difference 'User.count' do
      post '/register', params: { email: 'shortpw@example.com', password: 'short' }
    end

    assert_response :unprocessable_content
  end

  test 'POST /register re-renders with an error for a duplicate email' do
    existing = users(:player)

    assert_no_difference 'User.count' do
      post '/register', params: { email: existing.email, password: 'password123' }
    end

    assert_response :unprocessable_content
  end
end
