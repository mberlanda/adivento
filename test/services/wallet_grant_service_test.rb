require 'test_helper'

class WalletGrantServiceTest < ActiveSupport::TestCase
  test 'approve credits wallet and writes ledger' do
    request = faucet_requests(:pending_request)
    assert_difference('LedgerEntry.count', 1) do
      WalletGrantService.approve!(faucet_request: request, actor: users(:admin), note: 'ok')
    end

    assert_equal 'approved', request.reload.status
    assert_equal 3500, users(:player).wallet.reload.available_minor
  end

  test 'approving an already-approved request does not double-credit' do
    request = faucet_requests(:pending_request)
    WalletGrantService.approve!(faucet_request: request, actor: users(:admin), note: 'ok')
    balance_after_first = users(:player).wallet.reload.available_minor

    assert_raises(WalletGrantService::InvalidGrant) do
      WalletGrantService.approve!(faucet_request: request, actor: users(:admin), note: 'again')
    end

    assert_equal balance_after_first, users(:player).wallet.reload.available_minor
  end

  test 'reject updates status and writes audit' do
    request = FaucetRequest.create!(user: users(:player), amount_minor: 1000, status: :pending)

    assert_difference('AuditEvent.count', 1) do
      WalletGrantService.reject!(faucet_request: request, actor: users(:moderator), note: 'no')
    end

    assert_equal 'rejected', request.reload.status
  end
end
