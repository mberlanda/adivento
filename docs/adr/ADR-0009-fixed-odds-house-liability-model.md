# ADR-0009: Fixed-Odds Bounded House Liability Model

## Status
Accepted

## Context
The platform needs immediate market tradability with limited dependency overhead and explicit risk controls.

## Decision
Use fixed-odds house underwriting with per-market liability caps and fee capture at bet entry.

Key formula:
- compute PnL per outcome and enforce post-trade worst-case liability cap.

## Consequences
- immediate liquidity for first orders
- deterministic risk rejection path for oversized bets
- clear migration path to hybrid CLOB/AMM later while preserving ledger and audit primitives
