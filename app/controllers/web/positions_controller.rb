module Web
  class PositionsController < BaseController
    def index
      bets = Bet.includes(:market, :market_leg)
                .where(user_id: current_user.id, status: :open)
                .order(created_at: :desc)
      render json: {
        positions: bets.map { |b| serialize_position(b) },
        clob_positions: clob_contract_positions
      }
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
      rows = Order
             .where(user_id: current_user.id)
             .where('filled_quantity > 0')
             .joins(:market)
             .where(markets: { mechanism_type: 'clob' })
             .group(:market_id, :side)
             .select(
               'orders.market_id',
               'orders.side',
               'SUM(orders.filled_quantity) AS total_qty',
               'SUM(orders.price_cents * orders.filled_quantity) AS weighted_price_sum'
             )

      by_market = rows.group_by(&:market_id)
      markets_by_id = Market.where(id: by_market.keys).index_by(&:id)

      by_market.filter_map do |market_id, market_rows|
        market  = markets_by_id[market_id]
        yes_row = market_rows.find { |r| r.side == 'YES' }
        no_row  = market_rows.find { |r| r.side == 'NO' }
        yes_qty = yes_row&.total_qty.to_i
        no_qty  = no_row&.total_qty.to_i
        next if yes_qty.zero? && no_qty.zero?

        avg_yes    = yes_qty.positive? ? yes_row.weighted_price_sum.to_i / yes_qty : nil
        best_bid   = market.open? ? market.pricing_engine.order_book_summary[:bid] : nil
        unrealised = best_bid ? yes_qty * best_bid : nil

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
