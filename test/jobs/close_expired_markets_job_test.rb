require 'test_helper'

class CloseExpiredMarketsJobTest < ActiveJob::TestCase
  setup do
    @market = markets(:open_market)
    @market.bets.delete_all
  end

  test 'transitions open market with past close_at to closed' do
    @market.update_columns(close_at: 1.minute.ago, status: Market.statuses[:open])
    CloseExpiredMarketsJob.perform_now

    assert_predicate @market.reload, :closed?
  end

  test 'does not transition market whose close_at is in the future' do
    @market.update_columns(close_at: 1.hour.from_now, status: Market.statuses[:open])
    CloseExpiredMarketsJob.perform_now

    assert_predicate @market.reload, :open?
  end

  test 'does not transition market with nil close_at' do
    @market.update_columns(close_at: nil, status: Market.statuses[:open])
    CloseExpiredMarketsJob.perform_now

    assert_predicate @market.reload, :open?
  end

  test 'creates AuditEvent for each closed market' do
    @market.update_columns(close_at: 1.minute.ago, status: Market.statuses[:open])
    assert_difference('AuditEvent.count', 1) do
      CloseExpiredMarketsJob.perform_now
    end
    event = AuditEvent.last

    assert_equal 'market.close', event.action
    assert_equal @market.id, event.target_id
  end

  test 'does not close already-settled markets' do
    @market.update_columns(
      close_at: 1.minute.ago,
      status: Market.statuses[:settled]
    )
    CloseExpiredMarketsJob.perform_now

    assert_predicate @market.reload, :settled?
  end
end
