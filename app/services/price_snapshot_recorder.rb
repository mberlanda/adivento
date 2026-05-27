class PriceSnapshotRecorder
  def self.record(market)
    data = case market.mechanism_type
           when 'fixed_odds'
             { legs: market.market_legs.map { |l| { label: l.label, odds_minor: l.odds_minor } } }
           when 'clob'
             book = market.pricing_engine.order_book_summary
             { bid: book[:bid], ask: book[:ask] }
           when 'lmsr'
             svc = Lmsr::LmsrPricingService.new(
               lmsr_b: market.lmsr_b_parameter, q_yes: market.lmsr_q_yes, q_no: market.lmsr_q_no
             )
             { yes_probability: svc.yes_probability, no_probability: svc.no_probability }
           when 'parimutuel'
             { yes_probability: Parimutuel::ParimutuelPoolService.yes_probability(market),
               pool_yes_minor: market.parimutuel_pool_yes_minor,
               pool_no_minor: market.parimutuel_pool_no_minor }
           end

    PriceSnapshot.create!(
      market: market,
      mechanism_type: market.mechanism_type,
      snapshot_data: data,
      recorded_at: Time.current
    )
  end
end
