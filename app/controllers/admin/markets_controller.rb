module Admin
  class MarketsController < BaseController
    before_action -> { require_any_role!(:admin, :moderator) }

    def create
      require_any_role!(:admin)
      return if performed?

      market = Market.new(market_params.merge(created_by: current_user))
      if market.save
        seed_default_legs(market)
        render json: { id: market.id, status: market.status }, status: :created
      else
        render json: { errors: market.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      require_any_role!(:admin)
      return if performed?

      market = Market.find(params[:id])
      if market.update(market_params)
        AuditEvent.create!(
          actor: current_user,
          action: "market.update",
          target_type: "Market",
          target_id: market.id,
          metadata: {}
        )
        render json: { id: market.id, status: market.status }
      else
        render json: { errors: market.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def settle
      market = Market.find(params[:id])
      outcome = params[:outcome].to_s.upcase
      unless market.market_legs.where(label: outcome).exists?
        return render json: { error: "Invalid outcome" }, status: :unprocessable_entity
      end

      market.update!(status: :settled, settled_outcome: outcome, settled_by: current_user)
      AuditEvent.create!(
        actor: current_user,
        action: "market.settle",
        target_type: "Market",
        target_id: market.id,
        reason: params[:reason],
        metadata: { outcome: outcome }
      )
      render json: { id: market.id, status: market.status, settled_outcome: market.settled_outcome }
    end

    private

    def market_params
      params.permit(:question, :description, :status, :structure_locked)
    end

    def seed_default_legs(market)
      %w[YES NO].each do |label|
        market.market_legs.find_or_create_by!(label: label) do |leg|
          leg.odds_minor = 5000
          leg.active = true
        end
      end
    end
  end
end
