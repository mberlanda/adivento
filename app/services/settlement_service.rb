class SettlementService
  class InvalidSettlement < StandardError; end

  def self.settle!(market:, outcome:, actor:)
    raise InvalidSettlement, 'Market must be open to settle' unless market.open?

    valid_labels = market.market_legs.pluck(:label)
    unless valid_labels.include?(outcome)
      raise InvalidSettlement,
            "Invalid outcome: #{outcome}. Valid: #{valid_labels.join(', ')}"
    end

    ApplicationRecord.transaction do
      market.update!(status: :settled, settled_outcome: outcome, settled_by: actor)

      open_bets = market.bets.where(status: :open).includes(user: :wallet, market_leg: [])

      open_bets.each do |bet|
        if bet.market_leg.label == outcome
          bet.update!(status: :settled_win)

          wallet = bet.user.wallet
          wallet.update!(available_minor: wallet.available_minor + bet.potential_payout_minor)

          LedgerEntry.create!(
            user: bet.user,
            actor: actor,
            entry_type: 'BET_WIN_PAYOUT',
            amount_minor: bet.potential_payout_minor,
            direction: 'credit',
            metadata: { bet_id: bet.id, market_id: market.id, outcome: outcome }
          )

          AuditEvent.create!(
            actor: actor,
            action: 'bet.settle_win',
            target_type: 'Bet',
            target_id: bet.id,
            metadata: { market_id: market.id, outcome: outcome, payout_minor: bet.potential_payout_minor }
          )
        else
          bet.update!(status: :settled_loss)

          AuditEvent.create!(
            actor: actor,
            action: 'bet.settle_loss',
            target_type: 'Bet',
            target_id: bet.id,
            metadata: { market_id: market.id, outcome: outcome }
          )
        end
      end

      AuditEvent.create!(
        actor: actor,
        action: 'market.settle',
        target_type: 'Market',
        target_id: market.id,
        metadata: { outcome: outcome, bets_settled: open_bets.size }
      )

      HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: 'market.settle')
      HotStorage::Store.current.append_market_event!(
        market_id: market.id,
        event_name: 'market.settled.v1',
        payload: { market_id: market.id, outcome: outcome, actor_id: actor.id },
        version: (market.updated_at.to_f * 1000).to_i
      )
    end

    market
  end
end
