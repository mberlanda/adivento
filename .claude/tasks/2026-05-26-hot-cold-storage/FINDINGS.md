# Findings

## 2026-05-26 — Plan written, review approved with cautions

Read actual source files before modifying:
- `HotStorage::Store` — verify `Store.new(redis:)` constructor and `write_market_snapshot!` / `read_market_snapshot` signatures
- `Sse::MarketsController` — if it uses `ActionController::Live`, the plan's `render plain:` approach will differ; adapt accordingly
- Check `test/support/` for existing `ErrorRedis` before redeclaring inline

## 2026-05-26 — Implementation complete

All 5 tasks implemented. Key adaptations:
- `MarketSnapshotProjector` hardened with `rescue StandardError` around individual store calls
- `MarketSnapshotReader` adds cold fallback (DB re-derive) when Redis raises at read time
- `ReconcileMarketHotStateJob` uses `market_id:` singular kwarg form; scoped to `where(status: [:open, :settled])`
- SSE controller emits only `market.snapshot.v1` event; cold fallback via reader on Redis nil
- `ErrorRedis` declared inline in each test file (no collision with test/support/)
