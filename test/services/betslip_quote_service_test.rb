require 'test_helper'

class BetslipQuoteServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
  end

  test 'builds a quote with potential payouts and total stake' do
    quote = BetslipQuoteService.call(
      user: @user,
      items: [
        { market_leg_id: @yes_leg.id, stake_minor: 500 },
        { market_leg_id: @no_leg.id, stake_minor: 1000 }
      ],
      idempotency_key: 'k1'
    )

    assert_predicate quote, :persisted?
    assert_equal 1500, quote.total_stake_minor
    assert_equal 2, quote.items.length
    assert_equal @yes_leg.id, quote.items.first['market_leg_id']
    expected_payout = (500 * @yes_leg.odds_minor / 10_000.0).floor

    assert_equal expected_payout, quote.items.first['potential_payout_minor']
    assert_in_delta 60.0, (quote.expires_at - Time.current), 5.0
  end

  test 'replays existing quote when idempotency_key matches and payload matches' do
    quote1 = BetslipQuoteService.call(
      user: @user,
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: 'replay-key'
    )
    quote2 = BetslipQuoteService.call(
      user: @user,
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: 'replay-key'
    )

    assert_equal quote1.id, quote2.id
  end

  test 'raises Conflict when idempotency_key matches but payload differs' do
    BetslipQuoteService.call(
      user: @user,
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: 'conflict-key'
    )
    assert_raises(BetslipQuoteService::Conflict) do
      BetslipQuoteService.call(
        user: @user,
        items: [{ market_leg_id: @yes_leg.id, stake_minor: 999 }],
        idempotency_key: 'conflict-key'
      )
    end
  end

  test "raises InvalidQuote when leg's market is not open" do
    draft_market = markets(:draft_market)
    draft_leg = MarketLeg.create!(market: draft_market, label: 'X', odds_minor: 5000)

    assert_raises(BetslipQuoteService::InvalidQuote) do
      BetslipQuoteService.call(
        user: @user,
        items: [{ market_leg_id: draft_leg.id, stake_minor: 100 }],
        idempotency_key: 'draft-key'
      )
    end
  end

  test 'raises InvalidQuote when market_leg does not exist' do
    assert_raises(BetslipQuoteService::InvalidQuote) do
      BetslipQuoteService.call(
        user: @user,
        items: [{ market_leg_id: 999_999, stake_minor: 100 }],
        idempotency_key: 'missing-leg-key'
      )
    end
  end

  test 'raises InvalidQuote when items is empty' do
    assert_raises(BetslipQuoteService::InvalidQuote) do
      BetslipQuoteService.call(user: @user, items: [], idempotency_key: 'empty-key')
    end
  end

  test 'raises InvalidQuote when idempotency_key is blank' do
    assert_raises(BetslipQuoteService::InvalidQuote) do
      BetslipQuoteService.call(
        user: @user,
        items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
        idempotency_key: ''
      )
    end
  end

  test 'raises InvalidQuote when stake is not positive' do
    assert_raises(BetslipQuoteService::InvalidQuote) do
      BetslipQuoteService.call(
        user: @user,
        items: [{ market_leg_id: @yes_leg.id, stake_minor: 0 }],
        idempotency_key: 'zero-stake-key'
      )
    end
  end
end
