# Spec: Hot/Cold Storage Finalization

<!-- File location: docs/specs/2026-05-26-hot-cold-storage.md -->
<!-- Written BEFORE the implementation plan. Describes WHAT, not HOW. -->

## Goal

Complete the hot/cold storage layer so that Redis snapshots are authoritative for SSE reads, the reconciliation job repairs drift, and the SSE stream fans out live events to connected clients.

## Definitions

- **Hot snapshot**: Redis hash keyed `adivento:hot:v1:market:{market_id}:snapshot` — serialized market state for fast SSE reads; eventually consistent with cold
- **Cold source**: PostgreSQL — always authoritative; hot is always rebuilt from cold, never the reverse
- **Event stream**: Redis stream keyed `adivento:hot:v1:market:{market_id}:events` — ordered list of domain events appended via `xadd`
- **Reconciliation**: periodic process that rebuilds hot snapshots from cold DB for any market where hot version differs from cold version
- **SSE fanout**: emitting a serialized market snapshot or domain event to all SSE clients currently connected to a market endpoint
- **NullRedis**: in-process stub used when Redis is unavailable; all writes are no-ops, all reads return nil

## Invariants

1. A cold DB write always succeeds even if Redis is unavailable — Redis failures MUST NOT raise in any caller's happy path
2. Hot snapshot miss → rebuild from cold on read via `MarketSnapshotProjector.project!`, then return the result; never return an error to the client due to missing hot state
3. Redis error on read → derive snapshot from cold DB inline and return it; do NOT attempt a Redis write in the error path
4. Out-of-order events: consumers check the `version` field (epoch-milliseconds of `market.updated_at`) and ignore events with a version lower than the last seen version
5. `ReconcileMarketHotStateJob` reconciles all open/settled markets when called with no `market_id`, or a single market when `market_id` is provided; a Redis failure on one market MUST NOT abort reconciliation of remaining markets
6. SSE endpoint emits the current hot snapshot (or cold-derived fallback) as the first `market.snapshot.v1` event immediately on connect
7. All `MarketSnapshotProjector.project!` calls are idempotent — calling twice with the same market state produces the same snapshot key and the same event appended to the stream

## API / UI Contract

### SSE endpoint

`GET /sse/markets/:id`

- No auth required (existing behavior)
- Response: `Content-Type: text/event-stream`, `Cache-Control: no-cache`
- On connect: reads snapshot via `HotStorage::MarketSnapshotReader.call(market_id:)` and emits one `market.snapshot.v1` event with the snapshot payload (excluding the `version` field from the data body, using it as the SSE `id:` line)
- On Redis error during read: derives snapshot from cold DB without writing to Redis, emits `market.snapshot.v1` with cold-derived data, then closes the stream gracefully
- Subsequent live events: emitted as they arrive via Redis pub/sub (future; not in scope for this finalization)

### ReconcileMarketHotStateJob

`HotStorage::ReconcileMarketHotStateJob.perform_later(market_id: <id>)` — reconcile one market
`HotStorage::ReconcileMarketHotStateJob.perform_later` — reconcile all open/settled markets

- `perform(market_id: nil)`: if `market_id` is given, reconcile that market only; if nil, iterate `Market.where(status: [:open, :settled]).find_each`
- Reconciliation means: compare hot snapshot version to cold version; if they differ (or hot is missing), call `MarketSnapshotProjector.project!(market:, reason: "reconcile")`

### No new HTTP endpoints

This spec covers infrastructure completion only. No new routes are added.

## Test Requirements

- [ ] `MarketSnapshotProjector.project!` writes the correct JSON shape to Redis (market_id, status, question, settled_outcome, legs array, updated_at, version)
- [ ] `MarketSnapshotProjector.project!` does NOT raise when the store raises a `Redis::BaseError` (or equivalent)
- [ ] `MarketSnapshotReader.call` returns hot snapshot when Redis has one
- [ ] `MarketSnapshotReader.call` rebuilds from cold and returns when hot is missing (nil from Redis)
- [ ] `MarketSnapshotReader.call` returns cold-derived snapshot and does NOT raise when Redis raises an error
- [ ] `ReconcileMarketHotStateJob` projects every open/settled market when called with no `market_id`
- [ ] `ReconcileMarketHotStateJob` projects only the specified market when called with a `market_id`
- [ ] `ReconcileMarketHotStateJob` does NOT abort when a single market's projection raises a Redis error
- [ ] `ReconcileMarketHotStateJob` skips markets whose hot version already matches cold version
- [ ] SSE endpoint emits a `market.snapshot.v1` event as the first line of the response body
- [ ] SSE endpoint uses hot snapshot data when Redis has a snapshot
- [ ] SSE endpoint falls back to cold-derived snapshot when Redis returns nil

## Out of scope

- Multi-region Redis replication
- Per-user SSE filtering
- Event replay for late-joining clients beyond the current session
- ActionController::Live streaming (polling-based fanout is sufficient for now)
- Redis pub/sub for real-time push to connected clients
