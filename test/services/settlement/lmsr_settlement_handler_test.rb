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

    test 'positions_from_ledger aggregates YES and NO quantities from audit events' do
      moderator = users(:moderator)
      AuditEvent.create!(action: 'lmsr_trade.place', actor: @player, target_type: 'Market', target_id: @market.id,
                         metadata: { 'side' => 'YES', 'quantity' => 5 })
      AuditEvent.create!(action: 'lmsr_trade.place', actor: @player, target_type: 'Market', target_id: @market.id,
                         metadata: { 'side' => 'YES', 'quantity' => 3 })
      AuditEvent.create!(action: 'lmsr_trade.place', actor: moderator, target_type: 'Market', target_id: @market.id,
                         metadata: { 'side' => 'NO', 'quantity' => 7 })

      result = LmsrSettlementHandler.positions_from_ledger(@market)

      assert_equal 8,  result[@player.id]['YES']
      assert_equal 0,  result[@player.id]['NO']
      assert_equal 7,  result[moderator.id]['NO']
      assert_equal 0,  result[moderator.id]['YES']
    end
  end
end
