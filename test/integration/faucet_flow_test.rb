require "test_helper"

class FaucetFlowTest < ActionDispatch::IntegrationTest
  test "guest cannot request faucet credit" do
    post "/faucet_requests", params: { amount_minor: 1000 }, as: :json
    assert_response :unauthorized
  end

  test "player can request faucet credit" do
    assert_difference("FaucetRequest.count", 1) do
      post "/faucet_requests",
           params: { amount_minor: 1234 },
           headers: auth_headers_for(users(:player)),
           as: :json
    end

    assert_response :created
  end

  test "moderator can approve faucet request and credit wallet" do
    request = faucet_requests(:pending_request)
    wallet = users(:player).wallet

    assert_difference("LedgerEntry.count", 1) do
      post "/admin/faucet_requests/#{request.id}/approve",
           params: { note: "weekly grant" },
           headers: auth_headers_for(users(:moderator)),
           as: :json
    end

    assert_response :success
    assert_equal "approved", request.reload.status
    assert_equal 3500, wallet.reload.available_minor
  end
end
