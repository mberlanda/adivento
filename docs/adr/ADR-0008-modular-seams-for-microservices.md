# ADR-0008: Modular Monolith Seams for Future Microservices

## Status
Accepted

## Context
The monolith must remain easy to decompose later without major rewrites.

## Decision
Enforce service boundaries by context, explicit event contracts, and web read composition rules that avoid cross-context write coupling.

## Consequences
- Short-term developer discipline cost.
- Lower long-term extraction cost and reduced migration risk.
