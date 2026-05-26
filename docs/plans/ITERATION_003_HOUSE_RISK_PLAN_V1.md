<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 003 Plan V1 - House Exposure and Margin Model

## Goal
Add a first production-style risk model for prediction markets in the monolith.

## Chosen Model
- Mechanism: fixed-odds with bounded house liability.
- Revenue sources: overround and optional per-bet fee.
- Cold start: house posts initial outcomes and accepts first bet if liability caps remain safe.

## Scope V1
1. Add market risk configuration fields.
2. Introduce bet placement flow with wallet debit and ledger/audit trail.
3. Add risk calculator service (PnL by outcome, worst-case liability).
4. Add admin risk endpoint for each market.
5. Add tests for placement rules and liability caps.

## Out of Scope
- full settlement payout engine rewrite
- dynamic quote engine
- CLOB/LMSR execution engines

## Acceptance
- placing a bet rejected when post-trade liability exceeds cap
- admin can inspect current worst-case liability
- tests and coverage remain above target
