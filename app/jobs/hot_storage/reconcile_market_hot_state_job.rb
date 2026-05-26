module HotStorage
  class ReconcileMarketHotStateJob < ApplicationJob
    queue_as :default

    def perform(market_id: nil, market_ids: nil, store: Store.current)
      scope = Market.includes(:market_legs, :bets)

      if market_id.present?
        scope = scope.where(id: market_id)
      elsif market_ids.present?
        scope = scope.where(id: market_ids)
      else
        scope = scope.where(status: [ :open, :settled ])
      end

      scope.find_each do |market|
        reconcile_market!(market: market, store: store)
      end
    end

    private

    def reconcile_market!(market:, store:)
      hot_snapshot = store.read_market_snapshot(market_id: market.id)
      hot_version  = hot_snapshot&.dig("version").to_i
      cold_version = MarketSnapshotProjector.market_version(market)

      return if hot_version == cold_version

      MarketSnapshotProjector.project!(market: market, reason: "reconcile", store: store)
    rescue StandardError => e
      Rails.logger.warn("ReconcileMarketHotStateJob: error on market #{market.id}: #{e.class}: #{e.message}")
    end
  end
end
