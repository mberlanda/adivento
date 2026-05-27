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
      base = {
        market_id: market.id,
        status: market.status,
        mechanism_type: market.mechanism_type,
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
      base.merge(mechanism_snapshot(market))
    end

    def self.mechanism_snapshot(market)
      case market.mechanism_type
      when 'clob'
        book = market.pricing_engine.order_book_summary
        bids = market.orders.where(side: 'YES', status: %w[open partial])
                     .group(:price_cents).sum('quantity - filled_quantity - cancelled_quantity')
                     .sort.reverse.first(5)
                     .map { |price, qty| { price_cents: price, quantity: qty } }
        asks = market.orders.where(side: 'NO', status: %w[open partial])
                     .group(:price_cents).sum('quantity - filled_quantity - cancelled_quantity')
                     .sort.first(5)
                     .map { |price, qty| { price_cents: price, quantity: qty } }
        { clob: { bids: bids, asks: asks, best_bid: book[:bid], best_ask: book[:ask] } }
      when 'lmsr'
        svc = Lmsr::LmsrPricingService.new(
          lmsr_b: market.lmsr_b_parameter, q_yes: market.lmsr_q_yes, q_no: market.lmsr_q_no
        )
        { lmsr: { yes_probability: svc.yes_probability, no_probability: svc.no_probability } }
      when 'parimutuel'
        { parimutuel: {
          pool_yes_minor: market.parimutuel_pool_yes_minor,
          pool_no_minor: market.parimutuel_pool_no_minor,
          yes_probability: Parimutuel::ParimutuelPoolService.yes_probability(market),
          takeout_bps: market.takeout_bps
        } }
      else
        {}
      end
    end

    def self.market_version(market)
      (market.updated_at.to_f * 1000).to_i
    end
  end
end
