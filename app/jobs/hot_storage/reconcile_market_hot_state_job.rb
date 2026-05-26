module HotStorage
  class ReconcileMarketHotStateJob < ApplicationJob
    queue_as :default

    def perform(market_ids: nil, store: Store.current)
      scope = Market.includes(:market_legs, :bets)
      scope = scope.where(id: market_ids) if market_ids.present?

      scope.find_each do |market|
        reconcile_market!(market: market, store: store)
      end
    end

    private

    def reconcile_market!(market:, store:)
      hot_snapshot = store.read_market_snapshot(market_id: market.id)
      hot_version = hot_snapshot&.dig("version").to_i
      cold_version = MarketSnapshotProjector.market_version(market)

      return if hot_version == cold_version

      MarketSnapshotProjector.project!(market: market, reason: "reconcile", store: store)
    end
  end
end
