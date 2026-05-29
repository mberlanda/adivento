require 'test_helper'

class WebPositionsTest < ActionDispatch::IntegrationTest
  test 'positions page requires authentication' do
    get '/web/positions'

    assert_response :redirect
  end

  test 'player can view positions HTML page' do
    get '/web/positions', headers: auth_headers_for(users(:player))

    assert_response :success
    assert_select '[data-testid="positions-page"]'
  end

  test 'positions page shows no-positions state when no open bets' do
    users(:player).bets.update_all(status: :settled_win)
    get '/web/positions', headers: auth_headers_for(users(:player))

    assert_response :success
    assert_select '[data-testid="no-positions"]'
  end

  test 'positions page still returns JSON when requested' do
    get '/web/positions', headers: auth_headers_for(users(:player)).merge('Accept' => 'application/json')

    assert_response :success
    body = response.parsed_body

    assert body.key?('positions')
    assert body.key?('clob_positions')
  end
end
