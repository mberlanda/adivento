module Backoffice
  class FaucetRequestsController < BaseController
    before_action -> { require_permission!("wallet.faucet.review") }

    def index
      @pending = FaucetRequest.pending
                              .includes(:user)
                              .order(created_at: :asc)
      @processed = FaucetRequest.where.not(status: :pending)
                                .includes(:user, :reviewed_by)
                                .order(updated_at: :desc)
                                .limit(50)
    end

    def approve
      faucet_request = FaucetRequest.find(params[:id])
      unless faucet_request.pending?
        return redirect_to backoffice_faucet_requests_path,
                           alert: "Request has already been processed"
      end
      WalletGrantService.approve!(faucet_request: faucet_request, actor: current_user)
      redirect_to backoffice_faucet_requests_path, notice: "Faucet request approved"
    end

    def reject
      faucet_request = FaucetRequest.find(params[:id])
      unless faucet_request.pending?
        return redirect_to backoffice_faucet_requests_path,
                           alert: "Request has already been processed"
      end
      WalletGrantService.reject!(faucet_request: faucet_request, actor: current_user)
      redirect_to backoffice_faucet_requests_path, notice: "Faucet request rejected"
    end
  end
end
