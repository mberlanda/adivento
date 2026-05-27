module Web
  class OrderBooksController < ApplicationController
    def show
      market = Market.find(params[:market_id])
      return render json: { error: "Not a CLOB market" }, status: :unprocessable_entity unless market.clob?

      engine = market.pricing_engine
      book   = engine.order_book_summary

      bids = market.orders.where(side: "YES", status: %w[open partial])
               .group(:price_cents).sum(:quantity)
               .sort.reverse.first(10)
               .map { |price, qty| { price_cents: price, quantity: qty } }
      asks = market.orders.where(side: "NO", status: %w[open partial])
               .group(:price_cents).sum(:quantity)
               .sort.reverse.first(10)
               .map { |price, qty| { price_cents: price, quantity: qty } }

      render json: {
        market_id: market.id,
        best_bid: book[:bid],
        best_ask: book[:ask],
        bids: bids,
        asks: asks
      }
    end
  end
end
