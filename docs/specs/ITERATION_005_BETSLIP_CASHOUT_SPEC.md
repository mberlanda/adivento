<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 005 Spec: Betslip and Cashout

## Betslip
- Supports multi-item placement across distinct markets.
- Quote then execute flow with idempotency key.
- Execution semantics:
  - MVP: all-or-nothing
  - future: partial with explicit item statuses

## Cashout
- Cashout quote produced from current line probabilities.
- Execution settles or partially closes active positions.
- House and peer-liquidity strategies are isolated behind pricing interfaces.

## Required Contracts
- POST /betslips/quotes
- POST /betslips/execute
- GET /betslips/executions/:id
- GET /positions
- POST /positions/cashout_quotes
- POST /positions/cashout_execute

## Accounting
- Every execution produces ledger and audit references.
- Cashout must record realized pnl and fee metadata.

## Test Requirements
- Quote expiry handling.
- Idempotency key replay with same payload.
- Idempotency key conflict with changed payload.
- Wallet/ledger consistency on retries.
