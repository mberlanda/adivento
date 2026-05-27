require 'test_helper'

class ParimutuelBetsTest < ActionDispatch::IntegrationTest
  setup do
    @market = markets(:parimutuel_market)
    @market.update_columns(parimutuel_pool_yes_minor: 0, parimutuel_pool_no_minor: 0)
    users(:player).wallet.update!(available_minor: 100_000, reserved_minor: 0)
  end

  test 'player can place parimutuel bet via POST /web/markets/:id/parimutuel_bets' do
    post "/web/markets/#{@market.id}/parimutuel_bets",
         headers: auth_headers_for(users(:player)),
         params: { side: 'YES', stake_minor: 1000 },
         as: :json

    assert_response :created
    body = response.parsed_body

    assert body['success']
  end

  test 'returns 422 for non-parimutuel market' do
    post "/web/markets/#{markets(:open_market).id}/parimutuel_bets",
         headers: auth_headers_for(users(:player)),
         params: { side: 'YES', stake_minor: 1000 },
         as: :json

    assert_response :unprocessable_entity
  end

  test 'returns 422 when insufficient funds' do
    users(:player).wallet.update!(available_minor: 0)
    post "/web/markets/#{@market.id}/parimutuel_bets",
         headers: auth_headers_for(users(:player)),
         params: { side: 'YES', stake_minor: 1000 },
         as: :json

    assert_response :unprocessable_entity
  end
end
