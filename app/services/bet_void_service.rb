class BetVoidService
  class InvalidVoid < StandardError; end

  def self.void!(bet:, actor:, reason:)
    raise InvalidVoid, "Reason is required" if reason.to_s.strip.empty?

    ApplicationRecord.transaction do
      locked_bet = Bet.lock.find(bet.id)
      raise InvalidVoid, "Bet is not active" unless locked_bet.open?

      wallet = locked_bet.user.wallet
      wallet.update!(available_minor: wallet.available_minor + locked_bet.stake_minor)

      locked_bet.update!(status: :voided)

      LedgerEntry.create!(
        user: locked_bet.user,
        actor: actor,
        entry_type: "BET_VOID_REFUND",
        amount_minor: locked_bet.stake_minor,
        direction: "credit",
        metadata: { bet_id: locked_bet.id, market_id: locked_bet.market_id, reason: reason }
      )

      AuditEvent.create!(
        actor: actor,
        action: "bet.void",
        target_type: "Bet",
        target_id: locked_bet.id,
        reason: reason,
        metadata: { market_id: locked_bet.market_id }
      )

      market = locked_bet.market
      market.touch
      HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: "bet.void")
      HotStorage::Store.current.append_market_event!(
        market_id: market.id,
        event_name: "market.bet_voided.v1",
        payload: {
          market_id: market.id,
          bet_id: locked_bet.id,
          user_id: locked_bet.user_id,
          reason: reason,
          refunded_minor: locked_bet.stake_minor
        },
        version: (market.updated_at.to_f * 1000).to_i
      )

      locked_bet
    end
  end
end
