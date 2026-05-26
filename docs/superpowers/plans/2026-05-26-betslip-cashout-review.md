# Plan Review: Betslip + Cashout

<!-- File location: docs/superpowers/plans/2026-05-26-betslip-cashout-review.md -->

## Plan reviewed: [2026-05-26-betslip-cashout.md](2026-05-26-betslip-cashout.md)
## Spec reviewed: [docs/specs/2026-05-26-betslip-cashout.md](../../specs/2026-05-26-betslip-cashout.md)

## Findings

### Coverage gaps
- [x] Quote TTL expiry → Tasks 3+4, integration test step 6 ✅
- [x] Idempotency replay (same key + same payload = return existing) → Task 3, integration test ✅
- [x] Idempotency conflict (same key + different payload = 409) → Task 3, integration test ✅
- [x] All-or-nothing execution (closed market → full rollback) → Task 4 test ✅
- [x] Single-use quote → Task 4 (`AlreadyExecuted` guard) ✅
- [x] Cashout credits net payout, deducts fee → Task 5, service test ✅
- [x] Zero-fee case skips fee ledger entry → Task 5 test ✅
- [x] LedgerEntry and AuditEvent written per operation → Tasks 4+5 ✅
- [x] Positions index → Task 6 controller + integration test ✅
- [x] Execution show 404 for another user's execution → integration test ✅

### Placeholder scan
- [x] Clean — all code blocks are complete Ruby, no TODOs or "implement later"

### Type/signature consistency
- [x] `BetslipQuoteService.call` used in Task 4 test setup matches Task 3 definition ✅
- [x] `BetslipExecutionService.execute!` signature `(quote:, actor:)` consistent ✅
- [x] `CashoutQuoteService.quote(bet:)` and `CashoutExecutionService.execute!(bet:, actor:)` consistent across Task 5 and Task 6 controller ✅
- [x] `BetPlacementService.place!` — implementer must verify signature from actual file before using ⚠️
- [x] `BetslipExecution` `bet_ids` stored as jsonb array — `execution.bet_ids` returns array as expected ✅

### Risk flags
- [x] `BetPlacementService::InvalidBet` and `::RiskLimitExceeded` — plan assumes these exception class names; implementer must verify against actual service before Task 4 ⚠️
- [x] `Web::BaseController` is assumed to exist with `current_user` — verify the `web/` namespace base controller pattern ⚠️
- [x] `require_player!` renders JSON 401 — if `web/BaseController` redirects instead of rendering, the integration tests will fail; verify session auth behaviour ⚠️
- [x] `items_param` in `BetslipsController` handles both nested hash and array formats from `as: :json` tests — looks correct but worth verifying with the actual test params ✅
- [x] Race condition in `BetslipQuoteService`: `RecordNotUnique` rescue handles concurrent insert of same idempotency_key ✅

## Decision
**Approved with caution** — proceed to execution, but implementer must verify:
1. `BetPlacementService` exception class names and `.place!` signature
2. `Web::BaseController` auth pattern (redirect vs. JSON 401)

## Required changes before execution
None (risks are verification items, not plan errors). Implementer reads the relevant files in the first step of each task.
