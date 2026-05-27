class BetslipExecutionService
  class ExpiredQuote < StandardError; end
  class AlreadyExecuted < StandardError; end
  class ExecutionFailed < StandardError; end

  def self.execute!(quote:, actor:)
    raise AlreadyExecuted, "Quote #{quote.id} already executed" if quote.executed?
    raise ExpiredQuote, "Quote #{quote.id} expired at #{quote.expires_at}" if quote.expired?

    if (existing = BetslipExecution.find_by(betslip_quote_id: quote.id))
      return existing
    end

    bet_ids = []

    ApplicationRecord.transaction do
      quote.lock!
      raise AlreadyExecuted, "Quote #{quote.id} already executed" if quote.executed?

      quote.items.each do |item|
        leg = MarketLeg.find(item['market_leg_id'])
        market = leg.market
        bet = BetPlacementService.place!(
          user: quote.user,
          market: market,
          market_leg: leg,
          stake_minor: item['stake_minor']
        )
        bet_ids << bet.id
      end

      quote.update!(status: :executed)

      execution = BetslipExecution.create!(
        betslip_quote: quote,
        user: quote.user,
        bet_ids: bet_ids,
        status: :completed
      )

      AuditEvent.create!(
        actor: actor,
        action: 'betslip.execute',
        target_type: 'BetslipExecution',
        target_id: execution.id,
        metadata: { quote_id: quote.id, bet_count: bet_ids.length }
      )

      execution
    end
  rescue BetPlacementService::InvalidBet, BetPlacementService::RiskLimitExceeded => e
    raise ExecutionFailed, e.message
  end
end
