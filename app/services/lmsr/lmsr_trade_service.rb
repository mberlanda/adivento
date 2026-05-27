module Lmsr
  class LmsrTradeService
    Result = Struct.new(:success?, :cost_minor, :fee_minor, :errors, keyword_init: true)

    def self.call(**) = new(**).call

    def initialize(market:, user:, side:, quantity:)
      @market   = market
      @user     = user
      @side     = side
      @quantity = quantity.to_i
    end

    def call
      ApplicationRecord.transaction do
        raise 'Market is not open' unless @market.open?

        pricing = LmsrPricingService.new(
          lmsr_b: @market.lmsr_b_parameter,
          q_yes: @market.lmsr_q_yes,
          q_no: @market.lmsr_q_no
        )

        delta_yes = @side == 'YES' ? @quantity : 0
        delta_no  = @side == 'NO'  ? @quantity : 0
        raw_cost  = pricing.trade_cost(delta_yes: delta_yes, delta_no: delta_no)
        raw_cost_minor = (raw_cost * 100).round

        fee_minor  = (@market.spread_fee_bps.to_i * raw_cost_minor.abs / 10_000.0).ceil
        total_cost = raw_cost_minor + fee_minor

        wallet = @user.wallet.lock!
        raise 'Insufficient funds' if total_cost.positive? && wallet.available_minor < total_cost

        wallet.update!(available_minor: wallet.available_minor - total_cost)

        direction = raw_cost_minor >= 0 ? 'debit' : 'credit'
        LedgerEntry.create!(
          user: @user, actor: @user,
          entry_type: 'LMSR_TRADE_STAKE', direction: direction,
          amount_minor: raw_cost_minor.abs
        )

        if fee_minor.positive?
          LedgerEntry.create!(
            user: @user, actor: @user,
            entry_type: 'LMSR_FEE', direction: 'debit',
            amount_minor: fee_minor
          )
        end

        @market.lock!
        @market.update_columns(
          lmsr_q_yes: @market.lmsr_q_yes + delta_yes,
          lmsr_q_no: @market.lmsr_q_no + delta_no
        )

        AuditEvent.create!(
          action: 'lmsr_trade.place',
          actor: @user,
          target_type: 'Market', target_id: @market.id,
          metadata: { side: @side, quantity: @quantity, cost_minor: raw_cost_minor, fee_minor: fee_minor }
        )

        if defined?(HotStorage::MarketSnapshotProjector)
          HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: 'lmsr_trade.place')
        end

        Result.new(success?: true, cost_minor: raw_cost_minor, fee_minor: fee_minor, errors: [])
      end
    rescue StandardError => e
      Result.new(success?: false, cost_minor: 0, fee_minor: 0, errors: [e.message])
    end
  end
end
