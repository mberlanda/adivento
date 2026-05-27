module Web
  class LmsrTradesController < BaseController
    def create
      market = Market.find(params.expect(:market_id))
      return render json: { error: 'Not an LMSR market' }, status: :unprocessable_content unless market.lmsr?

      result = Lmsr::LmsrTradeService.call(
        market: market,
        user: current_user,
        side: params[:side],
        quantity: params[:quantity].to_i
      )

      if result.success?
        render json: { cost_minor: result.cost_minor, fee_minor: result.fee_minor }, status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end
  end
end
