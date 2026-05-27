module Admin
  class BetsController < BaseController
    before_action -> { require_permission!('bet.void') }

    def void
      bet = Bet.find(params.expect(:id))
      bet = BetVoidService.void!(bet: bet, actor: current_user, reason: params[:reason])

      render json: {
        id: bet.id,
        market_id: bet.market_id,
        status: bet.status,
        reason: params[:reason]
      }
    rescue BetVoidService::InvalidVoid => e
      render json: { error: e.message }, status: :unprocessable_content
    end
  end
end
