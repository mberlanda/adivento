module Web
  class FaucetRequestsController < BaseController
    def create
      amount = params[:amount_minor].to_i
      amount = 10_000 unless amount.positive?
      faucet_request = current_user.faucet_requests.create(amount_minor: amount)
      if faucet_request.persisted?
        redirect_to web_profile_path, notice: 'Token request submitted — an admin will review it shortly.'
      else
        redirect_to web_profile_path, alert: faucet_request.errors.full_messages.join(', ')
      end
    end
  end
end
