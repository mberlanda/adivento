require 'test_helper'

class BackofficeManagementTest < ActionDispatch::IntegrationTest
  test 'admin can view permissions matrix' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    get '/backoffice/permissions'

    assert_response :success
    assert_match 'Role Permission Matrix', response.body
  end

  test 'admin can update role permission with reason' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }

    permission = permissions(:market_update)
    assert_difference('AuditEvent.count', 1) do
      patch "/backoffice/permissions/#{permission.id}", params: {
        role_name: 'moderator',
        enabled: true,
        reason: 'delegation'
      }
    end

    assert_response :redirect
    assert RolePermission.exists?(role_name: 'moderator', permission: permission)
  end

  test 'admin can create ad hoc deny grant' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }

    assert_difference('UserGrant.count', 1) do
      post '/backoffice/grants', params: {
        user_id: users(:moderator).id,
        permission_id: permissions(:market_settle).id,
        allow: false,
        reason: 'cooldown'
      }
    end

    assert_response :redirect
  end

  test 'admin can create template' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }

    assert_difference('MarketTemplate.count', 1) do
      post '/backoffice/templates', params: {
        key: 'election_binary',
        name: 'Election Binary',
        description: 'Election model',
        default_legs: 'YES,NO',
        default_duration_hours: 72,
        active: true,
        reason: 'new catalog'
      }
    end

    assert_response :redirect
  end

  test 'admin can edit a template' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    template = market_templates(:binary)

    get "/backoffice/templates/#{template.id}/edit"

    assert_response :success
    assert_match 'Edit Template', response.body
  end

  test 'admin can update a template' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    template = market_templates(:binary)

    patch "/backoffice/templates/#{template.id}", params: {
      key: template.key,
      name: 'Updated Binary',
      description: 'Updated desc',
      default_legs: 'YES,NO',
      default_duration_hours: 48,
      active: true,
      reason: 'name correction'
    }

    assert_response :redirect
    template.reload

    assert_equal 'Updated Binary', template.name
    assert AuditEvent.exists?(action: 'template.update', target_id: template.id)
  end

  test 'admin can deactivate a template' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    template = market_templates(:binary)

    delete "/backoffice/templates/#{template.id}", params: { reason: 'retiring template' }

    assert_response :redirect
    template.reload

    assert_not template.active?
    assert AuditEvent.exists?(action: 'template.deactivate', target_id: template.id)
  end

  test 'admin can list markets in backoffice' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    get '/backoffice/markets'

    assert_response :success
    assert_match 'Markets', response.body
  end

  test 'admin can create a market in backoffice' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }

    assert_difference('Market.count', 1) do
      post '/backoffice/markets', params: {
        question: 'Will it snow tomorrow?',
        description: 'Weather prediction',
        legs: 'YES,NO',
        fee_bps: 100,
        liability_cap_minor: 50_000,
        mechanism_type: 'fixed_odds'
      }
    end

    market = Market.last

    assert_response :redirect
    assert_operator market.market_legs.count, :>=, 2
    assert AuditEvent.exists?(action: 'market.create', target_id: market.id)
  end

  test 'admin can create a market with category and tags' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }

    assert_difference('Market.count', 1) do
      post '/backoffice/markets', params: {
        question: 'Will the Fed hike rates?',
        description: 'Economics prediction',
        legs: 'YES,NO',
        fee_bps: 100,
        liability_cap_minor: 50_000,
        mechanism_type: 'fixed_odds',
        category: 'economics',
        tags_input: 'fed, rates, macro'
      }
    end

    market = Market.last

    assert_response :redirect
    assert_equal 'economics', market.category
    assert_equal %w[fed rates macro], market.tags
  end

  test 'admin can open a draft market in backoffice' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    market = markets(:draft_market)
    market.market_legs.create!(label: 'YES', odds_minor: 5000)
    market.market_legs.create!(label: 'NO', odds_minor: 5000)

    post "/backoffice/markets/#{market.id}/open"

    assert_response :redirect
    market.reload

    assert_predicate market, :open?
  end

  test 'admin can view market detail in backoffice' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    market = markets(:open_market)

    get "/backoffice/markets/#{market.id}"

    assert_response :success
    assert_match market.question, response.body
  end

  test 'admin can settle an open market in backoffice' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    market = markets(:open_market)

    post "/backoffice/markets/#{market.id}/settle", params: {
      outcome: 'YES',
      reason: 'result confirmed'
    }

    assert_response :redirect
    market.reload

    assert_predicate market, :settled?
    assert_equal 'YES', market.settled_outcome
  end

  test 'player cannot access backoffice markets' do
    post '/signin', params: { email: users(:player).email, password: 'password123' }
    get '/backoffice/markets'

    assert_response :redirect
  end

  test 'admin can update market details via PATCH' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    market = markets(:open_market)
    close_time = 1.week.from_now.strftime('%Y-%m-%dT%H:%M')

    patch "/backoffice/markets/#{market.id}", params: {
      close_at: close_time,
      resolution_criteria: 'Updated resolution criteria',
      resolution_source: 'Official source',
      category: 'sports',
      tags_input: 'nba, finals'
    }

    assert_response :redirect
    market.reload

    assert_equal 'Updated resolution criteria', market.resolution_criteria
    assert_equal 'Official source', market.resolution_source
    assert_equal 'sports', market.category
    assert_includes market.tags, 'nba'
  end
end
