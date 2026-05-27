require 'test_helper'

class LmsrTradesTest < ActionDispatch::IntegrationTest
  setup do
    @market = markets(:lmsr_market)
    @market.update_columns(lmsr_b_parameter: Lmsr::LmsrPricingService.b_from_subsidy(100_000), lmsr_q_yes: 0, lmsr_q_no: 0)
    users(:player).wallet.update!(available_minor: 100_000, reserved_minor: 0)
  end

  test 'player can place LMSR trade via POST /web/markets/:id/lmsr_trades' do
    post "/web/markets/#{@market.id}/lmsr_trades",
         headers: auth_headers_for(users(:player)),
         params: { side: 'YES', quantity: 10 },
         as: :json

    assert_response :created
    body = response.parsed_body

    assert_predicate body['cost_minor'], :present?
  end

  test 'returns 422 for non-LMSR market' do
    post "/web/markets/#{markets(:open_market).id}/lmsr_trades",
         headers: auth_headers_for(users(:player)),
         params: { side: 'YES', quantity: 10 },
         as: :json

    assert_response :unprocessable_entity
  end

  test 'returns 401 without authentication' do
    post "/web/markets/#{@market.id}/lmsr_trades",
         params: { side: 'YES', quantity: 10 },
         as: :json

    assert_response :unauthorized
  end
end
