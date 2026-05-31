require 'test_helper'

class WebFaucetRequestsTest < ActionDispatch::IntegrationTest
  def setup
    @player = users(:player)
    post '/signin', params: { email: @player.email, password: 'password123' }
  end

  test 'faucet create requires authentication' do
    delete '/signout'
    post '/web/faucet_requests', params: { amount_minor: 5000 }

    assert_redirected_to '/signin'
  end

  test 'faucet create with valid amount creates request and redirects to profile' do
    assert_difference 'FaucetRequest.count', 1 do
      post '/web/faucet_requests', params: { amount_minor: 5000 }
    end

    assert_redirected_to '/web/profile'
    follow_redirect!

    assert_select '[data-testid="flash-notice"]', /Token request submitted/

    req = FaucetRequest.last

    assert_equal @player, req.user
    assert_equal 5000, req.amount_minor
    assert_predicate req, :pending?
  end

  test 'faucet create defaults to 10_000 when amount is zero' do
    assert_difference 'FaucetRequest.count', 1 do
      post '/web/faucet_requests', params: { amount_minor: 0 }
    end

    assert_equal 10_000, FaucetRequest.last.amount_minor
  end

  test 'faucet create defaults to 10_000 when amount is missing' do
    assert_difference 'FaucetRequest.count', 1 do
      post '/web/faucet_requests'
    end

    assert_equal 10_000, FaucetRequest.last.amount_minor
  end

  test 'faucet create defaults to 10_000 when amount is negative' do
    assert_difference 'FaucetRequest.count', 1 do
      post '/web/faucet_requests', params: { amount_minor: -100 }
    end

    assert_equal 10_000, FaucetRequest.last.amount_minor
  end
end
