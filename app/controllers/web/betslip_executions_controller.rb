module Web
  class BetslipExecutionsController < BaseController
    def show
      @execution = BetslipExecution.where(user_id: current_user.id).find(params.expect(:id))
      @bets = Bet.includes(:market, :market_leg).where(id: @execution.bet_ids, user_id: current_user.id)
      respond_to do |format|
        format.html
        format.json do
          render json: {
            execution_id: @execution.id,
            quote_id: @execution.betslip_quote_id,
            bet_ids: @execution.bet_ids,
            status: @execution.status
          }
        end
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to web_markets_path, alert: 'Execution not found' }
        format.json { render json: { error: 'Execution not found' }, status: :not_found }
      end
    end
  end
end
