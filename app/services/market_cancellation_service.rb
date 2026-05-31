class MarketCancellationService
  class InvalidCancellation < StandardError; end

  def self.cancel!(market:, actor:, reason:)
    raise InvalidCancellation, 'Reason is required' if reason.to_s.strip.empty?
    raise InvalidCancellation, 'Market must be open or closed to cancel' unless market.open? || market.closed?

    refunded_minor = 0
    released_minor = 0

    ApplicationRecord.transaction do
      locked_market = Market.lock.find(market.id)
      raise InvalidCancellation, 'Market must be open or closed to cancel' unless locked_market.open? || locked_market.closed?

      locked_market.bets.where(status: :open).includes(user: :wallet).find_each do |bet|
        wallet = bet.user.wallet.lock!
        wallet.update!(available_minor: wallet.available_minor + bet.stake_minor)
        bet.update!(status: :voided)
        refunded_minor += bet.stake_minor

        LedgerEntry.create!(
          user: bet.user,
          actor: actor,
          entry_type: 'MARKET_CANCEL_REFUND',
          amount_minor: bet.stake_minor,
          direction: 'credit',
          metadata: { bet_id: bet.id, market_id: locked_market.id, reason: reason }
        )
      end

      locked_market.orders.where(status: %i[open partial]).includes(user: :wallet).find_each do |order|
        wallet = order.user.wallet.lock!
        release = [order.reserved_minor, wallet.reserved_minor].min
        order.cancelled_quantity += order.unfilled_quantity
        order.status = :cancelled
        order.save!

        wallet.update!(
          reserved_minor: wallet.reserved_minor - release,
          available_minor: wallet.available_minor + release
        )
        released_minor += release

        if release.positive?
          LedgerEntry.create!(
            user: order.user,
            actor: actor,
            entry_type: 'MARKET_CANCEL_ORDER_RELEASE',
            amount_minor: release,
            direction: 'credit',
            metadata: { order_id: order.id, market_id: locked_market.id, reason: reason }
          )
        end
      end

      locked_market.update!(status: :cancelled)

      AuditEvent.create!(
        actor: actor,
        action: 'market.cancel',
        target_type: 'Market',
        target_id: locked_market.id,
        reason: reason,
        metadata: { refunded_minor: refunded_minor, released_minor: released_minor }
      )

      HotStorage::MarketSnapshotProjector.project!(market: locked_market.reload, reason: 'market.cancel')
      HotStorage::Store.current.append_market_event!(
        market_id: locked_market.id,
        event_name: 'market.cancelled.v1',
        payload: {
          market_id: locked_market.id,
          reason: reason,
          refunded_minor: refunded_minor,
          released_minor: released_minor
        },
        version: (locked_market.updated_at.to_f * 1000).to_i
      )

      locked_market
    end
  end
end
