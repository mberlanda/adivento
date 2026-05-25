module Web
  class MarketsController < BaseController
    skip_before_action :authenticate_request!, only: [:index, :show]
    before_action :attach_current_user, only: [:index, :show]

    def index
      @markets = if current_user
                   Market.includes(:market_legs).order(created_at: :desc)
                 else
                   Market.includes(:market_legs).where(status: [:open, :settled]).order(created_at: :desc)
                 end
    end

    def show
      @market = Market.includes(:market_legs).find(params[:id])
      return if current_user || @market.open? || @market.settled?

      redirect_to web_markets_path, alert: "This market is not publicly visible yet"
    end

    private

    def attach_current_user
      @current_user = find_authenticated_user
    rescue JWT::DecodeError, JWT::ExpiredSignature
      @current_user = nil
    end
  end
end
