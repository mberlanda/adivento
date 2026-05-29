module Clob
  # Places buy orders on behalf of the operator at the current mid-price,
  # providing liquidity that sell orders can match against immediately.
  class OperatorBuybackService
    Result = Struct.new(:success?, :orders, :errors, keyword_init: true)

    def self.call(**) = new(**).call

    def initialize(market:, operator:, side:, contracts:)
      @market    = market
      @operator  = operator
      @side      = side
      @contracts = contracts.to_i
    end

    def call
      return Result.new(success?: false, orders: [], errors: ['Market is not a CLOB market']) unless @market.clob?
      return Result.new(success?: false, orders: [], errors: ['Contracts must be positive']) unless @contracts.positive?

      price = mid_price
      return Result.new(success?: false, orders: [], errors: ['Cannot determine mid-price: order book is empty']) if price.nil?

      leg = @market.market_legs.find_by(label: @side)
      result = OrderMatchingService.call(
        market: @market,
        incoming_order_params: {
          user: @operator, market_leg: leg, side: @side,
          direction: 'buy', price_cents: price,
          quantity: @contracts, time_in_force: :gtc
        }
      )

      if result.success?
        Result.new(success?: true, orders: [result.incoming_order], errors: [])
      else
        Result.new(success?: false, orders: [], errors: result.errors)
      end
    end

    private

    def mid_price
      summary = @market.pricing_engine.order_book_summary
      bid     = summary[:bid] # best YES buy price
      yes_ask = summary[:ask] ? 100 - summary[:ask] : nil # NO bid implies YES ask = 100 - no_bid

      return nil if bid.nil? && yes_ask.nil?
      return bid     if yes_ask.nil?
      return yes_ask if bid.nil?

      ((bid + yes_ask) / 2.0).round
    end
  end
end
