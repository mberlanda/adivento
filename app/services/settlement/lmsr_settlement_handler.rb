module Settlement
  class LmsrSettlementHandler
    def initialize(market, winning_side, settled_by)
      @market       = market
      @winning_side = winning_side
      @settled_by   = settled_by
    end

    def call
      @market.update!(status: :settled, settled_by: @settled_by, settled_outcome: @winning_side)

      pay_out_positions

      AuditEvent.create!(
        action: 'market.settle',
        actor: @settled_by,
        target_type: 'Market', target_id: @market.id,
        metadata: { mechanism: 'lmsr', winning_side: @winning_side }
      )

      return unless defined?(HotStorage::MarketSnapshotProjector)

      HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: 'market.settle')
    end

    # Option B: derive positions from audit events (reconciliation path).
    # Returns { user_id => { 'YES' => n, 'NO' => n } } without hitting lmsr_positions.
    def self.positions_from_ledger(market)
      AuditEvent
        .where(action: 'lmsr_trade.place', target_type: 'Market', target_id: market.id)
        .each_with_object(Hash.new { |h, k| h[k] = { 'YES' => 0, 'NO' => 0 } }) do |ev, acc|
          acc[ev.actor_id][ev.metadata['side']] += ev.metadata['quantity'].to_i
        end
    end

    private

    def pay_out_positions
      winning_positions = LmsrPosition.for_market(@market)
                                      .where(side: @winning_side)
                                      .holding

      winning_positions.find_each do |position|
        payout = payout_minor(position.contracts)
        next unless payout.positive?

        wallet = position.user.wallet.lock!
        wallet.update!(available_minor: wallet.available_minor + payout)

        LedgerEntry.create!(
          user: position.user, actor: @settled_by,
          entry_type: 'SETTLEMENT_WIN', direction: 'credit',
          amount_minor: payout
        )
      end
    end

    # Each winning contract pays out 1.00 ADIV (100 minor units).
    # LMSR guarantees total payout ≤ subsidy; the 100-per-contract rate
    # is the standard binary prediction market settlement value.
    def payout_minor(contracts)
      contracts * 100
    end
  end
end
