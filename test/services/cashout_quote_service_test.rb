require 'test_helper'

class CashoutQuoteServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @user.wallet.update!(available_minor: 100_000)
    @market = markets(:open_market)
    @market.update!(fee_bps: 100) # 1%
    @yes_leg = market_legs(:yes_leg)
    @yes_leg.update!(odds_minor: 4000) # 0.4x payout ratio (odds capped at 10_000)
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

  test 'computes gross, fee, and net payout' do
    quote = CashoutQuoteService.quote(bet: @bet)

    assert_equal @bet.id, quote.bet_id
    assert_equal 2000, quote.gross_payout_minor
    assert_equal 20, quote.fee_minor
    assert_equal 1980, quote.net_payout_minor
    assert_in_delta 60.0, (quote.expires_at - Time.current), 5.0
  end

  test 'raises InvalidPosition when bet is not open' do
    @bet.update!(status: :voided)
    assert_raises(CashoutQuoteService::InvalidPosition) do
      CashoutQuoteService.quote(bet: @bet)
    end
  end

  test "raises InvalidPosition when bet's market is not open" do
    @market.update!(status: :cancelled)
    assert_raises(CashoutQuoteService::InvalidPosition) do
      CashoutQuoteService.quote(bet: @bet.reload)
    end
  end
end
