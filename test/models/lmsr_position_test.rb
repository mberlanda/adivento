require 'test_helper'

class LmsrPositionTest < ActiveSupport::TestCase
  test 'validates side must be YES or NO' do
    pos = LmsrPosition.new(user: users(:player), market: markets(:lmsr_market), side: 'MAYBE', contracts: 1)

    assert_not pos.valid?
    assert_includes pos.errors[:side], 'is not included in the list'
  end

  test 'validates contracts must be non-negative' do
    pos = LmsrPosition.new(user: users(:player), market: markets(:lmsr_market), side: 'YES', contracts: -1)

    assert_not pos.valid?
  end

  test 'unique per user/market/side' do
    existing = lmsr_positions(:player_yes)
    dup = LmsrPosition.new(user: existing.user, market: existing.market, side: 'YES', contracts: 5)

    assert_not dup.valid?
  end

  test 'holding scope excludes zero-contract positions' do
    lmsr_positions(:player_yes).update!(contracts: 0)

    assert_empty LmsrPosition.for_market(markets(:lmsr_market)).holding
  end
end
