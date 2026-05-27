class MarketsController < ApplicationController
  include Authentication

  skip_before_action :authenticate_request!, only: %i[index show]
  before_action :attach_current_user, only: %i[index show]

  def index
    markets = if current_user
                Market.includes(:market_legs).order(created_at: :desc)
              else
                Market.includes(:market_legs).where(status: %i[open settled]).order(created_at: :desc)
              end

    render json: markets.map { |market| serialize_market(market) }
  end

  def show
    market = Market.includes(:market_legs).find(params.expect(:id))

    return render json: { error: 'Not found' }, status: :not_found if current_user.nil? && !market.open? && !market.settled?

    render json: serialize_market(market)
  end

  private

  def attach_current_user
    token = request.headers['Authorization'].to_s.split.last
    return if token.blank?

    payload = JsonWebToken.decode(token)
    @current_user = User.find_by(id: payload['user_id'])
  rescue JWT::DecodeError, JWT::ExpiredSignature
    @current_user = nil
  end

  def serialize_market(market)
    {
      id: market.id,
      question: market.question,
      description: market.description,
      status: market.status,
      settled_outcome: market.settled_outcome,
      legs: market.market_legs.map do |leg|
        { id: leg.id, label: leg.label, odds_minor: leg.odds_minor, active: leg.active }
      end
    }
  end
end
