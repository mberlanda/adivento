require 'test_helper'

class CashoutExecutionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @user.wallet.update!(available_minor: 50_000)
    @market = markets(:open_market)
    @market.update!(fee_bps: 100)
    @yes_leg = market_legs(:yes_leg)
    @yes_leg.update!(odds_minor: 4000)
    @market.bets.delete_all
    # Stake 5000 * odds 4000 / 10_000 = 2000 gross payout
    @bet = Bet.create!(
      user: @user,
      market: @market,
      market_leg: @yes_leg,
      stake_minor: 5000,
      fee_minor: 50,
      net_stake_minor: 4950,
      odds_minor: @yes_leg.odds_minor,
      potential_payout_minor: 2000,
      status: :open
    )
  end

  test 'credits net payout, voids bet, writes ledger and audit' do
    initial_balance = @user.wallet.available_minor

    credited = CashoutExecutionService.execute!(bet: @bet, actor: @user)

    assert_equal 1980, credited
    @bet.reload

    assert_predicate @bet, :voided?

    @user.wallet.reload

    assert_equal initial_balance + 1980, @user.wallet.available_minor

    assert LedgerEntry.exists?(user: @user, entry_type: 'BET_CASHOUT_PAYOUT', direction: 'credit',
                               amount_minor: 1980)
    assert LedgerEntry.exists?(user: @user, entry_type: 'BET_CASHOUT_FEE', direction: 'debit', amount_minor: 20)
    assert AuditEvent.exists?(action: 'bet.cashout', target_type: 'Bet', target_id: @bet.id)
  end

  test 'skips fee ledger entry when fee is zero' do
    @market.update!(fee_bps: 0)
    CashoutExecutionService.execute!(bet: @bet.reload, actor: @user)

    assert_not LedgerEntry.exists?(user: @user, entry_type: 'BET_CASHOUT_FEE')
  end

  test 'raises InvalidPosition when bet is already voided' do
    @bet.update!(status: :voided)
    assert_raises(CashoutExecutionService::InvalidPosition) do
      CashoutExecutionService.execute!(bet: @bet, actor: @user)
    end
  end

  test 'raises InvalidPosition when bet is settled' do
    @bet.update!(status: :settled_win)
    assert_raises(CashoutExecutionService::InvalidPosition) do
      CashoutExecutionService.execute!(bet: @bet, actor: @user)
    end
  end
end
