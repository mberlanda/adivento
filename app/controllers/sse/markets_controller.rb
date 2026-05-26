module Sse
  class MarketsController < ApplicationController
    include Authentication

    before_action :authenticate_request!, except: [:show]

    def show
      snapshot = HotStorage::MarketSnapshotReader.call(market_id: params[:id])
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"

      render plain: sse_event(
        id: snapshot[:version],
        name: "market.snapshot.v1",
        data: snapshot.except(:version)
      )
    end

    private

    def sse_event(id:, name:, data:)
      "id: #{id}\nevent: #{name}\ndata: #{data.to_json}\n"
    end
  end
end
