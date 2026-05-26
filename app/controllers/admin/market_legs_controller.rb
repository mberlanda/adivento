module Admin
  class MarketLegsController < BaseController
    before_action -> { require_permission!("market.leg.create") }

    def create
      market = Market.find(params[:market_id])

      if market.market_legs.count >= 2
        return render json: { error: "Market already has 2 legs" }, status: :unprocessable_entity
      end

      leg = market.market_legs.new(leg_params)
      if leg.save
        HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: "market_leg.create")
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
