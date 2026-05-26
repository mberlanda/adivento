require "test_helper"

class BetslipExecutionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @user.wallet.update!(available_minor: 100_000)
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
    @market.bets.delete_all
  end

  def build_quote(stake_yes: 500, stake_no: 1000, key: "exec-#{SecureRandom.hex(4)}")
    BetslipQuoteService.call(
      user: @user,
      items: [
        { market_leg_id: @yes_leg.id, stake_minor: stake_yes },
        { market_leg_id: @no_leg.id, stake_minor: stake_no }
      ],
      idempotency_key: key
    )
  end

  test "execute! creates bets, marks quote executed, writes audit event" do
    quote = build_quote
    initial_balance = @user.wallet.available_minor

    execution = BetslipExecutionService.execute!(quote: quote, actor: @user)

    quote.reload
    assert_predicate quote, :executed?
    assert_predicate execution, :completed?
    assert_equal 2, execution.bet_ids.length

    @user.wallet.reload
    assert_equal initial_balance - 1500, @user.wallet.available_minor

    bets = Bet.where(id: execution.bet_ids)
    assert bets.all?(&:open?)

    assert AuditEvent.where(action: "betslip.execute", target_type: "BetslipExecution", target_id: execution.id).exists?
  end

  test "execute! raises ExpiredQuote when quote has expired" do
    quote = build_quote
    quote.update_column(:expires_at, 1.second.ago)

    initial_balance = @user.wallet.available_minor

    assert_raises(BetslipExecutionService::ExpiredQuote) do
      BetslipExecutionService.execute!(quote: quote, actor: @user)
    end

    @user.wallet.reload
    assert_equal initial_balance, @user.wallet.available_minor
    assert_equal 0, Bet.where(user: @user).where.not(status: :voided).count
  end

  test "execute! raises AlreadyExecuted when quote already executed" do
    quote = build_quote
    BetslipExecutionService.execute!(quote: quote, actor: @user)

    assert_raises(BetslipExecutionService::AlreadyExecuted) do
      BetslipExecutionService.execute!(quote: quote.reload, actor: @user)
    end
  end

  test "execute! is all-or-nothing when one item's market closes mid-flight" do
    quote = build_quote
    # Simulate the market becoming non-open after the quote was created.
    @market.update!(status: :cancelled)
    initial_balance = @user.wallet.available_minor

    assert_raises(BetslipExecutionService::ExecutionFailed) do
      BetslipExecutionService.execute!(quote: quote, actor: @user)
    end

    @user.wallet.reload
    assert_equal initial_balance, @user.wallet.available_minor
    assert_equal 0, Bet.where(market: @market, user: @user).count
    assert_predicate quote.reload, :pending?
  end
end
