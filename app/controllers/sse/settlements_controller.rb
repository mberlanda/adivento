module Sse
  class SettlementsController < ApplicationController
    def show
      market = Market.find(params.expect(:id))
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache'

      payload = { market_id: market.id, status: market.status, settled_outcome: market.settled_outcome }.to_json
      render plain: "id: #{market.updated_at.to_i}\nevent: settlement.changed.v1\ndata: #{payload}\n"
    end
  end
end
