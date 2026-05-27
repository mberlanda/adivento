class RecordPriceSnapshotJob < ApplicationJob
  queue_as :default

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return unless market&.open?

    PriceSnapshotRecorder.record(market)
  end
end
