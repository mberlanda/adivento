require 'test_helper'

class SettlementServiceTest < ActiveSupport::TestCase
  setup do
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
    @actor = users(:admin)

    # Remove fixture bets so only test-controlled bets are settled
    @market.bets.delete_all

    @winner_user = users(:player)
    if @winner_user.wallet
      @winner_user.wallet.update!(available_minor: 10_000, reserved_minor: 0)
    else
      @winner_user.create_wallet!(available_minor: 10_000, reserved_minor: 0)
    end

    @loser_user = users(:moderator)
    if @loser_user.wallet
      @loser_user.wallet.update!(available_minor: 10_000, reserved_minor: 0)
    else
      @loser_user.create_wallet!(available_minor: 10_000, reserved_minor: 0)
    end

    @winner_bet = Bet.create!(
      user: @winner_user,
      market: @market,
      market_leg: @yes_leg,
      stake_minor: 1000,
      fee_minor: 10,
      net_stake_minor: 990,
      odds_minor: 5000,
      potential_payout_minor: 5000,
      status: :open
    )
    @loser_bet = Bet.create!(
      user: @loser_user,
      market: @market,
      market_leg: @no_leg,
      stake_minor: 1000,
      fee_minor: 10,
      net_stake_minor: 990,
      odds_minor: 5000,
      potential_payout_minor: 5000,
      status: :open
    )
  end

  test 'settles market and transitions bets' do
    SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor)

    @market.reload

    assert_predicate @market, :settled?
    assert_equal 'YES', @market.settled_outcome

    @winner_bet.reload

    assert_predicate @winner_bet, :settled_win?

    @loser_bet.reload

    assert_predicate @loser_bet, :settled_loss?
  end

  test 'credits payout to winner wallet' do
    initial_balance = @winner_user.wallet.available_minor

    SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor)

    @winner_user.wallet.reload

    assert_equal initial_balance + @winner_bet.potential_payout_minor, @winner_user.wallet.available_minor
  end

  test 'does not change loser wallet on settlement' do
    initial_balance = @loser_user.wallet.available_minor

    SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor)

    @loser_user.wallet.reload

    assert_equal initial_balance, @loser_user.wallet.available_minor
  end

  test 'creates ledger entry for each winner' do
    assert_difference("LedgerEntry.where(entry_type: 'BET_WIN_PAYOUT').count", 1) do
      SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor)
    end
  end

  test 'creates audit events for market settle and each bet' do
    assert_difference('AuditEvent.count', 3) do
      SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor)
    end
  end

  test 'raises on invalid outcome' do
    assert_raises(SettlementService::InvalidSettlement) do
      SettlementService.settle!(market: @market, outcome: 'DRAW', actor: @actor)
    end
  end

  test 'raises if market is not open' do
    @market.update!(status: :draft)
    assert_raises(SettlementService::InvalidSettlement) do
      SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor)
    end
  end

  test 'skips already-settled or voided bets' do
    @loser_bet.update!(status: :voided)

    assert_nothing_raised do
      SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor)
    end

    @loser_bet.reload

    assert_predicate @loser_bet, :voided?
  end

  test 'SettlementService delegates to ClobSettlementHandler for clob markets' do
    @market.update_columns(mechanism_type: 'clob', taker_fee_bps: 70)
    @market.bets.delete_all
    @market.orders.delete_all
    assert_nothing_raised do
      SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor)
    end
    @market.reload

    assert_predicate @market, :settled?
  end
end
