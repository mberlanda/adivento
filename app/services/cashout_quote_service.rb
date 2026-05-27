class CashoutQuoteService
  class InvalidPosition < StandardError; end

  Quote = Struct.new(:bet_id, :gross_payout_minor, :fee_minor, :net_payout_minor, :expires_at, keyword_init: true)

  TTL_SECONDS = 60

  def self.quote(bet:)
    raise InvalidPosition, 'Bet is not open' unless bet.open?
    raise InvalidPosition, 'Market is not open' unless bet.market.open?

    gross = (bet.stake_minor * bet.market_leg.odds_minor / 10_000.0).floor
    fee = (gross * bet.market.fee_bps / 10_000.0).ceil
    net = gross - fee

    Quote.new(
      bet_id: bet.id,
      gross_payout_minor: gross,
      fee_minor: fee,
      net_payout_minor: net,
      expires_at: Time.current + TTL_SECONDS.seconds
    )
  end
end
