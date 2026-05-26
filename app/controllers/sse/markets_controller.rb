module Sse
  class MarketsController < ApplicationController
    include Authentication

    before_action :authenticate_request!, except: [:show]

    def show
      snapshot = HotStorage::MarketSnapshotReader.call(market_id: params[:id])
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"

      render plain: [
        sse_event(id: snapshot[:version], name: "market.snapshot.v1", data: snapshot.except(:version)),
        sse_event(id: Time.current.to_i, name: "market.settlement_changed.v1", data: {
          market_id: snapshot[:market_id],
          settled: snapshot[:status].to_s == "settled",
          settled_outcome: snapshot[:settled_outcome]
        }),
        sse_event(id: Time.current.to_i, name: "market.bet_voided.v1", data: voided_payload(snapshot[:market_id]))
      ].join("\n")
    end

    private

    def sse_event(id:, name:, data:)
      "id: #{id}\nevent: #{name}\ndata: #{data.to_json}\n"
    end

    def voided_payload(market_id)
      last_voided = Bet.where(market_id: market_id, status: :voided).order(updated_at: :desc).first
      {
        market_id: market_id.to_i,
        voided_bets_count: Bet.where(market_id: market_id, status: :voided).count,
        last_voided_bet_id: last_voided&.id
      }
    end
  end
end
