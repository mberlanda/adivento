module Settlement
  class ClobSettlementHandler
    def initialize(market, winning_side, settled_by)
      @market = market
      @winning_side = winning_side
      @settled_by   = settled_by
    end

    def call
      # Pass 1: cancel all open/partial orders and release reservations
      @market.orders.where(status: %w[open partial]).find_each do |order|
        released = order.reserved_minor
        order.cancelled_quantity += order.unfilled_quantity
        order.status = :cancelled
        order.save!
        next if released.zero?

        w = order.user.wallet
        w.update!(reserved_minor: w.reserved_minor - released, available_minor: w.available_minor + released)
        AuditEvent.create!(
          action: 'order.settlement_cancel',
          actor: @settled_by,
          target_type: 'Order', target_id: order.id,
          metadata: { released_minor: released }
        )
      end

      # Pass 2: credit winning contracts (100 per filled contract on winning side)
      @market.orders.where(side: @winning_side).where.not(filled_quantity: 0).find_each do |order|
        payout = order.filled_quantity * 100
        next if payout.zero?

        w = order.user.wallet.lock!
        w.update!(available_minor: w.available_minor + payout)
        LedgerEntry.create!(
          user: order.user, actor: @settled_by,
          entry_type: 'SETTLEMENT_WIN', direction: 'credit',
          amount_minor: payout
        )
      end

      @market.update!(status: :settled, settled_by: @settled_by, settled_outcome: @winning_side)

      AuditEvent.create!(
        action: 'market.settle',
        actor: @settled_by,
        target_type: 'Market', target_id: @market.id,
        metadata: { mechanism: 'clob', winning_side: @winning_side }
      )

      return unless defined?(HotStorage::MarketSnapshotProjector)

      HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: 'market.settle')
    end
  end
end
