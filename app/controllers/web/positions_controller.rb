module Web
  class PositionsController < BaseController
    def index
      bets = Bet.includes(:market, :market_leg)
                .where(user_id: current_user.id, status: :open)
                .order(created_at: :desc)
      @positions = bets.map { |b| serialize_position(b) }
      @clob_positions = clob_contract_positions
      respond_to do |format|
        format.html
        format.json { render json: { positions: @positions, clob_positions: @clob_positions } }
      end
    end

    def cashout_quotes
      bet = current_user_bet
      quote = CashoutQuoteService.quote(bet: bet)
      render json: {
        bet_id: quote.bet_id,
        gross_payout_minor: quote.gross_payout_minor,
        fee_minor: quote.fee_minor,
        net_payout_minor: quote.net_payout_minor,
        expires_at: quote.expires_at.iso8601
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Bet not found' }, status: :not_found
    rescue CashoutQuoteService::InvalidPosition => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def cashout_execute
      bet = current_user_bet
      credited = CashoutExecutionService.execute!(bet: bet, actor: current_user)
      render json: { status: 'completed', credited_minor: credited }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Bet not found' }, status: :not_found
    rescue CashoutExecutionService::InvalidPosition, CashoutQuoteService::InvalidPosition => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def clob_cashout
      market = Market.find(params.expect(:market_id))
      result = Clob::ClobCashoutService.call(
        market: market,
        user: current_user,
        side: params.expect(:side).upcase,
        contracts: params.expect(:contracts),
        price_cents: params.expect(:price_cents)
      )
      if result.success?
        redirect_to web_positions_path, notice: "Sell order placed (order ##{result.order.id})"
      else
        redirect_to web_positions_path, alert: result.errors.join(', ')
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to web_positions_path, alert: 'Market not found'
    end

    private

    def current_user_bet
      Bet.where(user_id: current_user.id).find(params.expect(:bet_id))
    end

    def serialize_position(bet)
      {
        bet_id: bet.id,
        market_id: bet.market_id,
        market_question: bet.market.question,
        market_leg_id: bet.market_leg_id,
        leg_label: bet.market_leg.label,
        stake_minor: bet.stake_minor,
        odds_minor: bet.odds_minor,
        potential_payout_minor: bet.potential_payout_minor,
        status: bet.status
      }
    end

    def clob_contract_positions
      base = Order
             .where(user_id: current_user.id)
             .where('filled_quantity > 0')
             .joins(:market)
             .where(markets: { mechanism_type: 'clob' })
             .group(:market_id, :side, :direction)
             .select(
               'orders.market_id',
               'orders.side',
               'orders.direction',
               'SUM(orders.filled_quantity) AS total_qty',
               'SUM(orders.price_cents * orders.filled_quantity) AS weighted_price_sum'
             )

      # Compute net position per market/side: bought - sold
      grouped = base.each_with_object({}) do |row, h|
        key = [row.market_id, row.side]
        h[key] ||= { total_qty: 0, weighted_price_sum: 0 }
        delta = row.direction == 'buy' ? row.total_qty.to_i : -row.total_qty.to_i
        h[key][:total_qty] += delta
        h[key][:weighted_price_sum] += row.total_qty.to_i * (row.direction == 'buy' ? row.weighted_price_sum.to_i / [row.total_qty.to_i, 1].max : 0)
      end

      market_ids = grouped.keys.map(&:first).uniq
      markets_by_id = Market.where(id: market_ids).index_by(&:id)

      market_ids.filter_map do |market_id|
        market  = markets_by_id[market_id]
        yes_qty = grouped[[market_id, 'YES']]&.dig(:total_qty).to_i
        no_qty  = grouped[[market_id, 'NO']]&.dig(:total_qty).to_i
        next if yes_qty <= 0 && no_qty <= 0

        yes_sum    = grouped[[market_id, 'YES']]&.dig(:weighted_price_sum).to_i
        avg_yes    = yes_qty.positive? ? yes_sum / yes_qty : nil
        best_bid   = market.open? ? market.pricing_engine.order_book_summary[:bid] : nil
        unrealised = best_bid && yes_qty.positive? ? yes_qty * best_bid : nil

        {
          market_id: market_id,
          market_question: market.question,
          yes_contracts: yes_qty,
          no_contracts: no_qty,
          avg_yes_price_cents: avg_yes,
          unrealised_value_minor: unrealised
        }
      end
    end
  end
end
