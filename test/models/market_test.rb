require 'test_helper'

class MarketTest < ActiveSupport::TestCase
  test 'has valid fixture' do
    assert_predicate markets(:open_market), :valid?
  end

  test 'requires question' do
    market = markets(:open_market)
    market.question = nil

    assert_not market.valid?
  end

  def build_draft
    Market.new(
      question: 'Q?',
      description: 'D',
      mechanism_type: 'binary',
      fee_bps: 0,
      liability_cap_minor: 100_000,
      created_by: users(:admin)
    )
  end

  test 'draft market with 0 legs is valid' do
    market = build_draft

    assert_predicate market, :valid?
  end

  test 'cannot transition to open with 0 legs' do
    market = build_draft
    market.save!
    market.status = :open

    assert_not market.valid?
    assert_includes market.errors[:base], 'Market must have exactly 2 legs to open'
  end

  test 'cannot transition to open with 1 leg' do
    market = build_draft
    market.save!
    market.market_legs.create!(label: 'YES', odds_minor: 5000)
    market.status = :open

    assert_not market.valid?
    assert_includes market.errors[:base], 'Market must have exactly 2 legs to open'
  end

  test 'can transition to open with exactly 2 legs' do
    market = build_draft
    market.save!
    market.market_legs.create!(label: 'YES', odds_minor: 5000)
    market.market_legs.create!(label: 'NO', odds_minor: 5000)
    market.status = :open

    assert_predicate market, :valid?
  end
end
