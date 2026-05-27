module Admin
  class MarketsController < BaseController
    before_action -> { require_permission!('market.read') }

    def show
      market = Market.includes(:market_legs).find(params.expect(:id))
      render json: {
        id: market.id,
        question: market.question,
        status: market.status,
        legs: market.market_legs.map { |l| { id: l.id, label: l.label, odds_minor: l.odds_minor } }
      }
    end

    def create
      require_permission!('market.create')
      return if performed?

      market = Market.new(market_params.merge(created_by: current_user))
      if market.save
        seed_default_legs(market)
        HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: 'market.create')
        render json: { id: market.id, status: market.status }, status: :created
      else
        render json: { errors: market.errors.full_messages }, status: :unprocessable_content
      end
    end

    def update
      require_permission!('market.update')
      return if performed?

      market = Market.find(params.expect(:id))
      if market.update(market_params)
        HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: 'market.update')
        AuditEvent.create!(
          actor: current_user,
          action: 'market.update',
          target_type: 'Market',
          target_id: market.id,
          metadata: {}
        )
        render json: { id: market.id, status: market.status }
      else
        render json: { errors: market.errors.full_messages }, status: :unprocessable_content
      end
    end

    def settle
      require_permission!('market.settle')
      return if performed?

      market = Market.find(params.expect(:id))
      outcome = params[:outcome].to_s.upcase
      market = SettlementService.settle!(market: market, outcome: outcome, actor: current_user)
      render json: { id: market.id, status: market.status, settled_outcome: market.settled_outcome }
    rescue SettlementService::InvalidSettlement => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def risk
      require_permission!('risk.read')
      return if performed?

      market = Market.includes(:market_legs).find(params.expect(:id))
      pnl_by_outcome = HouseRiskService.pnl_by_outcome(market)

      render json: {
        market_id: market.id,
        mechanism_type: market.mechanism_type,
        fee_bps: market.fee_bps,
        liability_cap_minor: market.liability_cap_minor,
        pnl_by_outcome_minor: pnl_by_outcome.transform_keys(&:label),
        worst_case_liability_minor: HouseRiskService.worst_case_liability(market)
      }
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
