require 'test_helper'

class WebBetsTest < ActionDispatch::IntegrationTest
  def setup
    @player = users(:player)
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    post '/signin', params: { email: @player.email, password: 'password123' }
  end

  test 'unauthenticated user is redirected to sign-in' do
    delete '/signout'
    post web_market_bets_path(@market), params: { market_leg_id: @yes_leg.id, stake_minor: 100 }

    assert_redirected_to '/signin'
  end

  test 'places bet and redirects to market page with notice' do
    assert_difference 'Bet.count', 1 do
      post web_market_bets_path(@market),
           params: { market_leg_id: @yes_leg.id, stake_minor: 200 }
    end

    assert_redirected_to web_market_path(@market)
    follow_redirect!

    assert_select '[data-testid="flash-notice"]', /Bet placed on YES/
  end

  test 'invalid leg redirects with alert' do
    post web_market_bets_path(@market),
         params: { market_leg_id: 0, stake_minor: 100 }

    assert_response :not_found
  end

  test 'risk limit exceeded redirects with alert' do
    post web_market_bets_path(@market),
         params: { market_leg_id: @yes_leg.id, stake_minor: 999_999_999 }

    assert_redirected_to web_market_path(@market)
    follow_redirect!

    assert_select '[data-testid="flash-alert"]'
  end
end
