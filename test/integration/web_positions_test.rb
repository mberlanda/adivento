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
    player = users(:player)
    player.bets.update_all(status: :settled_win)
    LmsrPosition.where(user: player).delete_all

    get '/web/positions', headers: auth_headers_for(player)

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

  test 'positions page shows LMSR positions' do
    player = users(:player)
    market = markets(:lmsr_market)
    LmsrPosition.where(user: player, market: market, side: 'YES').delete_all
    LmsrPosition.create!(user: player, market: market, side: 'YES', contracts: 5)

    get '/web/positions', headers: auth_headers_for(player)

    assert_response :success
    assert_select '[data-testid="lmsr-positions-list"]'
    assert_select "[data-testid='lmsr-position-row-#{market.id}-YES']"
  end

  test 'positions JSON includes LMSR positions' do
    player = users(:player)
    market = markets(:lmsr_market)
    LmsrPosition.where(user: player, market: market, side: 'NO').delete_all
    LmsrPosition.create!(user: player, market: market, side: 'NO', contracts: 3)

    get '/web/positions',
        headers: auth_headers_for(player).merge('Accept' => 'application/json')

    assert_response :success

    body = response.parsed_body
    lmsr_position = body.fetch('lmsr_positions').find { |pos| pos['market_id'] == market.id && pos['side'] == 'NO' }

    assert_equal 3, lmsr_position['contracts']
  end
end
