# Plan Review: Hot/Cold Storage Finalization

<!-- File location: docs/superpowers/plans/2026-05-26-hot-cold-storage-review.md -->

## Plan reviewed: [2026-05-26-hot-cold-storage.md](2026-05-26-hot-cold-storage.md)
## Spec reviewed: [docs/specs/2026-05-26-hot-cold-storage.md](../../specs/2026-05-26-hot-cold-storage.md)

## Findings

### Coverage gaps
- [x] `project!` resilience (Redis error does not raise) → Task 1 ✅
- [x] `read` cold fallback on miss → already in reader's existing cold-rebuild path (confirmed by plan's current-state audit) ✅
- [x] `read` cold fallback on Redis error mid-call → Task 2 ✅
- [x] Reconciliation job: all-markets form, single-market form, per-market error isolation → Task 3 ✅
- [x] SSE endpoint emits snapshot-first, no extra synthetic events, Redis-nil fallback → Task 4 ✅
- [x] Version field in snapshot → included in `build_snapshot` return (`merge(version:)`) ✅

### Placeholder scan
- [x] Clean — all code blocks are complete Ruby with real implementations

### Type/signature consistency
- [x] `MarketSnapshotProjector.project!(market:, reason:, store:)` — plan adds `store:` kwarg; implementer must ensure existing call sites (`MarketsController`, `SettlementService`, etc.) still work with default `store: Store.current` ⚠️
- [x] `MarketSnapshotProjector.build_snapshot` and `.market_version` promoted to public class methods in Task 1 — Task 2 reader uses them directly; consistent ✅
- [x] `ReconcileMarketHotStateJob#perform(market_id: nil, market_ids: nil, store: Store.current)` — consistent with Task 3 tests ✅
- [x] `Store.new(redis: ErrorRedis.new)` used in tests — verify `Store.new` accepts a `redis:` kwarg (may be `Store.current` factory only); plan assumes this is possible ⚠️

### Risk flags
- [x] SSE controller rewrite removes the `ActionController::Live` streaming infrastructure — if the existing controller uses `response.stream`, the plan's `render plain:` replacement will differ significantly; implementer must read the actual file first ⚠️
- [x] `snapshot.except(:version)` in SSE controller — `except` on a Hash works in Ruby 3.0+; verify Hash vs. Symbol key consistency in snapshot ✅
- [x] `ErrorRedis` class is declared inline in two test files — if test helper already defines it, there will be a constant redefinition warning; implementer should check `test/support/` ✅

## Decision
**Approved with caution** — proceed to execution. Implementer must read the actual source files for `HotStorage::Store`, `MarketSnapshotProjector`, `MarketSnapshotReader`, and `Sse::MarketsController` before modifying them, since the plan's current-state audit may have minor inaccuracies about the existing interface.

## Required changes before execution
None. Risks are read-before-write items, not plan errors.
