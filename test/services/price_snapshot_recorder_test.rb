require 'test_helper'

class PriceSnapshotRecorderTest < ActiveSupport::TestCase
  test 'records fixed_odds snapshot with legs data' do
    market = markets(:open_market)
    snap = PriceSnapshotRecorder.record(market)

    assert_instance_of PriceSnapshot, snap
    assert_equal 'fixed_odds', snap.mechanism_type
    assert_predicate snap.snapshot_data['legs'], :present?
  end

  test 'records clob snapshot with bid/ask' do
    market = markets(:clob_market)
    snap = PriceSnapshotRecorder.record(market)

    assert_equal 'clob', snap.mechanism_type
    assert snap.snapshot_data.key?('bid')
    assert snap.snapshot_data.key?('ask')
  end

  test 'records lmsr snapshot with probabilities' do
    market = markets(:lmsr_market)
    market.update_columns(lmsr_b_parameter: Lmsr::LmsrPricingService.b_from_subsidy(100_000))
    snap = PriceSnapshotRecorder.record(market)

    assert_equal 'lmsr', snap.mechanism_type
    assert_predicate snap.snapshot_data['yes_probability'], :present?
  end

  test 'records parimutuel snapshot with pool data' do
    market = markets(:parimutuel_market)
    snap = PriceSnapshotRecorder.record(market)

    assert_equal 'parimutuel', snap.mechanism_type
    assert snap.snapshot_data.key?('yes_probability')
    assert snap.snapshot_data.key?('pool_yes_minor')
  end
end
