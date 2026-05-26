# Hot/Cold Storage Finalization Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-26-hot-cold-storage.md -->
<!-- Written AFTER the spec is approved. Describes HOW. -->
<!-- Each task = one atomic commit. Each step = one verifiable action. -->

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use `- [ ]` for tracking.

**Goal:** Complete the hot/cold storage layer so that Redis snapshots are authoritative for SSE reads, the reconciliation job repairs drift, and the SSE stream fans out live events to connected clients.

**Architecture:** `MarketSnapshotProjector` and `MarketSnapshotReader` are the two write and read surfaces wrapping `HotStorage::Store`. The `Store` already has a `NullRedis` fallback for connection-time failures; what is missing is runtime error handling (Redis raising mid-call) in the projector and reader. The reconciliation job is structurally complete but lacks per-market error isolation and a single-market invocation form. The SSE controller reads the hot snapshot correctly but emits two spurious extra events and lacks a Redis-error fallback.

**Tech Stack:** Rails 8, Minitest, existing patterns (see docs/INDEX.md for file map)

**Spec:** [docs/specs/2026-05-26-hot-cold-storage.md](../../specs/2026-05-26-hot-cold-storage.md)

---

## Current state audit

Before reading task steps, note what **already exists and passes tests**:

| Component | Status | Gap |
|-----------|--------|-----|
| `HotStorage::Store` | Complete | None |
| `HotStorage::NullRedis` | Complete | None |
| `HotStorage::FakeRedis` | Complete | None |
| `MarketSnapshotProjector.project!` | Works but fragile | No rescue for mid-call Redis errors |
| `MarketSnapshotReader.call` | Works but fragile | No rescue for mid-call Redis errors |
| `ReconcileMarketHotStateJob` | Structurally correct | No per-market rescue; only accepts `market_ids:` array, not `market_id:` singular; only reconciles all if nil, but doesn't filter to open/settled |
| `Sse::MarketsController#show` | Works for happy path | Emits 3 events instead of 1 snapshot; no Redis-error fallback |
| `MarketSnapshotProjectorTest` | 1 happy-path test | Missing Redis error test |
| `MarketSnapshotReaderTest` | 2 happy-path tests | Missing Redis error test |
| `ReconcileMarketHotStateJobTest` | 1 test (single market array) | Missing: all-markets form, single-market `market_id:`, per-market error isolation |
| `HotSseMarketsTest` | 1 test (hot path) | Missing cold fallback test |

---

## File Map

**Modify:**
- `app/services/hot_storage/market_snapshot_projector.rb` — wrap store calls in rescue
- `app/services/hot_storage/market_snapshot_reader.rb` — add Redis error rescue path
- `app/jobs/hot_storage/reconcile_market_hot_state_job.rb` — add `market_id:` form, per-market rescue, open/settled scope
- `app/controllers/sse/markets_controller.rb` — emit only snapshot event; add cold fallback
- `test/services/hot_storage/market_snapshot_projector_test.rb` — add Redis error test
- `test/services/hot_storage/market_snapshot_reader_test.rb` — add Redis error test
- `test/jobs/hot_storage/reconcile_market_hot_state_job_test.rb` — add all-markets, single-market, error-isolation tests
- `test/integration/hot_sse_markets_test.rb` — add cold fallback test

---

## Task 1: MarketSnapshotProjector — Redis error resilience

**Files:**
- Modify: `app/services/hot_storage/market_snapshot_projector.rb`
- Test: `test/services/hot_storage/market_snapshot_projector_test.rb`

The projector currently calls `store.write_market_snapshot!` and `store.append_market_event!` without any rescue. If the `Store` was initialized with a real Redis client that later times out or drops connection, these calls will raise and bubble up through callers (including the SSE endpoint and background jobs). We need to rescue and log, then return the snapshot payload so callers always get a value.

Note: `FakeRedis` does not raise by default. We need an `ErrorRedis` test double that always raises to verify resilience.

- [ ] **Step 1.1: Write the failing test**

```ruby
# test/services/hot_storage/market_snapshot_projector_test.rb
# Add after the existing test:

class ErrorRedis
  def set(*) = raise(RuntimeError, "Redis::BaseError simulated")
  def get(*) = raise(RuntimeError, "Redis::BaseError simulated")
  def xadd(*) = raise(RuntimeError, "Redis::BaseError simulated")
end

test "project! does not raise when Redis raises an error" do
  error_store = HotStorage::Store.new(redis: ErrorRedis.new)
  market = markets(:open_market)

  result = nil
  assert_nothing_raised do
    result = HotStorage::MarketSnapshotProjector.project!(
      market: market,
      reason: "test_resilience",
      store: error_store
    )
  end

  assert_equal market.id, result.fetch(:market_id)
  assert_operator result.fetch(:version), :>, 0
end
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
bin/rails test test/services/hot_storage/market_snapshot_projector_test.rb -v
```
Expected: FAIL — `RuntimeError: Redis::BaseError simulated` (or error propagates and raises)

