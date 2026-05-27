class BetsController < ApplicationController
  include Authentication
  include RoleAuthorization

  before_action :authenticate_request!
  before_action -> { require_permission!('bet.place') }

  def create
    market = Market.find(params.expect(:market_id))
    market_leg = market.market_legs.find(params.expect(:market_leg_id))

    bet = BetPlacementService.place!(
      user: current_user,
      market: market,
      market_leg: market_leg,
      stake_minor: params[:stake_minor]
    )
    HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: 'bet.place')

    render json: {
      id: bet.id,
      market_id: bet.market_id,
      market_leg_id: bet.market_leg_id,
      stake_minor: bet.stake_minor,
      fee_minor: bet.fee_minor,
      net_stake_minor: bet.net_stake_minor,
      potential_payout_minor: bet.potential_payout_minor,
      status: bet.status
    }, status: :created
  rescue BetPlacementService::InvalidBet, BetPlacementService::RiskLimitExceeded => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
