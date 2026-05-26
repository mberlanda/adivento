require "test_helper"

class HotStorage::ReconcileMarketHotStateJobTest < ActiveJob::TestCase
  setup do
    @fake_redis = HotStorage::FakeRedis.new
    @store = HotStorage::Store.new(redis: @fake_redis)
  end

  test "reconciles stale hot snapshot with cold state" do
    market = markets(:open_market)
    @store.write_market_snapshot!(
      market_id: market.id,
      snapshot: {
        market_id: market.id,
        status: "draft",
        settled_outcome: nil,
        total_open_interest_minor: 0,
        updated_at: Time.current.iso8601,
        legs: []
      },
      version: 1
    )

    HotStorage::ReconcileMarketHotStateJob.perform_now(market_ids: [market.id], store: @store)

    hot_snapshot = @store.read_market_snapshot(market_id: market.id)

    assert_equal "open", hot_snapshot.fetch("status")
    assert_equal 2, hot_snapshot.fetch("legs").length
    assert_equal HotStorage::MarketSnapshotProjector.market_version(market), hot_snapshot.fetch("version")
  end
end