- [ ] **Step 1.3: Implement resilience in projector**

```ruby
# app/services/hot_storage/market_snapshot_projector.rb
module HotStorage
  class MarketSnapshotProjector
    def self.project!(market:, reason:, store: Store.current)
      snapshot = build_snapshot(market)
      version = market_version(market)

      begin
        store.write_market_snapshot!(market_id: market.id, snapshot: snapshot, version: version)
        store.append_market_event!(
          market_id: market.id,
          event_name: "market.snapshot.v1",
          payload: snapshot.merge(reason: reason),
          version: version
        )
      rescue StandardError => e
        Rails.logger.warn("HotStorage::MarketSnapshotProjector: Redis error for market #{market.id}: #{e.class}: #{e.message}")
      end

      snapshot.merge(version: version)
    end

    def self.build_snapshot(market)
      {
        market_id: market.id,
        status: market.status,
        settled_outcome: market.settled_outcome,
        total_open_interest_minor: market.bets.where(status: :open).sum(:net_stake_minor),
        updated_at: market.updated_at&.iso8601,
        legs: market.market_legs.order(:id).map do |leg|
          {
            id: leg.id,
            label: leg.label,
            odds_minor: leg.odds_minor,
            active: leg.active
          }
        end
      }
    end

    def self.market_version(market)
      (market.updated_at.to_f * 1000).to_i
    end
  end
end
```

- [ ] **Step 1.4: Run test to verify it passes**

```bash
bin/rails test test/services/hot_storage/market_snapshot_projector_test.rb -v
```
Expected: 2 tests, 0 failures

- [ ] **Step 1.5: Commit**

```bash
git add app/services/hot_storage/market_snapshot_projector.rb \
        test/services/hot_storage/market_snapshot_projector_test.rb
git commit -m "$(cat <<'EOF'
feat(hot-storage): harden MarketSnapshotProjector with Redis error resilience

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: MarketSnapshotReader — Redis error cold fallback

**Files:**
- Modify: `app/services/hot_storage/market_snapshot_reader.rb`
- Test: `test/services/hot_storage/market_snapshot_reader_test.rb`

The reader currently has a hot path (Redis hit) and a cold-rebuild path (Redis miss → call projector). What's missing is the Redis-error path: if the store raises mid-call (e.g., connection reset after initial connect), we should derive the snapshot from cold DB inline without writing back to Redis, to avoid a write-on-error loop.

The `ErrorRedis` class from Task 1's test file can be re-declared or moved to `test/support/hot_storage/`. For now, redeclare inline in the test file to keep each test file self-contained.

- [ ] **Step 2.1: Write the failing test**

```ruby
# test/services/hot_storage/market_snapshot_reader_test.rb
# Add after existing tests (also add ErrorRedis class if not already defined in this file):

class ErrorRedis
  def set(*) = raise(RuntimeError, "Redis connection lost")
  def get(*) = raise(RuntimeError, "Redis connection lost")
  def xadd(*) = raise(RuntimeError, "Redis connection lost")
end

test "returns cold-derived snapshot and does not raise when Redis errors" do
  error_store = HotStorage::Store.new(redis: ErrorRedis.new)
  market = markets(:open_market)

  result = nil
  assert_nothing_raised do
    result = HotStorage::MarketSnapshotReader.call(market_id: market.id, store: error_store)
  end

  assert_equal market.id, result.fetch(:market_id)
  assert_equal "open", result.fetch(:status)
  assert_operator result.fetch(:version), :>, 0
end
```

- [ ] **Step 2.2: Run test to verify it fails**

```bash
bin/rails test test/services/hot_storage/market_snapshot_reader_test.rb -v
```
Expected: FAIL — `RuntimeError: Redis connection lost` propagates

- [ ] **Step 2.3: Implement cold fallback in reader**

```ruby
# app/services/hot_storage/market_snapshot_reader.rb
module HotStorage
  class MarketSnapshotReader
    def self.call(market_id:, store: Store.current)
      hot_snapshot = store.read_market_snapshot(market_id: market_id)
      return hot_snapshot.deep_symbolize_keys if hot_snapshot.present?

      market = Market.includes(:market_legs, :bets).find(market_id)
      MarketSnapshotProjector.project!(market: market, reason: "cache_miss", store: store)
    rescue StandardError => e
      Rails.logger.warn("HotStorage::MarketSnapshotReader: Redis error for market #{market_id}: #{e.class}: #{e.message}")
      market = Market.includes(:market_legs, :bets).find(market_id)
      MarketSnapshotProjector.build_snapshot(market).merge(
        version: MarketSnapshotProjector.market_version(market)
      )
    end
  end
