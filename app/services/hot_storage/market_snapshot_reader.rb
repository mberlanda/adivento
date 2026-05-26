module HotStorage
  class MarketSnapshotReader
    def self.call(market_id:, store: Store.current)
      hot_snapshot = store.read_market_snapshot(market_id: market_id)
      return hot_snapshot.deep_symbolize_keys if hot_snapshot.present?

      market = Market.includes(:market_legs, :bets).find(market_id)
      MarketSnapshotProjector.project!(market: market, reason: "cache_miss", store: store)
    end
  end
end
