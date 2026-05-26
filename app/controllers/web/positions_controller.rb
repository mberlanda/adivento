module Web
  class PositionsController < BaseController
    def index
      bets = Bet.includes(:market, :market_leg)
                .where(user_id: current_user.id, status: :open)
                .order(created_at: :desc)
      render json: { positions: bets.map { |b| serialize_position(b) } }
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
      render json: { error: "Bet not found" }, status: :not_found
    rescue CashoutQuoteService::InvalidPosition => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def cashout_execute
      bet = current_user_bet
      credited = CashoutExecutionService.execute!(bet: bet, actor: current_user)
      render json: { status: "completed", credited_minor: credited }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Bet not found" }, status: :not_found
    rescue CashoutExecutionService::InvalidPosition, CashoutQuoteService::InvalidPosition => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def current_user_bet
      Bet.where(user_id: current_user.id).find(params[:bet_id])
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
  end
end
