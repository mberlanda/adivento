module Web
  class LmsrTradesController < BaseController
    def create
      market = Market.find(params.expect(:market_id))

      unless market.lmsr?
        return respond_to do |format|
          format.html { redirect_to web_market_path(market), alert: 'Not an LMSR market' }
          format.json { render json: { error: 'Not an LMSR market' }, status: :unprocessable_content }
        end
      end

      side = params[:side]&.upcase
      result = Lmsr::LmsrTradeService.call(
        market: market,
        user: current_user,
        side: side,
        quantity: params[:quantity].to_i
      )

      respond_to do |format|
        if result.success?
          format.html do
            redirect_to web_market_path(market),
                        notice: "Trade placed on #{side} for #{params[:quantity].to_i} shares. " \
                                "Cost: #{result.cost_minor} ADIV"
          end
          format.json { render json: { cost_minor: result.cost_minor, fee_minor: result.fee_minor }, status: :created }
        else
          format.html { redirect_to web_market_path(market), alert: result.errors.join(', ') }
          format.json { render json: { errors: result.errors }, status: :unprocessable_content }
        end
      end
    end
  end
end
