# Iteration 005 Spec: Hot/Cold Storage

## Objective
Use PostgreSQL as durable source of truth and Redis for volatile market snapshots and event streams.

## Contracts
- Hot snapshot key per market.
- Stream channel per market for update fanout.
- SSE endpoint consumes hot snapshot first, cold fallback second.

## Guarantees
- Cold writes are authoritative.
- Hot projection is eventually consistent.
- Reconciliation job repairs drift.

## Failure Handling
- Redis unavailable: cold path still succeeds.
- Hot cache miss: rebuild from cold on read.
- Out-of-order events: version check in consumers.

## Test Requirements
- Snapshot projection and read fallback.
- Reconciliation repair path.
- SSE payload consistency in hot and cold modes.
