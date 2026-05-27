module Backoffice
  class MarketsController < BaseController
    before_action -> { require_permission!('market.read') }
    before_action :set_market, only: %i[show open settle]

    def index
      @markets = Market.includes(:market_legs, :created_by).order(created_at: :desc)
    end

    def show
      @bets = @market.bets.includes(:user, :market_leg).order(created_at: :desc)
    end

    def create
      require_permission!('market.create')
      return if performed?

      market = Market.new(market_create_params.merge(created_by: current_user))
      if market.save
        legs = params[:legs].to_s.split(',').map(&:strip).compact_blank
        legs = %w[YES NO] if legs.empty?
        legs.each do |label|
          market.market_legs.find_or_create_by!(label: label) do |leg|
            leg.odds_minor = 5000
            leg.active = true
          end
        end
        HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: 'market.create')
        AuditEvent.create!(
          actor: current_user,
          action: 'market.create',
          target_type: 'Market',
          target_id: market.id,
          metadata: {}
        )
        redirect_to backoffice_market_path(market), notice: 'Market created'
      else
        @markets = Market.includes(:market_legs, :created_by).order(created_at: :desc)
        flash.now[:alert] = market.errors.full_messages.join(', ')
        render :index, status: :unprocessable_content
      end
    end

    def open
      require_permission!('market.update')
      return if performed?

      return redirect_to backoffice_market_path(@market), alert: 'Market is not in draft state' unless @market.draft?

      @market.update!(status: :open)
      HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: 'market.open')
      AuditEvent.create!(
        actor: current_user,
        action: 'market.open',
        target_type: 'Market',
        target_id: @market.id,
        metadata: {}
      )
      redirect_to backoffice_market_path(@market), notice: 'Market is now open'
    end

    def settle
      require_permission!('market.settle')
      return if performed?

      outcome = params[:outcome].to_s.upcase

      return redirect_to backoffice_market_path(@market), alert: 'Market must be open to settle' unless @market.open?

      SettlementService.settle!(market: @market, outcome: outcome, actor: current_user)
      redirect_to backoffice_market_path(@market), notice: "Market settled: #{outcome}"
    rescue SettlementService::InvalidSettlement => e
      redirect_to backoffice_market_path(@market), alert: e.message
    end

    private

    def set_market
      @market = Market.includes(:market_legs).find(params.expect(:id))
    end

    def market_create_params
      params.permit(:question, :description, :mechanism_type, :fee_bps, :liability_cap_minor,
                    :taker_fee_bps, :liquidity_subsidy_minor, :spread_fee_bps, :takeout_bps)
    end
  end
end
