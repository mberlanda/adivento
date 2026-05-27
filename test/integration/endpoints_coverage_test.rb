require 'test_helper'

class EndpointsCoverageTest < ActionDispatch::IntegrationTest
  test 'signin page renders form fields' do
    get '/signin'

    assert_response :success
    assert_match '<h1>Sign in</h1>', response.body
    assert_match 'name="email"', response.body
    assert_match 'name="password"', response.body
  end

  test 'signout clears session for backoffice access' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    get '/backoffice'

    assert_response :success

    delete '/signout'

    assert_response :redirect

    get '/backoffice'

    assert_response :redirect
    assert_match '/signin', response.headers['Location']
  end

  test 'web markets index endpoint renders explorer content' do
    get '/web/markets'

    assert_response :success
    assert_match 'Explore Markets', response.body
    assert_match markets(:open_market).question, response.body
  end

  test 'admin can view grants and templates pages' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }

    get '/backoffice/grants'

    assert_response :success
    assert_match 'User Ad Hoc Grants', response.body

    get '/backoffice/templates'

    assert_response :success
    assert_match 'Market Templates', response.body
    assert_match market_templates(:binary).name, response.body
  end

  test 'backoffice permission update requires reason' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    permission = permissions(:market_update)
    existing = RolePermission.exists?(role_name: 'moderator', permission: permission)

    assert_no_difference('AuditEvent.count') do
      patch "/backoffice/permissions/#{permission.id}", params: { role_name: 'moderator', enabled: false, reason: '' }
    end

    assert_response :redirect
    assert_equal existing, RolePermission.exists?(role_name: 'moderator', permission: permission)
  end

  test 'backoffice grant creation requires reason' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }

    assert_no_difference('UserGrant.count') do
      post '/backoffice/grants', params: {
        user_id: users(:moderator).id,
        permission_id: permissions(:market_settle).id,
        allow: false,
        reason: ''
      }
    end

    assert_response :redirect
  end

  test 'admin faucet index returns serialized shape' do
    get '/admin/faucet_requests', headers: auth_headers_for(users(:moderator)), as: :json

    assert_response :success
    payload = response.parsed_body

    assert_kind_of Array, payload
    assert_equal payload.first.keys.sort, %w[amount_minor id note reviewed_by status user_id].sort
  end

  test 'admin leg creation rejects duplicate labels' do
    market = markets(:draft_market)
    market.market_legs.create!(label: 'YES', odds_minor: 5000)

    assert_equal 1, market.market_legs.count

    post "/admin/markets/#{market.id}/legs",
         params: { label: 'YES', odds_minor: 2500 },
         headers: auth_headers_for(users(:admin)),
         as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body['errors'].join(' ').downcase, 'taken'
  end

  test 'admin risk endpoint requires authentication' do
    get "/admin/markets/#{markets(:open_market).id}/risk", as: :json

    assert_response :unauthorized
  end

  test 'admin can list faucet requests with review metadata after reject' do
    request = FaucetRequest.create!(user: users(:player), amount_minor: 700, status: :pending)

    post "/admin/faucet_requests/#{request.id}/reject",
         params: { note: 'policy' },
         headers: auth_headers_for(users(:moderator)),
         as: :json

    assert_response :success

    get '/admin/faucet_requests', headers: auth_headers_for(users(:moderator)), as: :json

    assert_response :success

    payload = response.parsed_body
    row = payload.find { |entry| entry['id'] == request.id }

    assert_equal 'rejected', row['status']
    assert_equal users(:moderator).id, row['reviewed_by']
    assert_equal 'policy', row['note']
  end
end
