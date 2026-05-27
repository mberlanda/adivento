module Web
  class ParimutuelBetsController < ApplicationController
    before_action :authenticate_user!

    def create
      market = Market.find(params[:market_id])
      return render json: { error: "Not a parimutuel market" }, status: :unprocessable_entity unless market.parimutuel?

      result = Parimutuel::ParimutuelPoolService.add_stake(
        market: market,
        user: current_user,
        side: params[:side],
        stake_minor: params[:stake_minor].to_i
      )

      if result.success?
        render json: { success: true }, status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_entity
      end
    end
  end
end
