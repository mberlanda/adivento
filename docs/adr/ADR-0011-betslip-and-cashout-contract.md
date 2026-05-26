# ADR-0011: Betslip and Cashout Contract

## Status
Proposed

## Context
Users need multi-market slips and optional early exit via cashout with deterministic accounting and idempotent APIs.

## Decision
Adopt quote-then-execute contracts for betslips and cashout, with strict idempotency keys and ledger/audit references for each execution.

## Consequences
- Strong retry safety and predictable wallet transitions.
- Enables phased progression from house quotes to peer liquidity.
- Adds execution lifecycle complexity requiring dedicated tests.
