module Web
  class OrderBooksController < BaseController
    def show
      market = Market.find(params.expect(:market_id))
      return render json: { error: 'Not a CLOB market' }, status: :unprocessable_content unless market.clob?

      engine = market.pricing_engine
      book   = engine.order_book_summary

      bids = market.orders.where(side: 'YES', status: %w[open partial])
                   .group(:price_cents)
                   .sum('quantity - filled_quantity - cancelled_quantity')
                   .sort.reverse.first(10)
                   .map { |price, qty| { price_cents: price, quantity: qty } }
      asks = market.orders.where(side: 'NO', status: %w[open partial])
                   .group(:price_cents)
                   .sum('quantity - filled_quantity - cancelled_quantity')
                   .sort.first(10)
                   .map { |price, qty| { price_cents: price, quantity: qty } }

      spread = book[:bid] && book[:ask] ? book[:ask] - (100 - book[:bid]) : nil

      render json: {
        market_id: market.id,
        best_bid: book[:bid],
        best_ask: book[:ask],
        last_trade_price: market.last_fill_price_cents,
        spread: spread,
        bids: bids,
        asks: asks
      }
    end
  end
end
