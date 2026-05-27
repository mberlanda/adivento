class BetPlacementService
  class RiskLimitExceeded < StandardError; end
  class InvalidBet < StandardError; end

  def self.place!(user:, market:, market_leg:, stake_minor:)
    raise InvalidBet, 'Market is not open' unless market.open?
    raise InvalidBet, 'Leg does not belong to market' unless market_leg.market_id == market.id
    raise InvalidBet, 'Leg is inactive' unless market_leg.active?
    raise InvalidBet, 'Stake must be positive' unless stake_minor.to_i.positive?

    fee_minor = (stake_minor.to_i * market.fee_bps) / 10_000
    net_stake_minor = stake_minor.to_i - fee_minor
    raise InvalidBet, 'Stake too small after fee' unless net_stake_minor.positive?

    potential_payout_minor = (stake_minor.to_i * market_leg.odds_minor) / 10_000

    wallet = user.wallet
    raise InvalidBet, 'Insufficient wallet balance' if wallet.available_minor < stake_minor.to_i

    simulated = {
      market_leg_id: market_leg.id,
      net_stake_minor: net_stake_minor,
      potential_payout_minor: potential_payout_minor
    }
    post_trade_liability = HouseRiskService.worst_case_liability(market, extra_bet_attrs: simulated)
    raise RiskLimitExceeded, 'Liability cap exceeded' if post_trade_liability > market.liability_cap_minor

    ApplicationRecord.transaction do
      wallet.update!(available_minor: wallet.available_minor - stake_minor.to_i)

      bet = Bet.create!(
        user: user,
        market: market,
        market_leg: market_leg,
        stake_minor: stake_minor,
        fee_minor: fee_minor,
        net_stake_minor: net_stake_minor,
        odds_minor: market_leg.odds_minor,
        potential_payout_minor: potential_payout_minor,
        status: :open
      )

      LedgerEntry.create!(
        user: user,
        actor: user,
        entry_type: 'BET_STAKE',
        amount_minor: stake_minor,
        direction: 'debit',
        metadata: { bet_id: bet.id, market_id: market.id, fee_minor: fee_minor }
      )

      AuditEvent.create!(
        actor: user,
        action: 'bet.place',
        target_type: 'Bet',
        target_id: bet.id,
        metadata: { market_id: market.id, market_leg_id: market_leg.id, stake_minor: stake_minor }
      )

      bet
    end
  end
end
