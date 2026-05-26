require "test_helper"

class HotStorage::MarketSnapshotProjectorTest < ActiveSupport::TestCase
  setup do
    @fake_redis = HotStorage::FakeRedis.new
    @store = HotStorage::Store.new(redis: @fake_redis)
  end

  test "projects cold market state to hot snapshot and stream event" do
    market = markets(:open_market)

    snapshot = HotStorage::MarketSnapshotProjector.project!(
      market: market,
      reason: "test_projection",
      store: @store
    )

    hot_snapshot = @store.read_market_snapshot(market_id: market.id)

    assert_equal market.id, hot_snapshot.fetch("market_id")
    assert_equal "open", hot_snapshot.fetch("status")
    assert_equal 297, hot_snapshot.fetch("total_open_interest_minor")
    assert_equal 2, hot_snapshot.fetch("legs").length
    assert_operator snapshot.fetch(:version), :>, 0

    stream_key = "adivento:hot:v1:market:#{market.id}:events"
    assert_equal 1, @fake_redis.events.fetch(stream_key).length
    assert_equal "market.snapshot.v1", @fake_redis.events.fetch(stream_key).first.fetch(:fields).fetch("event")
  end
end
