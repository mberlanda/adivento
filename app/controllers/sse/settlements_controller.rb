module Sse
  class SettlementsController < ApplicationController
    def show
      market = Market.find(params[:id])
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"

      render plain: "id: #{market.updated_at.to_i}\nevent: settlement.changed.v1\ndata: #{ { market_id: market.id, status: market.status, settled_outcome: market.settled_outcome }.to_json }\n"
    end
  end
end
