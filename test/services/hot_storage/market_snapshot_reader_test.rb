require "test_helper"

class HotStorage::MarketSnapshotReaderTest < ActiveSupport::TestCase
  setup do
    @fake_redis = HotStorage::FakeRedis.new
    @store = HotStorage::Store.new(redis: @fake_redis)
  end

  test "reads existing hot snapshot when present" do
    market = markets(:open_market)
    @store.write_market_snapshot!(
      market_id: market.id,
      snapshot: {
        market_id: market.id,
        status: "open",
        settled_outcome: nil,
        total_open_interest_minor: 0,
        updated_at: Time.current.iso8601,
        legs: []
      },
      version: 99
    )

    snapshot = HotStorage::MarketSnapshotReader.call(market_id: market.id, store: @store)

    assert_equal 99, snapshot.fetch(:version)
    assert_equal [], snapshot.fetch(:legs)
  end

  test "rebuilds hot snapshot from cold storage when hot cache misses" do
    market = markets(:open_market)

    snapshot = HotStorage::MarketSnapshotReader.call(market_id: market.id, store: @store)

    assert_equal market.id, snapshot.fetch(:market_id)
    assert_equal "open", snapshot.fetch(:status)
    assert_equal 2, snapshot.fetch(:legs).length
    assert_operator snapshot.fetch(:version), :>, 0
  end
end
