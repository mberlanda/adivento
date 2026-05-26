class HouseRiskService
  def self.pnl_by_outcome(market, extra_bet_attrs: nil)
    legs = market.market_legs.to_a
    bets = market.bets.open.to_a
    if extra_bet_attrs
      temp_bet = Bet.new(extra_bet_attrs.merge(market: market, status: :open))
      bets << temp_bet
    end

    total_stake = bets.sum(&:net_stake_minor)

    legs.index_with do |leg|
      payout = bets.select { |bet| bet.market_leg_id == leg.id }.sum(&:potential_payout_minor)
      total_stake - payout
    end
  end

  def self.worst_case_liability(market, extra_bet_attrs: nil)
    min_pnl = pnl_by_outcome(market, extra_bet_attrs: extra_bet_attrs).values.min || 0
    [0, -min_pnl].max
  end
end
