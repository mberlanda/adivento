module Web
  class BetslipExecutionsController < BaseController
    def show
      execution = BetslipExecution.where(user_id: current_user.id).find(params[:id])
      render json: {
        execution_id: execution.id,
        quote_id: execution.betslip_quote_id,
        bet_ids: execution.bet_ids,
        status: execution.status
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Execution not found" }, status: :not_found
    end
  end
end
