# Plan: Hot/Cold Storage Finalization

> Resume from first unchecked step. Read FINDINGS.md for decisions made so far.

- [ ] Task 1: MarketSnapshotProjector — Redis error resilience (rescue StandardError, return snapshot)
- [ ] Task 2: MarketSnapshotReader — cold fallback on Redis error (inline cold derivation without Redis write)
- [ ] Task 3: ReconcileMarketHotStateJob — single-market form, open/settled scope, per-market error isolation
- [ ] Task 4: SSE endpoint — snapshot-first, no synthetic extra events, cold fallback via reader
- [ ] Task 5: Update docs (WORK_LOG + INDEX)
