# Iteration 005 Master Todo Tree

Status: TODO · IN_PROGRESS · DONE · BLOCKED

## Dependency Graph
- PLAN-A Binary Market Lines and Settlement Invariants — depends on: none
- PLAN-B Betslip and Cashout — depends on: PLAN-A
- PLAN-C Hot/Cold Storage and SSE — depends on: PLAN-A
- PLAN-D UI End-to-End — depends on: PLAN-A (partial)

## Plan Status
- PLAN-A: DONE (settlement engine complete 2026-05-26)
- PLAN-B: TODO
- PLAN-C: TODO
- PLAN-D: BLOCKED (Docker overlay2)

## Work Tree

### PLAN-A Binary Market Lines and Settlement [DONE]
- A1.1 Create plan v1 [DONE]
- A1.2 Plan review [DONE]
- A1.3 Create spec [DONE]
- A1.4 Spec review [DONE]
- A1.5 DB invariants for bet→market_leg→market consistency [TODO - deferred]
- A1.6 Settlement engine — bet status transitions + payout ledger [DONE 2026-05-26]
- A1.7 Enforce binary line taxonomy at market/line creation [TODO - deferred]
- A1.8 Integration + model + service tests [DONE]
- A1.9 Full suite pass [DONE]

Deferred: A1.5 and A1.7 (binary invariants) moved to follow-up; unblocks PLAN-B.

### PLAN-B Betslip and Cashout [TODO]
- B1.1–B1.4 Planning [DONE]
- B1.5 MVP quote and execute endpoints [TODO]
- B1.6 Position projection model [TODO]
- B1.7 Cashout quote/execute model [TODO]
- B1.8 Idempotency and ledger postings [TODO]
- B1.9 Tests + full suite [TODO]

Spec: [ITERATION_005_BETSLIP_CASHOUT_SPEC.md](../specs/ITERATION_005_BETSLIP_CASHOUT_SPEC.md)
Plan: [ITERATION_005_BETSLIP_CASHOUT_ARCHITECTURE_PLAN_V1.md](ITERATION_005_BETSLIP_CASHOUT_ARCHITECTURE_PLAN_V1.md)

### PLAN-C Hot/Cold Storage [TODO]
- C1.1–C1.4 Planning [DONE]
- C1.5 Redis hot snapshot projection for volatile markets [TODO]
- C1.6 Stream and SSE fanout path [TODO]
- C1.7 Reconciliation job [TODO]
- C1.8 Failure-mode and fallback tests [TODO]
- C1.9 Full suite and close plan [TODO]

Spec: [ITERATION_005_HOT_COLD_STORAGE_SPEC.md](../specs/ITERATION_005_HOT_COLD_STORAGE_SPEC.md)
Plan: [ITERATION_005_HOT_COLD_STORAGE_ARCHITECTURE_V1.md](ITERATION_005_HOT_COLD_STORAGE_ARCHITECTURE_V1.md)

### PLAN-D UI End-to-End [BLOCKED]
- D1.1–D1.7 [DONE]
- D1.8 Wire CI/stage execution docs [IN_PROGRESS]
- D1.9 Execute UI suite against running app [BLOCKED]

Blocker: Docker engine filesystem read-only during overlay2 rebuild.
Resume: `docker compose up -d db web && bin/rails db:prepare && bin/rails db:seed` then `docker compose -f docker-compose.yml -f e2e/playwright/docker-compose.e2e.yml run --build --rm ui-tests`

## Next Step
Start PLAN-B. Write implementation plan using `superpowers:writing-plans` skill.
Save to: `docs/superpowers/plans/YYYY-MM-DD-betslip-cashout.md`
