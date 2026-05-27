module Web
  class ParimutuelBetsController < BaseController
    def create
      market = Market.find(params.expect(:market_id))
      return render json: { error: 'Not a parimutuel market' }, status: :unprocessable_content unless market.parimutuel?

      result = Parimutuel::ParimutuelPoolService.add_stake(
        market: market,
        user: current_user,
        side: params[:side],
        stake_minor: params[:stake_minor].to_i
      )

      if result.success?
        render json: { success: true }, status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end
  end
end
