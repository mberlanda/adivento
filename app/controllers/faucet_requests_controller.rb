class FaucetRequestsController < ApplicationController
  include Authentication

  def create
    faucet_request = current_user.faucet_requests.create(faucet_request_params)
    if faucet_request.persisted?
      render json: { id: faucet_request.id, status: faucet_request.status, amount_minor: faucet_request.amount_minor }, status: :created
    else
      render json: { errors: faucet_request.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def faucet_request_params
    params.permit(:amount_minor)
  end
end
