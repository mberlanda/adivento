module Admin
  class FaucetRequestsController < BaseController
    before_action -> { require_any_role!(:admin, :moderator) }

    def index
      render json: FaucetRequest.order(created_at: :desc).map { |request| serialize_request(request) }
    end

    def approve
      faucet_request = FaucetRequest.pending.find(params[:id])
      WalletGrantService.approve!(faucet_request: faucet_request, actor: current_user, note: params[:note])
      render json: serialize_request(faucet_request.reload)
    end

    def reject
      faucet_request = FaucetRequest.pending.find(params[:id])
      WalletGrantService.reject!(faucet_request: faucet_request, actor: current_user, note: params[:note])
      render json: serialize_request(faucet_request.reload)
    end

    private

    def serialize_request(request)
      {
        id: request.id,
        user_id: request.user_id,
        amount_minor: request.amount_minor,
        status: request.status,
        reviewed_by: request.reviewed_by_id,
        note: request.note
      }
    end
  end
end
