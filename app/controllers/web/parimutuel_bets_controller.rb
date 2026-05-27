module Web
  class ParimutuelBetsController < BaseController
    def create
      market = Market.find(params.expect(:market_id))

      unless market.parimutuel?
        return respond_to do |format|
          format.html { redirect_to web_market_path(market), alert: 'Not a parimutuel market' }
          format.json { render json: { error: 'Not a parimutuel market' }, status: :unprocessable_content }
        end
      end

      side = params[:side]&.upcase
      result = Parimutuel::ParimutuelPoolService.add_stake(
        market: market,
        user: current_user,
        side: side,
        stake_minor: params[:stake_minor].to_i
      )

      respond_to do |format|
        if result.success?
          format.html do
            redirect_to web_market_path(market),
                        notice: "Stake placed on #{side} pool for #{params[:stake_minor].to_i} ADIV"
          end
          format.json { render json: { success: true }, status: :created }
        else
          format.html { redirect_to web_market_path(market), alert: result.errors.join(', ') }
          format.json { render json: { errors: result.errors }, status: :unprocessable_content }
        end
      end
    end
  end
end
