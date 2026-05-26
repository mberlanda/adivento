# Plan: Hot/Cold Storage Finalization

> Resume from first unchecked step. Read FINDINGS.md for decisions made so far.

- [x] Task 1: MarketSnapshotProjector — Redis error resilience (rescue StandardError, return snapshot)
- [x] Task 2: MarketSnapshotReader — cold fallback on Redis error (inline cold derivation without Redis write)
- [x] Task 3: ReconcileMarketHotStateJob — single-market form, open/settled scope, per-market error isolation
- [x] Task 4: SSE endpoint — snapshot-first, no synthetic extra events, cold fallback via reader
- [x] Task 5: Update docs (WORK_LOG + INDEX)
