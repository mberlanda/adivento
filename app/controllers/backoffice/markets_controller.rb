module Backoffice
  class MarketsController < BaseController
    before_action -> { require_permission!('market.read') }
    before_action :set_market, only: %i[show open settle update operator_buyback]

    def index
      @page     = [params[:page].to_i, 1].max
      @per_page = 20
      @total    = Market.count
      @markets  = Market.includes(:market_legs, :created_by).order(created_at: :desc)
                        .limit(@per_page).offset((@page - 1) * @per_page)
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

    def update
      require_permission!('market.update')
      return if performed?

      if @market.update(market_update_params)
        HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: 'market.update')
        AuditEvent.create!(
          actor: current_user, action: 'market.update',
          target_type: 'Market', target_id: @market.id, metadata: {}
        )
        redirect_to backoffice_market_path(@market), notice: 'Market updated'
      else
        flash.now[:alert] = @market.errors.full_messages.join(', ')
        @bets = @market.bets.includes(:user, :market_leg).order(created_at: :desc)
        render :show, status: :unprocessable_content
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

    def operator_buyback
      require_permission!('market.update')
      return if performed?

      unless @market.clob? && @market.open?
        return redirect_to backoffice_market_path(@market), alert: 'Buyback only available on open CLOB markets'
      end

      result = Clob::OperatorBuybackService.call(
        market: @market,
        operator: current_user,
        side: params.expect(:side).upcase,
        contracts: params.expect(:contracts)
      )

      if result.success?
        redirect_to backoffice_market_path(@market), notice: "Buyback order placed at mid-price (order ##{result.orders.first.id})"
      else
        redirect_to backoffice_market_path(@market), alert: result.errors.join(', ')
      end
    end

    def settle
      require_permission!('market.settle')
      return if performed?

      outcome = params[:outcome].to_s.upcase

      unless @market.open? || @market.closed?
        return redirect_to backoffice_market_path(@market),
                           alert: 'Market must be open or closed to settle'
      end

      SettlementService.settle!(market: @market, outcome: outcome, actor: current_user)
      redirect_to backoffice_market_path(@market), notice: "Market settled: #{outcome}"
    rescue SettlementService::InvalidSettlement => e
      redirect_to backoffice_market_path(@market), alert: e.message
    end

    private

    def set_market
      @market = Market.includes(:market_legs).find(params.expect(:id))
    end

    def market_update_params
      params.permit(:description, :close_at, :resolution_criteria, :resolution_source, :category, :tags_input).tap do |p|
        if p[:tags_input]
          tags = p.delete(:tags_input).to_s.split(',').map(&:strip).reject(&:empty?)
          p[:tags] = tags
        end
      end
    end

    def market_create_params
      permitted = params.permit(:question, :description, :mechanism_type, :fee_bps,
                                :liability_cap_minor, :taker_fee_bps, :liquidity_subsidy_minor,
                                :spread_fee_bps, :takeout_bps, :category, :tags_input,
                                :close_at, :resolution_criteria, :resolution_source)
      if permitted[:tags_input]
        permitted = permitted.except(:tags_input).merge(
          tags: permitted[:tags_input].to_s.split(',').map(&:strip).reject(&:empty?)
        )
      end
      permitted
    end
  end
end
