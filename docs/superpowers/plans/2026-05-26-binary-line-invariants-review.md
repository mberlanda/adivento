# Plan Review: Binary Line Invariants

<!-- File location: docs/superpowers/plans/2026-05-26-binary-line-invariants-review.md -->

## Plan reviewed: [2026-05-26-binary-line-invariants.md](2026-05-26-binary-line-invariants.md)
## Spec reviewed: [docs/specs/2026-05-26-binary-line-invariants.md](../../specs/2026-05-26-binary-line-invariants.md)

## Findings

### Coverage gaps
- [x] Spec requires: cannot add 3rd leg via `Admin::MarketLegsController` → Task 4 ✅
- [x] Spec requires: `MarketLeg` count validation → Task 1 ✅
- [x] Spec requires: `Market` open-transition guard (0, 1, 2 leg cases) → Task 2 ✅
- [x] Spec requires: DB-level trigger test → Task 3 ✅
- [x] Spec requires: label uniqueness already enforced — noted, no action needed ✅
- [x] Spec out-of-scope items correctly excluded (no canonical OPTION_1/2, no settled market changes) ✅

### Placeholder scan
- [x] Clean — all steps have real code, no TODOs or "similar to Task N"

### Type/signature consistency
- [x] `market_leg_count_within_limit` validation method is consistent in both model and test
- [x] `requires_two_legs_to_open` consistent between plan text and implementation code
- [x] `FaucetRequest.pending.find` pattern from admin controller correctly replicated
- Note: Step 4.3 says "Read `app/controllers/admin/market_legs_controller.rb` first" and then gives a simplified version — the actual controller may have different structure; implementer must read and integrate, not replace wholesale.

### Risk flags
- [x] PostgreSQL trigger uses a raw count subquery — correct for INSERT trigger; UPDATE on `market_id` is edge-case not covered (market_id FK is immutable in practice, acceptable)
- [x] `market_legs.count` in the validation makes one extra DB query per leg creation — acceptable for a POC; no N+1 in practice since we create at most 2 legs per market lifetime
- [x] `will_save_change_to_status?` used with `open?` — correct for Rails 5.1+ dirty tracking ✅

## Decision
**Approved** — proceed to execution via `superpowers:subagent-driven-development`
