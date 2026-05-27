require 'test_helper'

class AdminPermissionsTest < ActionDispatch::IntegrationTest
  test 'moderator cannot create market' do
    post '/admin/markets',
         params: { question: 'Q', description: 'D' },
         headers: auth_headers_for(users(:moderator)),
         as: :json

    assert_response :forbidden
  end

  test 'admin can create market with default legs' do
    assert_difference('Market.count', 1) do
      post '/admin/markets',
           params: { question: 'Will sun rise?', description: 'Test market' },
           headers: auth_headers_for(users(:admin)),
           as: :json
    end

    assert_response :created
    market = Market.order(:created_at).last

    assert_equal %w[NO YES], market.market_legs.order(:label).pluck(:label)
  end

  test 'moderator can add leg to a draft market with fewer than 2 legs' do
    market = markets(:draft_market)

    assert_operator market.market_legs.count, :<, 2

    post "/admin/markets/#{market.id}/legs",
         params: { label: 'YES', odds_minor: 5000 },
         headers: auth_headers_for(users(:moderator)),
         as: :json

    assert_response :created
  end

  test 'moderator can settle an open market' do
    post "/admin/markets/#{markets(:open_market).id}/settle",
         params: { outcome: 'YES', reason: 'official result' },
         headers: auth_headers_for(users(:moderator)),
         as: :json

    assert_response :success
    assert_equal 'settled', markets(:open_market).reload.status
  end

  test 'admin can update market content' do
    patch "/admin/markets/#{markets(:draft_market).id}",
          params: { question: 'Updated question' },
          headers: auth_headers_for(users(:admin)),
          as: :json

    assert_response :success
    assert_equal 'Updated question', markets(:draft_market).reload.question
  end

  test 'settle fails with invalid outcome' do
    post "/admin/markets/#{markets(:open_market).id}/settle",
         params: { outcome: 'INVALID' },
         headers: auth_headers_for(users(:moderator)),
         as: :json

    assert_response :unprocessable_entity
  end

  test 'moderator can reject faucet request' do
    request = FaucetRequest.create!(user: users(:player), amount_minor: 1500, status: :pending)

    post "/admin/faucet_requests/#{request.id}/reject",
         params: { note: 'policy' },
         headers: auth_headers_for(users(:moderator)),
         as: :json

    assert_response :success
    assert_equal 'rejected', request.reload.status
  end
end
