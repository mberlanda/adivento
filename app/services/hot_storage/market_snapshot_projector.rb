module HotStorage
  class MarketSnapshotProjector
    def self.project!(market:, reason:, store: Store.current)
      snapshot = build_snapshot(market)
      version = market_version(market)

      begin
        store.write_market_snapshot!(market_id: market.id, snapshot: snapshot, version: version)
        store.append_market_event!(
          market_id: market.id,
          event_name: 'market.snapshot.v1',
          payload: snapshot.merge(reason: reason),
          version: version
        )
      rescue StandardError => e
        Rails.logger.warn("HotStorage::MarketSnapshotProjector: Redis error for market #{market.id}: #{e.class}: #{e.message}")
      end

      snapshot.merge(version: version)
    end

    def self.build_snapshot(market)
      {
        market_id: market.id,
        status: market.status,
        settled_outcome: market.settled_outcome,
        total_open_interest_minor: market.bets.where(status: :open).sum(:net_stake_minor),
        updated_at: market.updated_at&.iso8601,
        legs: market.market_legs.order(:id).map do |leg|
          {
            id: leg.id,
            label: leg.label,
            odds_minor: leg.odds_minor,
            active: leg.active
          }
        end
      }
    end

    def self.market_version(market)
      (market.updated_at.to_f * 1000).to_i
    end
  end
end
