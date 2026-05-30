# Spec: Market Price History (D6)

<!-- Decision D6-TODO-005. Recommended option: expose existing PriceSnapshot with a web endpoint + simple chart now. -->

## Goal
A customer viewing a market detail page can see how the market's price/probability has moved over time, rendered as a simple line chart backed by the existing `PriceSnapshot` data.

## Definitions
- **PriceSnapshot**: existing model (`app/models/price_snapshot.rb`) storing `market_id`, `mechanism_type`, `snapshot_data` (json), `recorded_at`. One row = the market's price state at a point in time.
- **Series point**: a normalized `{ t: <iso8601>, yes: <0..100 float> }` pair derived from a snapshot, where `yes` is the YES-side probability/price expressed as a percentage. This is the single value the chart plots, regardless of mechanism.

## Background / current state
- `PriceSnapshotRecorder.record(market)` and `RecordPriceSnapshotJob` exist but are **never enqueued anywhere in production code** (verified: only referenced by their own files + unit test). Therefore no snapshots are currently being written. This spec must wire recording into market-mutating events, otherwise the chart has no data.
- There is no `/web/markets/:id/price_history` endpoint and no chart in `app/views/web/markets/show.html.erb`.

## Normalization rule (snapshot_data → `yes` percentage)
The chart plots one YES-side percentage per snapshot. Derive it per mechanism from `snapshot_data`:
- **fixed_odds**: `legs` array; `yes = (YES leg odds_minor) / 100.0` (odds_minor is basis points of probability; 5000 → 50.0).
- **clob**: `{ bid:, ask: }` in cents; `yes = bid` when present, else `100 - ask` when present, else `null` (skip point).
- **lmsr**: `{ yes_probability:, no_probability: }`; `yes = yes_probability`.
- **parimutuel**: `{ yes_probability:, ... }`; `yes = yes_probability`.
Points whose `yes` resolves to `null` are omitted from the series.

## Invariants
1. The endpoint returns snapshots only for the requested market, ordered by `recorded_at` ascending.
2. The endpoint never returns more than `limit` points (default 500, max 1000); when capped it returns the most recent `limit` points.
3. A market with zero snapshots returns an empty `points` array and HTTP 200 (not an error).
4. Recording a snapshot never raises into or rolls back the triggering trade/bet/settlement transaction (recording happens after commit, best-effort).
5. Snapshots are recorded only for `open` markets (existing `RecordPriceSnapshotJob` guard).

## API / UI Contract
**JSON endpoint** — `GET /web/markets/:market_id/price_history(.json)`
- Auth: same as other `/web/markets` reads (public/optional current_user).
- Query params: `limit` (optional integer, default 500, clamped 1..1000).
- Response 200:
```json
{
  "market_id": 12,
  "mechanism_type": "clob",
  "points": [
    { "t": "2026-05-30T10:00:00Z", "yes": 41.0 },
    { "t": "2026-05-30T10:05:00Z", "yes": 43.0 }
  ]
}
```

**Chart (market detail page)** — `app/views/web/markets/show.html.erb`
- A `<section data-testid="price-history">` containing an inline `<svg>` line chart (no npm/JS chart library) rendered server-side from the same series, OR a tiny inline `<script>` that fetches the JSON endpoint and draws an SVG polyline. Chosen approach: **server-side SVG** (no client JS dependency, matches the codebase's no-build-step style).
- Empty state: when there are <2 points, render "Not enough price history yet" instead of a chart.

## Status Taxonomy
None (no new enums).

## Accounting / Ledger
None (read-only feature; no ledger or wallet writes).

## Test Requirements
- [ ] `PriceHistoryController#index` returns ascending points for a market with snapshots.
- [ ] Returns empty `points` + 200 for a market with no snapshots.
- [ ] Respects `limit` (returns most recent N when capped).
- [ ] Normalization: each mechanism's `snapshot_data` maps to the correct `yes` percentage; unresolvable points are skipped.
- [ ] A snapshot is recorded after an order fill / LMSR trade / parimutuel stake / fixed-odds bet on an open market (recording is wired).
- [ ] Recording failure does not roll back or raise into the trade transaction.
- [ ] Market detail view renders the chart section when ≥2 points exist, and the empty state otherwise.

## Out of scope
- Retention / pruning / downsampling of `price_snapshots` (tracked separately as a follow-up — see TD-035 in the plan; the table can grow unbounded until then).
- Time-range selector (1H/6H/1D/1W/ALL), volume overlay, candlesticks, holders/liquidity stats (future UX-005/UX-009).
- jsonb migration of `snapshot_data` (tracked under TD-024).
- Real-time chart updates over SSE.
