module Web
  class BetsController < BaseController
    before_action :set_market

    def create
      market_leg = @market.market_legs.find(params.expect(:market_leg_id))
      bet = BetPlacementService.place!(
        user: current_user,
        market: @market,
        market_leg: market_leg,
        stake_minor: params[:stake_minor].to_i
      )
      HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: 'bet.place')
      redirect_to web_market_path(@market),
                  notice: "Bet placed on #{market_leg.label} for #{bet.net_stake_minor} ADIV. " \
                          "Potential payout: #{bet.potential_payout_minor} ADIV"
    rescue BetPlacementService::InvalidBet, BetPlacementService::RiskLimitExceeded => e
      redirect_to web_market_path(@market), alert: e.message
    end

    private

    def set_market
      @market = Market.includes(:market_legs).find(params.expect(:market_id))
    end
  end
end
