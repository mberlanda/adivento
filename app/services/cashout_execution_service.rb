class CashoutExecutionService
  class InvalidPosition < StandardError; end

  def self.execute!(bet:, actor:)
    ApplicationRecord.transaction do
      locked_bet = Bet.lock.find(bet.id)
      raise InvalidPosition, 'Bet is not open' unless locked_bet.open?
      raise InvalidPosition, 'Market is not open' unless locked_bet.market.open?

      quote = CashoutQuoteService.quote(bet: locked_bet)

      wallet = locked_bet.user.wallet.lock!
      wallet.update!(available_minor: wallet.available_minor + quote.net_payout_minor)

      locked_bet.update!(status: :voided)

      LedgerEntry.create!(
        user: locked_bet.user,
        actor: actor,
        entry_type: 'BET_CASHOUT_PAYOUT',
        amount_minor: quote.net_payout_minor,
        direction: 'credit',
        metadata: { bet_id: locked_bet.id, market_id: locked_bet.market_id }
      )

      if quote.fee_minor.positive?
        LedgerEntry.create!(
          user: locked_bet.user,
          actor: actor,
          entry_type: 'BET_CASHOUT_FEE',
          amount_minor: quote.fee_minor,
          direction: 'debit',
          metadata: { bet_id: locked_bet.id, market_id: locked_bet.market_id }
        )
      end

      AuditEvent.create!(
        actor: actor,
        action: 'bet.cashout',
        target_type: 'Bet',
        target_id: locked_bet.id,
        metadata: {
          bet_id: locked_bet.id,
          net_payout_minor: quote.net_payout_minor,
          fee_minor: quote.fee_minor
        }
      )

      quote.net_payout_minor
    end
  end
end
