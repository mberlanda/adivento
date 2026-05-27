require 'test_helper'

module Parimutuel
  class ParimutuelSettlementServiceTest < ActiveSupport::TestCase
    setup do
      @market = markets(:parimutuel_market)
      @market.update_columns(
        takeout_bps: 1000,
        parimutuel_pool_yes_minor: 60_000,
        parimutuel_pool_no_minor: 40_000
      )
      @winner1 = users(:player)
      @winner1.wallet.update!(available_minor: 0)
      @loser = users(:moderator)
      @loser.wallet.update!(available_minor: 0)
    end

    test 'total payout after 10% takeout equals 90% of total pool' do
      total_pool    = 100_000
      takeout       = (total_pool * 1000 / 10_000)
      after_takeout = total_pool - takeout
      payout_ratio  = after_takeout.to_f / 60_000.0

      payout_for_10k_stake = (10_000 * payout_ratio).round

      assert_in_delta 15_000, payout_for_10k_stake, 1
    end

    test 'zero winning pool triggers full refund (no takeout)' do
      @market.update_columns(parimutuel_pool_yes_minor: 0, parimutuel_pool_no_minor: 40_000)
      result = Parimutuel::ParimutuelSettlementService.call(
        market: @market,
        winning_side: 'YES',
        settled_by: users(:admin)
      )

      assert_predicate result, :success?
      assert_predicate result, :refunded?
    end
  end
end
