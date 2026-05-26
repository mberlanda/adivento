require "test_helper"

class BetVoidServiceTest < ActiveSupport::TestCase
  test "void refunds wallet and marks bet voided" do
    bet = bets(:player_yes_open_bet)
    user = bet.user
    before_balance = user.wallet.available_minor

    assert_difference("LedgerEntry.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        BetVoidService.void!(bet: bet, actor: users(:admin), reason: "operator correction")
      end
    end

    assert_equal "voided", bet.reload.status
    assert_equal before_balance + bet.stake_minor, user.wallet.reload.available_minor
    assert_equal "BET_VOID_REFUND", LedgerEntry.order(:created_at).last.entry_type
    assert_equal "bet.void", AuditEvent.order(:created_at).last.action
  end

  test "requires open status and non-empty reason" do
    bet = bets(:player_yes_open_bet)
    bet.update!(status: :voided)

    assert_raises(BetVoidService::InvalidVoid) do
      BetVoidService.void!(bet: bet, actor: users(:admin), reason: "x")
    end

    assert_raises(BetVoidService::InvalidVoid) do
      BetVoidService.void!(bet: bets(:moderator_no_open_bet), actor: users(:admin), reason: "")
    end
  end
end
