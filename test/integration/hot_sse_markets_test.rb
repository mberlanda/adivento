require 'test_helper'

class HotSseMarketsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_store = HotStorage::Store.current
    @fake_redis = HotStorage::FakeRedis.new
    HotStorage::Store.current = HotStorage::Store.new(redis: @fake_redis)
  end

  teardown do
    HotStorage::Store.current = @previous_store
  end

  test 'market sse endpoint serves hot snapshot when available' do
    market = markets(:open_market)

    HotStorage::Store.current.write_market_snapshot!(
      market_id: market.id,
      snapshot: {
        market_id: market.id,
        status: 'open',
        settled_outcome: nil,
        total_open_interest_minor: 9_999,
        updated_at: Time.current.iso8601,
        legs: [
          { id: market_legs(:yes_leg).id, label: 'YES', odds_minor: 7_777, active: true },
          { id: market_legs(:no_leg).id, label: 'NO', odds_minor: 2_223, active: true }
        ]
      },
      version: 555
    )

    get "/sse/markets/#{market.id}"

    assert_response :success
    assert_equal 'text/event-stream', response.media_type
    assert_match 'event: market.snapshot.v1', response.body
    assert_match '"odds_minor":7777', response.body
    assert_match '"total_open_interest_minor":9999', response.body
  end

  test 'market sse endpoint falls back to cold snapshot when Redis has no snapshot' do
    market = markets(:open_market)
    # FakeRedis starts empty — no snapshot written

    get "/sse/markets/#{market.id}"

    assert_response :success
    assert_equal 'text/event-stream', response.media_type
    assert_match 'event: market.snapshot.v1', response.body
    assert_match "\"market_id\":#{market.id}", response.body
    assert_match '"status":"open"', response.body
    # Should NOT emit the two extra synthetic events
    assert_no_match 'event: market.settlement_changed.v1', response.body
    assert_no_match 'event: market.bet_voided.v1', response.body
  end

  test 'market sse endpoint emits only the snapshot event (no synthetic extras)' do
    market = markets(:open_market)
    HotStorage::Store.current.write_market_snapshot!(
      market_id: market.id,
      snapshot: {
        market_id: market.id,
        status: 'open',
        settled_outcome: nil,
        total_open_interest_minor: 100,
        updated_at: Time.current.iso8601,
        legs: []
      },
      version: 42
    )

    get "/sse/markets/#{market.id}"

    assert_response :success
    body_events = response.body.scan(/^event: .*/).map { |l| l.sub('event: ', '') }

    assert_equal ['market.snapshot.v1'], body_events
  end
end
