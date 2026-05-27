require 'test_helper'

class AdminMarketRiskTest < ActionDispatch::IntegrationTest
  test 'moderator can read market risk metrics' do
    get "/admin/markets/#{markets(:open_market).id}/risk",
        headers: auth_headers_for(users(:moderator)),
        as: :json

    assert_response :success
    payload = response.parsed_body

    assert_equal markets(:open_market).id, payload['market_id']
    assert payload['pnl_by_outcome_minor'].key?('YES')
    assert payload.key?('worst_case_liability_minor')
  end

  test 'player cannot read market risk metrics' do
    get "/admin/markets/#{markets(:open_market).id}/risk",
        headers: auth_headers_for(users(:player)),
        as: :json

    assert_response :forbidden
  end
end
