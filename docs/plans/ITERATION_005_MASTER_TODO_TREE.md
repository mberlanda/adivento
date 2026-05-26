# Iteration 005 Master Todo Tree

Status Legend:
- TODO
- IN_PROGRESS
- DONE
- BLOCKED

## Dependency Graph
- PLAN-A Binary Market Lines and Settlement Invariants
  - depends on: none
  - unlocks: PLAN-B, PLAN-C
- PLAN-B Betslip and Cashout
  - depends on: PLAN-A
- PLAN-C Hot/Cold Storage and SSE Volatility Path
  - depends on: PLAN-A
- PLAN-D UI End-to-End Automation
  - depends on: PLAN-A (partial), can start scaffolding immediately

## Plan Status
- PLAN-A: IN_PROGRESS
- PLAN-B: TODO
- PLAN-C: TODO
- PLAN-D: IN_PROGRESS

## Work Tree
1. PLAN-A Binary Market Lines and Settlement Invariants [IN_PROGRESS]
- A1.1 Create plan v1 [DONE]
- A1.2 Plan review [DONE]
- A1.3 Create spec [DONE]
- A1.4 Spec review [DONE]
- A1.5 Add DB invariants for bet->market_leg->market consistency [TODO]
- A1.6 Add settlement engine for bet status transitions and payout ledger [TODO]
- A1.7 Enforce binary line taxonomy at market/line creation [TODO]
- A1.8 Add integration + model + service tests [IN_PROGRESS]
- A1.9 Run full suite and close plan [IN_PROGRESS]

2. PLAN-B Betslip and Cashout [TODO]
- B1.1 Create plan v1 [DONE]
- B1.2 Plan review [TODO]
- B1.3 Create spec [DONE]
- B1.4 Spec review [DONE]
- B1.5 MVP quote and execute endpoints [TODO]
- B1.6 Position projection model [TODO]
- B1.7 Cashout quote/execute model [TODO]
- B1.8 Idempotency and ledger postings [TODO]
- B1.9 Tests + full suite [TODO]

3. PLAN-C Hot/Cold Storage [TODO]
- C1.1 Create plan v1 [DONE]
- C1.2 Plan review [TODO]
- C1.3 Create spec [DONE]
- C1.4 Spec review [DONE]
- C1.5 Redis hot snapshot projection for volatile markets [TODO]
- C1.6 Stream and SSE fanout path [TODO]
- C1.7 Reconciliation job [TODO]
- C1.8 Failure-mode tests and fallback tests [TODO]
- C1.9 Full suite and close plan [TODO]

4. PLAN-D UI End-to-End Automation [IN_PROGRESS]
- D1.1 Create plan v1 [DONE]
- D1.2 Create spec [DONE]
- D1.3 Spec review [DONE]
- D1.4 Add test-id hooks to UI components [DONE]
- D1.5 Add Playwright config and scripts [DONE]
- D1.6 Add core scenarios (create market, win/loss settlement) [DONE]
- D1.7 Add voided scenario placeholder test [DONE]
- D1.8 Wire CI/stage execution docs [IN_PROGRESS]
- D1.9 Execute UI suite against running app [BLOCKED]

Blocker notes:
- Local Docker engine filesystem became read-only while rebuilding/running UI test container.
- Failing operation: `docker compose down -v` / overlay2 unlink on container rootfs.
- Next resume step after Docker recovery: `docker compose up -d db web && docker compose exec -T web bin/rails db:prepare && docker compose exec -T web bin/rails db:seed && docker compose -f docker-compose.yml -f e2e/playwright/docker-compose.e2e.yml run --build --rm ui-tests`.

## Current Session Progress
- Fixed action contract runtime lookup issue and added top-level constant lookup.
- Added integration coverage for missing app endpoints with meaningful assertions.
- Expanded auth and bet endpoint integration assertions for action contract and side effects.
- Added Playwright UI automation scaffolding and test-id contracts.

## Resume Instructions
1. Finish PLAN-A implementation tasks A1.5-A1.9 first.
2. Start PLAN-B once PLAN-A is DONE.
3. Start PLAN-C in parallel with PLAN-B after PLAN-A is DONE.
