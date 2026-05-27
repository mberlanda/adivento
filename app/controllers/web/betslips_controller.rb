module Web
  class BetslipsController < BaseController
    def quotes
      quote = BetslipQuoteService.call(
        user: current_user,
        items: items_param,
        idempotency_key: params[:idempotency_key].to_s
      )
      render json: serialize_quote(quote)
    rescue BetslipQuoteService::Conflict => e
      render json: { error: e.message }, status: :conflict
    rescue BetslipQuoteService::InvalidQuote => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def execute
      quote = BetslipQuote.where(user_id: current_user.id).find(params.expect(:quote_id))
      execution = BetslipExecutionService.execute!(quote: quote, actor: current_user)
      render json: {
        execution_id: execution.id,
        bet_ids: execution.bet_ids,
        status: execution.status
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Quote not found' }, status: :not_found
    rescue BetslipExecutionService::ExpiredQuote,
           BetslipExecutionService::AlreadyExecuted,
           BetslipExecutionService::ExecutionFailed => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def items_param
      raw = params[:items]
      raw = raw.values if raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)
      Array(raw).map do |item|
        h = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
        { market_leg_id: h[:market_leg_id] || h['market_leg_id'], stake_minor: h[:stake_minor] || h['stake_minor'] }
      end
    end

    def serialize_quote(quote)
      {
        quote_id: quote.id,
        items: quote.items,
        total_stake_minor: quote.total_stake_minor,
        expires_at: quote.expires_at.iso8601
      }
    end
  end
end
