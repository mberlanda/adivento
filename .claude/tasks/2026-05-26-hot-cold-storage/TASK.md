# Task: Hot/Cold Storage Finalization

Complete the hot/cold storage layer: harden `MarketSnapshotProjector` and `MarketSnapshotReader` against Redis runtime errors, complete `ReconcileMarketHotStateJob` with single-market form and per-market error isolation, and update the SSE endpoint to emit a single clean snapshot event with a cold fallback path. PostgreSQL remains authoritative; Redis is eventually consistent and failure-tolerant.

Spec: `docs/specs/2026-05-26-hot-cold-storage.md`
Plan: `docs/superpowers/plans/2026-05-26-hot-cold-storage.md`
