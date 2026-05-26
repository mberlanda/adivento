# ADR-0012: Hot/Cold Storage with Redis Projections

## Status
Proposed

## Context
Price volatility and frequent updates require low-latency reads while preserving durable financial correctness.

## Decision
Use PostgreSQL as system of record and Redis for hot snapshots and stream fanout. SSE reads hot-first with cold fallback and reconciliation jobs.

## Consequences
- Maintains correctness while improving latency.
- Introduces eventual consistency and operational complexity.
- Requires reconciliation and monitoring for hot/cold drift.
