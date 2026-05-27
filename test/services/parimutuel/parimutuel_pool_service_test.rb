require 'test_helper'

module Parimutuel
  class ParimutuelPoolServiceTest < ActiveSupport::TestCase
    setup do
      @market = markets(:parimutuel_market)
      @market.update_columns(parimutuel_pool_yes_minor: 0, parimutuel_pool_no_minor: 0)
      @player = users(:player)
      @player.wallet.update!(available_minor: 100_000, reserved_minor: 0)
    end

    test 'placing a YES bet debits wallet and increments pool_yes' do
      result = Parimutuel::ParimutuelPoolService.add_stake(market: @market, user: @player, side: 'YES', stake_minor: 1000)

      assert_predicate result, :success?
      @market.reload

      assert_equal 1000, @market.parimutuel_pool_yes_minor
      assert_equal 99_000, @player.wallet.reload.available_minor
    end

    test 'PARIMUTUEL_STAKE ledger entry written' do
      assert_difference -> { LedgerEntry.where(entry_type: 'PARIMUTUEL_STAKE').count }, 1 do
        Parimutuel::ParimutuelPoolService.add_stake(market: @market, user: @player, side: 'YES', stake_minor: 1000)
      end
    end

    test 'implied YES probability is 50% when pools are equal' do
      @market.update_columns(parimutuel_pool_yes_minor: 5000, parimutuel_pool_no_minor: 5000)

      assert_in_delta 50.0, Parimutuel::ParimutuelPoolService.yes_probability(@market), 0.01
    end

    test 'implied YES probability is 100% when NO pool is zero' do
      @market.update_columns(parimutuel_pool_yes_minor: 1000, parimutuel_pool_no_minor: 0)

      assert_in_delta 100.0, Parimutuel::ParimutuelPoolService.yes_probability(@market), 0.01
    end

    test 'bet rejected if insufficient funds' do
      @player.wallet.update!(available_minor: 0)
      result = Parimutuel::ParimutuelPoolService.add_stake(market: @market, user: @player, side: 'YES', stake_minor: 1)

      assert_not result.success?
    end

    test 'audit event written on stake' do
      assert_difference -> { AuditEvent.where(action: 'parimutuel.stake').count }, 1 do
        Parimutuel::ParimutuelPoolService.add_stake(market: @market, user: @player, side: 'YES', stake_minor: 1000)
      end
    end
  end
end
