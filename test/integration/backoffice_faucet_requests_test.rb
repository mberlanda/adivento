# test/integration/backoffice_faucet_requests_test.rb
require 'test_helper'

class BackofficeFaucetRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @moderator = users(:moderator)
    @player = users(:player)

    @pending_request = FaucetRequest.create!(
      user: @player,
      amount_minor: 5_000
    )
  end

  def sign_in(user)
    post '/signin', params: { email: user.email, password: 'password123' }
  end

  test 'moderator can view faucet requests list' do
    sign_in @moderator
    get '/backoffice/faucet_requests'

    assert_response :success
  end

  test 'player cannot access faucet requests list' do
    sign_in @player
    get '/backoffice/faucet_requests'

    assert_response :redirect
  end

  test 'unauthenticated request is redirected' do
    get '/backoffice/faucet_requests'

    assert_response :redirect
  end

  test 'moderator can approve a pending request' do
    sign_in @moderator
    initial_balance = @player.wallet.available_minor

    post "/backoffice/faucet_requests/#{@pending_request.id}/approve"

    assert_response :redirect
    follow_redirect!

    assert_response :success

    @pending_request.reload

    assert_predicate @pending_request, :approved?

    assert_equal initial_balance + 5_000, @player.wallet.reload.available_minor
    assert AuditEvent.exists?(action: 'faucet_request.approve', target_id: @pending_request.id)
  end

  test 'moderator can reject a pending request' do
    sign_in @moderator

    post "/backoffice/faucet_requests/#{@pending_request.id}/reject"

    assert_response :redirect
    @pending_request.reload

    assert_predicate @pending_request, :rejected?
  end

  test 'cannot approve an already-approved request' do
    @pending_request.update!(status: :approved, reviewed_by: @admin)
    sign_in @moderator
    initial_balance = @player.wallet.reload.available_minor

    post "/backoffice/faucet_requests/#{@pending_request.id}/approve"

    assert_response :redirect
    assert_equal initial_balance, @player.wallet.reload.available_minor
  end

  test 'cannot reject an already-rejected request' do
    @pending_request.update!(status: :rejected, reviewed_by: @admin)
    sign_in @moderator

    post "/backoffice/faucet_requests/#{@pending_request.id}/reject"

    assert_response :redirect
    follow_redirect!

    assert_match 'already been processed', flash[:alert]
  end
end
