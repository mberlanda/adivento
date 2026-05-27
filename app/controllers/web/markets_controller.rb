module Web
  class MarketsController < BaseController
    skip_before_action :authenticate_request!, only: %i[index show]
    before_action :attach_current_user, only: %i[index show]

    def index
      raw_cat = params[:category].presence
      @selected_category = Market::CATEGORIES.include?(raw_cat) ? raw_cat : nil
      @search_query      = params[:q].presence
      @markets = if current_user
                   Market.includes(:market_legs)
                 else
                   Market.includes(:market_legs).where(status: %i[open settled])
                 end
      @markets = @markets.where(category: @selected_category) if @selected_category
      if @search_query
        term = "%#{@search_query}%"
        @markets = @markets.where(
          'question ILIKE :t OR description ILIKE :t OR category ILIKE :t', t: term
        )
      end
      @markets = @markets.order(created_at: :desc)
    end

    def show
      @market = Market.includes(:market_legs).find(params.expect(:id))
      return if current_user || @market.open? || @market.settled?

      redirect_to web_markets_path, alert: 'This market is not publicly visible yet'
    end

    private

    def attach_current_user
      @current_user = find_authenticated_user
    rescue JWT::DecodeError, JWT::ExpiredSignature
      @current_user = nil
    end
  end
end
