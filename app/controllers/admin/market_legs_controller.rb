module Admin
  class MarketLegsController < BaseController
    before_action -> { require_any_role!(:admin, :moderator) }

    def create
      market = Market.find(params[:market_id])
      leg = market.market_legs.new(leg_params)
      if leg.save
        AuditEvent.create!(
          actor: current_user,
          action: "market_leg.create",
          target_type: "Market",
          target_id: market.id,
          reason: params[:reason],
          metadata: { leg_label: leg.label }
        )
        render json: { id: leg.id, label: leg.label, odds_minor: leg.odds_minor }, status: :created
      else
        render json: { errors: leg.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def leg_params
      params.permit(:label, :odds_minor, :active)
    end
  end
end