end
```

- [ ] **Step 2.4: Run test to verify it passes**

```bash
bin/rails test test/services/hot_storage/market_snapshot_reader_test.rb -v
```
Expected: 3 tests, 0 failures

- [ ] **Step 2.5: Commit**

```bash
git add app/services/hot_storage/market_snapshot_reader.rb \
        test/services/hot_storage/market_snapshot_reader_test.rb
git commit -m "$(cat <<'EOF'
feat(hot-storage): add cold fallback to MarketSnapshotReader on Redis error

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: ReconcileMarketHotStateJob — single-market form, open/settled scope, per-market error isolation

**Files:**
- Modify: `app/jobs/hot_storage/reconcile_market_hot_state_job.rb`
- Test: `test/jobs/hot_storage/reconcile_market_hot_state_job_test.rb`

Three gaps to close:
1. The job accepts `market_ids:` (array) but the spec and task contract require a `market_id:` (singular) invocation form
2. The all-markets path uses `Market.includes(...)` without filtering to `[:open, :settled]` — it should only reconcile active markets
3. A Redis error on one market's `project!` call will abort all remaining markets; we need per-market rescue

- [ ] **Step 3.1: Write the failing tests**

```ruby
# test/jobs/hot_storage/reconcile_market_hot_state_job_test.rb
# Add after the existing test:

test "reconciles all open and settled markets when called with no market_id" do
  # open_market is status :open; draft_market is status :draft
  market = markets(:open_market)

  HotStorage::ReconcileMarketHotStateJob.perform_now(store: @store)

  hot_snapshot = @store.read_market_snapshot(market_id: market.id)
  assert_not_nil hot_snapshot, "open market should have been reconciled"
  assert_equal "open", hot_snapshot.fetch("status")
end

test "reconciles only the specified market when market_id is given" do
  open_market  = markets(:open_market)
  draft_market = markets(:draft_market)

  HotStorage::ReconcileMarketHotStateJob.perform_now(market_id: open_market.id, store: @store)

  assert_not_nil @store.read_market_snapshot(market_id: open_market.id)
  assert_nil     @store.read_market_snapshot(market_id: draft_market.id)
end

test "does not abort when one market projection raises a Redis error" do
  market = markets(:open_market)
  call_count = 0

  HotStorage::MarketSnapshotProjector.stub(:project!, ->(**) {
    call_count += 1
    raise StandardError, "Redis boom" if call_count == 1
    { market_id: market.id, version: 1 }
  }) do
    assert_nothing_raised do
      HotStorage::ReconcileMarketHotStateJob.perform_now(
        market_ids: [market.id, market.id],
        store: @store
      )
    end
  end

  assert_equal 2, call_count, "should have attempted both markets even after first error"
end
```

- [ ] **Step 3.2: Run tests to verify they fail**

```bash
bin/rails test test/jobs/hot_storage/reconcile_market_hot_state_job_test.rb -v
```
Expected: existing test passes; new tests FAIL (wrong arguments or no error isolation)

- [ ] **Step 3.3: Implement updated job**

```ruby
# app/jobs/hot_storage/reconcile_market_hot_state_job.rb
module HotStorage
  class ReconcileMarketHotStateJob < ApplicationJob
    queue_as :default

    def perform(market_id: nil, market_ids: nil, store: Store.current)
      scope = Market.includes(:market_legs, :bets)

      if market_id.present?
        scope = scope.where(id: market_id)
      elsif market_ids.present?
        scope = scope.where(id: market_ids)
      else
        scope = scope.where(status: [ :open, :settled ])
      end

      scope.find_each do |market|
        reconcile_market!(market: market, store: store)
      end
    end

    private

    def reconcile_market!(market:, store:)
      hot_snapshot = store.read_market_snapshot(market_id: market.id)
      hot_version  = hot_snapshot&.dig("version").to_i
      cold_version = MarketSnapshotProjector.market_version(market)

      return if hot_version == cold_version

      MarketSnapshotProjector.project!(market: market, reason: "reconcile", store: store)
    rescue StandardError => e
      Rails.logger.warn("ReconcileMarketHotStateJob: error on market #{market.id}: #{e.class}: #{e.message}")
    end
  end
end
```

- [ ] **Step 3.4: Run tests to verify they pass**

