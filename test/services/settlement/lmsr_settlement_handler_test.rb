require 'test_helper'

module Settlement
  class LmsrSettlementHandlerTest < ActiveSupport::TestCase
    setup do
      @market = markets(:lmsr_market)
      @market.update_columns(status: Market.statuses[:open])
      @player = users(:player)
      @admin  = users(:admin)
      @player.wallet.update!(available_minor: 100_000)
      LmsrPosition.where(market: @market).delete_all
    end

    test 'settles market status to settled' do
      LmsrSettlementHandler.new(@market, 'YES', @admin).call

      assert_predicate @market.reload, :settled?
      assert_equal 'YES', @market.settled_outcome
    end

    test 'credits winning position holders on YES settlement' do
      LmsrPosition.create!(user: @player, market: @market, side: 'YES', contracts: 10)
      initial = @player.wallet.reload.available_minor

      LmsrSettlementHandler.new(@market, 'YES', @admin).call

      assert_equal initial + 1000, @player.wallet.reload.available_minor
    end

    test 'does not credit NO holders when YES wins' do
      LmsrPosition.create!(user: @player, market: @market, side: 'NO', contracts: 10)
      initial = @player.wallet.reload.available_minor

      LmsrSettlementHandler.new(@market, 'YES', @admin).call

      assert_equal initial, @player.wallet.reload.available_minor
    end

    test 'writes SETTLEMENT_WIN ledger entry for each winner' do
      LmsrPosition.create!(user: @player, market: @market, side: 'YES', contracts: 5)

      assert_difference -> { LedgerEntry.where(entry_type: 'SETTLEMENT_WIN').count }, 1 do
        LmsrSettlementHandler.new(@market, 'YES', @admin).call
      end
    end

    test 'skips positions with zero contracts' do
      LmsrPosition.create!(user: @player, market: @market, side: 'YES', contracts: 0)
      initial = @player.wallet.reload.available_minor

      LmsrSettlementHandler.new(@market, 'YES', @admin).call

      assert_equal initial, @player.wallet.reload.available_minor
    end

    test 'audit event written on settlement' do
      assert_difference -> { AuditEvent.where(action: 'market.settle').count }, 1 do
        LmsrSettlementHandler.new(@market, 'YES', @admin).call
      end
    end
  end
end
