module Parimutuel
  class ParimutuelSettlementService
    Result = Struct.new(:success?, :refunded?, :takeout_minor, :payout_per_stake_ratio, :errors, keyword_init: true)

    def self.call(**) = new(**).call

    def initialize(market:, winning_side:, settled_by:)
      @market       = market
      @winning_side = winning_side
      @settled_by   = settled_by
    end

    def call
      ApplicationRecord.transaction do
        total_pool   = @market.parimutuel_pool_yes_minor + @market.parimutuel_pool_no_minor
        winning_pool = @winning_side == 'YES' ? @market.parimutuel_pool_yes_minor : @market.parimutuel_pool_no_minor

        if winning_pool.zero?
          refund_all!(total_pool)
          @market.lock!
          @market.update!(status: :settled, settled_by: @settled_by)
          return Result.new(success?: true, refunded?: true, takeout_minor: 0, payout_per_stake_ratio: 0, errors: [])
        end

        takeout_minor = (total_pool * @market.takeout_bps / 10_000.0).ceil
        after_takeout = total_pool - takeout_minor
        payout_ratio  = after_takeout.to_f / winning_pool

        # Pay each winning staker pro-rata from PARIMUTUEL_STAKE ledger entries
        LedgerEntry.where(entry_type: 'PARIMUTUEL_STAKE')
                   .where("metadata->>'market_id' = ?", @market.id.to_s)
                   .where("metadata->>'side' = ?", @winning_side)
                   .find_each do |entry|
                     payout = (entry.amount_minor * payout_ratio).floor
                     next if payout.zero?

                     w = entry.user.wallet
                     w.update!(available_minor: w.available_minor + payout)
                     LedgerEntry.create!(
                       user: entry.user, actor: @settled_by,
                       entry_type: 'SETTLEMENT_WIN', direction: 'credit',
                       amount_minor: payout
                     )
                   end

        AuditEvent.create!(
          action: 'parimutuel.takeout',
          actor: @settled_by,
          target_type: 'Market', target_id: @market.id,
          metadata: { takeout_minor: takeout_minor, total_pool: total_pool, takeout_bps: @market.takeout_bps }
        )

        @market.lock!
        @market.update!(status: :settled, settled_by: @settled_by)

        Result.new(
          success?: true,
          refunded?: false,
          takeout_minor: takeout_minor,
          payout_per_stake_ratio: payout_ratio,
          errors: []
        )
      end
    rescue StandardError => e
      Result.new(success?: false, refunded?: false, takeout_minor: 0, payout_per_stake_ratio: 0, errors: [e.message])
    end

    private

    def refund_all!(total_pool)
      LedgerEntry.where(entry_type: 'PARIMUTUEL_STAKE')
                 .where("metadata->>'market_id' = ?", @market.id.to_s)
                 .find_each do |entry|
                   w = entry.user.wallet
                   w.update!(available_minor: w.available_minor + entry.amount_minor)
                   LedgerEntry.create!(
                     user: entry.user, actor: @settled_by,
                     entry_type: 'PARIMUTUEL_REFUND', direction: 'credit',
                     amount_minor: entry.amount_minor
                   )
                 end

      AuditEvent.create!(
        action: 'parimutuel.refund_all',
        actor: @settled_by,
        target_type: 'Market', target_id: @market.id,
        metadata: { refunded_pool: total_pool, reason: 'winning_pool_was_zero' }
      )
    end
  end
end
