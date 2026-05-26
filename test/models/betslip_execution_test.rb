require "test_helper"

class BetslipExecutionTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @quote = BetslipQuote.create!(
      user: @user,
      idempotency_key: "exec-test-key",
      items: [],
      total_stake_minor: 0,
      expires_at: 60.seconds.from_now
    )
  end

  test "valid execution belongs to a quote and user" do
    execution = BetslipExecution.create!(
      betslip_quote: @quote,
      user: @user,
      bet_ids: [1, 2],
      status: :completed
    )
    assert execution.persisted?
    assert_predicate execution, :completed?
    assert_equal [1, 2], execution.bet_ids
  end

  test "BetslipQuote has_one execution" do
    execution = BetslipExecution.create!(
      betslip_quote: @quote,
      user: @user,
      bet_ids: [],
      status: :completed
    )
    assert_equal execution, @quote.reload.betslip_execution
  end
end