```bash
bin/rails test test/jobs/hot_storage/reconcile_market_hot_state_job_test.rb -v
```
Expected: 4 tests, 0 failures

- [ ] **Step 3.5: Commit**

```bash
git add app/jobs/hot_storage/reconcile_market_hot_state_job.rb \
        test/jobs/hot_storage/reconcile_market_hot_state_job_test.rb
git commit -m "$(cat <<'EOF'
feat(hot-storage): complete ReconcileMarketHotStateJob with single-market form and per-market error isolation

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: SSE endpoint — snapshot-first, cold fallback, clean event shape

**Files:**
- Modify: `app/controllers/sse/markets_controller.rb`
- Test: `test/integration/hot_sse_markets_test.rb`

The current SSE controller emits three events per connect: `market.snapshot.v1`, `market.settlement_changed.v1`, and `market.bet_voided.v1`. The spec says the endpoint should emit the hot snapshot as the **first event** then stream subsequent events as they arrive (live streaming is out of scope, so for now: one initial snapshot event only). The two extra synthetic events should be removed — they duplicate data already in the snapshot and violate the contract.

The controller also has no handling for the case where `MarketSnapshotReader.call` raises (e.g., market not found) or when Redis is down. Since `MarketSnapshotReader.call` now handles Redis errors internally (Task 2), the only remaining gap is the Redis-nil path test.

- [ ] **Step 4.1: Write the failing test**

```ruby
# test/integration/hot_sse_markets_test.rb
# Add after the existing test:

test "market sse endpoint falls back to cold snapshot when Redis has no snapshot" do
  market = markets(:open_market)
  # FakeRedis starts empty — no snapshot written

  get "/sse/markets/#{market.id}"

  assert_response :success
  assert_equal "text/event-stream", response.media_type
  assert_match "event: market.snapshot.v1", response.body
  assert_match "\"market_id\":#{market.id}", response.body
  assert_match "\"status\":\"open\"", response.body
  # Should NOT emit the two extra synthetic events
  assert_no_match "event: market.settlement_changed.v1", response.body
  assert_no_match "event: market.bet_voided.v1", response.body
end

test "market sse endpoint emits only the snapshot event (no synthetic extras)" do
  market = markets(:open_market)
  HotStorage::Store.current.write_market_snapshot!(
    market_id: market.id,
    snapshot: {
      market_id: market.id,
      status: "open",
      settled_outcome: nil,
      total_open_interest_minor: 100,
      updated_at: Time.current.iso8601,
      legs: []
    },
    version: 42
  )

  get "/sse/markets/#{market.id}"

  assert_response :success
  body_events = response.body.scan(/^event: .*/).map { |l| l.sub("event: ", "") }
  assert_equal [ "market.snapshot.v1" ], body_events
end
```

- [ ] **Step 4.2: Run tests to verify they fail**

```bash
bin/rails test test/integration/hot_sse_markets_test.rb -v
```
Expected: existing test passes; new tests FAIL (body contains extra events)

- [ ] **Step 4.3: Implement updated SSE controller**

```ruby
# app/controllers/sse/markets_controller.rb
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
```

- [ ] **Step 4.4: Run tests to verify they pass**

```bash
bin/rails test test/integration/hot_sse_markets_test.rb -v
```
Expected: 3 tests, 0 failures

- [ ] **Step 4.5: Run full suite to confirm no regressions**

```bash
bin/rails test
```
Expected: all tests pass, coverage >= 90%

- [ ] **Step 4.6: Commit**

```bash
git add app/controllers/sse/markets_controller.rb \
        test/integration/hot_sse_markets_test.rb
git commit -m "$(cat <<'EOF'
feat(hot-storage): update SSE endpoint to emit snapshot-first with cold fallback

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update docs

- [ ] Append entry to `docs/WORK_LOG.md` — describe what was built, list key files, include commit refs
- [ ] Update `docs/INDEX.md` — move "PLAN-C Hot/cold storage finalisation" from ⏳ Next to ✅ Done, update the Done list to reflect the new state
- [ ] Update `docs/plans/ITERATION_005_MASTER_TODO_TREE.md` — mark PLAN-C tasks done if tracked there
- [ ] Commit:

```bash
git add docs/WORK_LOG.md docs/INDEX.md
git commit -m "$(cat <<'EOF'
docs: update INDEX and WORK_LOG after hot-cold-storage

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist
- [ ] Every spec invariant has a test
- [ ] Every write action has an AuditEvent (N/A — hot storage is not audited; no ledger writes)
- [ ] Every ledger write has correct entry_type and direction (N/A)
- [ ] Full test suite passes: `bin/rails test`
- [ ] No placeholder steps remain
