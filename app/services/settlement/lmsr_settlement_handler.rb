module Settlement
  class LmsrSettlementHandler
    def initialize(market, winning_side, settled_by)
      @market       = market
      @winning_side = winning_side
      @settled_by   = settled_by
    end

    def call
      # v1: settle market status; individual payouts deferred (requires position tracking)
      @market.update!(status: :settled, settled_by: @settled_by, settled_outcome: @winning_side)

      AuditEvent.create!(
        action: 'market.settle',
        actor: @settled_by,
        target_type: 'Market', target_id: @market.id,
        metadata: { mechanism: 'lmsr', winning_side: @winning_side }
      )

      return unless defined?(HotStorage::MarketSnapshotProjector)

      HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: 'market.settle')
    end
  end
end
