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

      # Pass 2: credit each holder for their NET long position on the winning side
      # (filled buys - filled sells). Paying raw filled orders would double-pay
      # contracts that were sold before settlement (TD-018).
      user_ids = @market.orders.where(side: @winning_side).where.not(filled_quantity: 0).distinct.pluck(:user_id)
      User.where(id: user_ids).find_each do |user|
        net = Clob::NetPositionService.call(user: user, market: @market, side: @winning_side)
        next unless net.positive?

        payout = net * 100
        w = user.wallet.lock!
        w.update!(available_minor: w.available_minor + payout)
        LedgerEntry.create!(
          user: user, actor: @settled_by,
          entry_type: 'SETTLEMENT_WIN', direction: 'credit',
          amount_minor: payout, metadata: { market_id: @market.id }
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
