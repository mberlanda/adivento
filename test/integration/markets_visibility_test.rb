require 'test_helper'

class MarketsVisibilityTest < ActionDispatch::IntegrationTest
  test 'guest only sees open or settled markets' do
    get '/markets'

    assert_response :success
    ids = response.parsed_body.pluck('id')

    assert_includes ids, markets(:open_market).id
    assert_not_includes ids, markets(:draft_market).id
  end

  test 'authenticated user can see draft market' do
    get '/markets', headers: auth_headers_for(users(:player))

    assert_response :success
    ids = response.parsed_body.pluck('id')

    assert_includes ids, markets(:draft_market).id
  end

  test 'guest cannot view draft market details' do
    get "/markets/#{markets(:draft_market).id}"

    assert_response :not_found
  end

  test 'authenticated user can view draft market details' do
    get "/markets/#{markets(:draft_market).id}", headers: auth_headers_for(users(:player))

    assert_response :success
  end
end
