require 'test_helper'

module Lmsr
  class LmsrTradeServiceTest < ActiveSupport::TestCase
    setup do
      @market = markets(:lmsr_market)
      @market.update_columns(lmsr_b_parameter: Lmsr::LmsrPricingService.b_from_subsidy(100_000), lmsr_q_yes: 0, lmsr_q_no: 0)
      @player = users(:player)
      @player.wallet.update!(available_minor: 100_000, reserved_minor: 0)
      LmsrPosition.where(user: @player, market: @market).delete_all
    end

    test 'buying YES contracts debits wallet and increments lmsr_q_yes' do
      result = Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 10)

      assert_predicate result, :success?
      @market.reload

      assert_equal 10, @market.lmsr_q_yes
      assert_operator @player.wallet.reload.available_minor, :<, 100_000
    end

    test 'LMSR_TRADE_STAKE ledger entry written on buy' do
      assert_difference -> { LedgerEntry.where(entry_type: 'LMSR_TRADE_STAKE').count }, 1 do
        Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 10)
      end
    end

    test 'LMSR_FEE ledger entry written when spread_fee_bps > 0' do
      assert_difference -> { LedgerEntry.where(entry_type: 'LMSR_FEE').count }, 1 do
        Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 10)
      end
    end

    test 'trade rejected if insufficient wallet funds' do
      @player.wallet.update!(available_minor: 1)
      result = Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 1000)

      assert_not result.success?
    end

    test 'audit event written on trade' do
      assert_difference -> { AuditEvent.where(action: 'lmsr_trade.place').count }, 1 do
        Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 10)
      end
    end

    test 'position upserted after trade' do
      Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 10)

      pos = LmsrPosition.find_by(user: @player, market: @market, side: 'YES')

      assert_not_nil pos
      assert_equal 10, pos.contracts
    end

    test 'position accumulates across multiple trades' do
      Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 5)
      Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 3)

      assert_equal 8, LmsrPosition.find_by(user: @player, market: @market, side: 'YES').contracts
    end

    test 'lmsr_realized_loss_minor does not change on a standard buy trade' do
      # LMSR is buy-only: trade_cost is always >= 0, so outflow never occurs during trading.
      # The guard is in place for forward-compatibility if sell trades are ever added.
      initial_loss = @market.lmsr_realized_loss_minor
      Lmsr::LmsrTradeService.call(market: @market, user: @player, side: 'YES', quantity: 10)

      assert_equal initial_loss, @market.reload.lmsr_realized_loss_minor
    end
  end
end
