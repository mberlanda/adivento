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
      mechanism_type: 'fixed_odds',
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

  test 'mechanism_type must be one of the four valid values' do
    m = markets(:draft_market).dup
    m.mechanism_type = 'invalid_type'

    assert_not m.valid?
    assert_includes m.errors[:mechanism_type], 'is not included in the list'
  end

  test 'clob market requires taker_fee_bps in 0..200' do
    m = markets(:draft_market).dup
    m.mechanism_type = 'clob'
    m.taker_fee_bps = nil

    assert_not m.valid?
    m.taker_fee_bps = 201

    assert_not m.valid?
    m.taker_fee_bps = 70

    assert_predicate m, :valid?
  end

  test 'lmsr market requires positive liquidity_subsidy_minor' do
    m = markets(:draft_market).dup
    m.mechanism_type = 'lmsr'
    m.liquidity_subsidy_minor = nil
    m.spread_fee_bps = 50

    assert_not m.valid?
    m.liquidity_subsidy_minor = 0

    assert_not m.valid?
    m.liquidity_subsidy_minor = 100_000

    assert_predicate m, :valid?
  end

  test 'parimutuel market requires takeout_bps in 1000..3000' do
    m = markets(:draft_market).dup
    m.mechanism_type = 'parimutuel'
    m.takeout_bps = 500

    assert_not m.valid?
    m.takeout_bps = 1500

    assert_predicate m, :valid?
  end

  test 'mechanism_type cannot change once market is open' do
    m = markets(:open_market)
    m.mechanism_type = 'clob'

    assert_not m.valid?
    assert_includes m.errors[:mechanism_type], 'cannot be changed after market is open'
  end

  test 'pricing_engine returns correct class for each mechanism_type' do
    m = markets(:open_market)

    m.mechanism_type = 'fixed_odds'

    assert_instance_of Market::FixedOddsPricingEngine, m.pricing_engine

    m.mechanism_type = 'clob'

    assert_instance_of Market::ClobPricingEngine, m.pricing_engine

    m.mechanism_type = 'lmsr'

    assert_instance_of Market::LmsrPricingEngine, m.pricing_engine

    m.mechanism_type = 'parimutuel'

    assert_instance_of Market::ParimutuelPricingEngine, m.pricing_engine
  end
end
