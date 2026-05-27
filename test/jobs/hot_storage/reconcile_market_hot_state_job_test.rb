require 'test_helper'

module HotStorage
  class ReconcileMarketHotStateJobTest < ActiveJob::TestCase
    setup do
      @fake_redis = HotStorage::FakeRedis.new
      @store = HotStorage::Store.new(redis: @fake_redis)
    end

    test 'reconciles stale hot snapshot with cold state' do
      market = markets(:open_market)
      @store.write_market_snapshot!(
        market_id: market.id,
        snapshot: {
          market_id: market.id,
          status: 'draft',
          settled_outcome: nil,
          total_open_interest_minor: 0,
          updated_at: Time.current.iso8601,
          legs: []
        },
        version: 1
      )

      HotStorage::ReconcileMarketHotStateJob.perform_now(market_ids: [market.id], store: @store)

      hot_snapshot = @store.read_market_snapshot(market_id: market.id)

      assert_equal 'open', hot_snapshot.fetch('status')
      assert_equal 2, hot_snapshot.fetch('legs').length
      assert_equal HotStorage::MarketSnapshotProjector.market_version(market), hot_snapshot.fetch('version')
    end

    test 'reconciles all open and settled markets when called with no market_id' do
      market = markets(:open_market)

      HotStorage::ReconcileMarketHotStateJob.perform_now(store: @store)

      hot_snapshot = @store.read_market_snapshot(market_id: market.id)

      assert_not_nil hot_snapshot, 'open market should have been reconciled'
      assert_equal 'open', hot_snapshot.fetch('status')
    end

    test 'reconciles only the specified market when market_id is given' do
      open_market  = markets(:open_market)
      draft_market = markets(:draft_market)

      HotStorage::ReconcileMarketHotStateJob.perform_now(market_id: open_market.id, store: @store)

      assert_not_nil @store.read_market_snapshot(market_id: open_market.id)
      assert_nil     @store.read_market_snapshot(market_id: draft_market.id)
    end

    test 'does not abort when one market projection raises a Redis error' do
      open_market  = markets(:open_market)
      draft_market = markets(:draft_market)

      write_count = 0
      error_on_first_write_store = Class.new(HotStorage::Store) do
        define_method(:write_market_snapshot!) do |**kwargs|
          write_count += 1
          raise StandardError, 'Redis boom' if write_count == 1

          super(**kwargs)
        end
      end.new(redis: @fake_redis)

      assert_nothing_raised do
        HotStorage::ReconcileMarketHotStateJob.perform_now(
          market_ids: [open_market.id, draft_market.id],
          store: error_on_first_write_store
        )
      end

      assert_equal 2, write_count, 'should have attempted both markets even after first error'
    end
  end
end
