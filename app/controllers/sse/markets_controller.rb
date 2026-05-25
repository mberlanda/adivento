module Sse
  class MarketsController < ApplicationController
    include Authentication

    before_action :authenticate_request!, except: [:show]

    def show
      market = Market.find(params[:id])
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"

      render plain: [
        sse_event(id: market.updated_at.to_i, name: "market.snapshot.v1", data: {
          market_id: market.id,
          status: market.status,
          settled_outcome: market.settled_outcome,
          legs: market.market_legs.order(:id).pluck(:label, :odds_minor).map { |label, odds| { label: label, odds_minor: odds } }
        }),
        sse_event(id: Time.current.to_i, name: "market.settlement_changed.v1", data: {
          market_id: market.id,
          settled: market.settled?,
          settled_outcome: market.settled_outcome
        })
      ].join("\n")
    end

    private

    def sse_event(id:, name:, data:)
      "id: #{id}\nevent: #{name}\ndata: #{data.to_json}\n"
    end
  end
end
