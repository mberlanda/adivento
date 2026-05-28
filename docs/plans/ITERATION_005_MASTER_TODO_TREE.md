# Iteration 005 Master Todo Tree

<!-- LEGACY FORMAT — audit artifact only. Do NOT add new work here.
   Current backlog: docs/wiki/tech-debt-backlog.md
   Current status:  docs/INDEX.md -->

Status: TODO · IN_PROGRESS · DONE · BLOCKED

## Plan Status (all complete as of 2026-05-28)
- PLAN-A: DONE (settlement engine complete 2026-05-26)
- PLAN-B: DONE (betslip + cashout, PR #3 `c686641`)
- PLAN-C: DONE (hot/cold storage + SSE, PR #4)
- PLAN-D: DONE (full E2E suite, PRs #23, #25, #26)

## Work Tree

### PLAN-A Binary Market Lines and Settlement [DONE]
- A1.1 Create plan v1 [DONE]
- A1.2 Plan review [DONE]
- A1.3 Create spec [DONE]
- A1.4 Spec review [DONE]
- A1.5 DB invariants for bet→market_leg→market consistency [DONE — DB trigger, PR #2]
- A1.6 Settlement engine — bet status transitions + payout ledger [DONE 2026-05-26]
- A1.7 Enforce binary line taxonomy at market/line creation [DONE — PR #2]
- A1.8 Integration + model + service tests [DONE]
- A1.9 Full suite pass [DONE]

### PLAN-B Betslip and Cashout [DONE]
- B1.1–B1.4 Planning [DONE]
- B1.5 MVP quote and execute endpoints [DONE]
- B1.6 Position projection model [DONE]
- B1.7 Cashout quote/execute model [DONE]
- B1.8 Idempotency and ledger postings [DONE]
- B1.9 Tests + full suite [DONE]

### PLAN-C Hot/Cold Storage [DONE]
- C1.1–C1.4 Planning [DONE]
- C1.5 Redis hot snapshot projection [DONE]
- C1.6 Stream and SSE fanout path [DONE]
- C1.7 Reconciliation job [DONE]
- C1.8 Failure-mode and fallback tests [DONE]
- C1.9 Full suite [DONE]

### PLAN-D UI End-to-End [DONE]
- D1.1–D1.9 [DONE — Docker overlay2 blocker resolved via docker-compose.e2e.yml overlay]
- Full suite: 84 Playwright tests, all passing in production mode (PR #26)
- Multi-player settlement coverage: 16 tests (PR #25)
