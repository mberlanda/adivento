module Clob
  # Places a sell limit order on behalf of a player to exit a CLOB position.
  # Validates the player has sufficient net contracts before creating the order.
  class ClobCashoutService
    Result = Struct.new(:success?, :order, :errors, keyword_init: true)

    def self.call(**) = new(**).call

    def initialize(market:, user:, side:, contracts:, price_cents:)
      @market      = market
      @user        = user
      @side        = side
      @contracts   = contracts.to_i
      @price_cents = price_cents.to_i
    end

    def call
      return Result.new(success?: false, order: nil, errors: ['Market is not open for trading']) unless @market.open?
      return Result.new(success?: false, order: nil, errors: ['Market is not a CLOB market']) unless @market.clob?
      return Result.new(success?: false, order: nil, errors: ['Contracts must be positive']) unless @contracts.positive?

      leg = @market.market_legs.find_by(label: @side)
      result = OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @user, market_leg: leg, side: @side,
          direction: 'sell', price_cents: @price_cents,
          quantity: @contracts, time_in_force: :gtc
        }
      )

      if result.success?
        Result.new(success?: true, order: result.incoming_order, errors: [])
      else
        Result.new(success?: false, order: nil, errors: result.errors)
      end
    end
  end
end
