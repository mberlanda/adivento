require 'test_helper'

class WebCustomerPagesTest < ActionDispatch::IntegrationTest
  test 'player does not see backoffice in top nav' do
    player = User.create!(
      email: 'nav_player@example.com',
      password: 'password123',
      role: :player,
      active: true
    )

    post '/signin', params: { email: player.email, password: 'password123' }
    get '/'

    assert_response :success
    assert_no_match '>Backoffice<', response.body
  end

  test 'admin sees backoffice in top nav' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    get '/'

    assert_response :success
    assert_match '>Backoffice<', response.body
  end

  test 'home page renders market explorer' do
    get '/'

    assert_response :success
    assert_match 'Explore Markets', response.body
  end

  test 'guest cannot see draft market page' do
    get "/web/markets/#{markets(:draft_market).id}"

    assert_response :redirect
  end

  test 'signed in user can see draft market page' do
    post '/signin', params: { email: users(:player).email, password: 'password123' }
    get "/web/markets/#{markets(:draft_market).id}"

    assert_response :success
    assert_match markets(:draft_market).question, response.body
  end
end
