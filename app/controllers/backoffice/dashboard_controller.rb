module Backoffice
  class DashboardController < BaseController
    def index
      @pending_faucet_requests = FaucetRequest.pending.count
      @active_templates = MarketTemplate.where(active: true).count
      @open_markets = Market.open.count
    end
  end
end
