# Decision Planning Dispatch Todo Tracker

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:writing-plans` for any implementation plan you create. Use `superpowers:verification-before-completion` before marking a planning todo complete. Keep this file updated as the checkpoint before ending a session.

**Goal:** Convert approved product/architecture decisions 2-11 from the 2026-05-30 decision ballot into dispatchable planning work.

**Architecture:** Decision 1, the backend correctness lane, is already in progress with Claude and is not duplicated here. Decisions 2-11 are tracked as planning todos, each producing a small ADR, spec, implementation plan, backlog update, or plan review artifact that can be assigned to a specialist agent.

**Tech Stack:** Rails 8, PostgreSQL, Redis/SSE, Minitest, Playwright, markdown docs, Superpowers planning workflow.

---

## Resume Checkpoint

Last updated: 2026-05-30.

Current branch for this tracker: `codex/planning-decision-todos`.

Do not edit application code for this planning dispatch. This PR should only update planning/backlog docs. Claude is handling Decision 1 backend correctness implementation work separately.

## Approved Recommended Options

The user accepted Decision 1 as already in progress with Claude and asked to track recommended options for Decisions 2-11 as todos.

| Decision | Approved option | Planning owner lane | Status |
|----------|-----------------|---------------------|--------|
| D2 Market cancellation scope | Full cross-mechanism atomic cancellation/refund service | Trust/backend architecture | ✅ Planned — `docs/specs/2026-05-30-market-cancellation.md` + `docs/superpowers/plans/2026-05-30-market-cancellation.md` |
| D3 CLOB trading-state guards | Centralize guards inside `Clob::OrderMatchingService` | CLOB/backend correctness | ✅ Planned — `docs/superpowers/plans/2026-05-30-d3-clob-trading-state-guards.md` |
| D4 CLOB cancellation locking | Shared cancellation service with row/wallet locks | CLOB/backend correctness | ✅ Planned — `docs/superpowers/plans/2026-05-30-d4-clob-order-cancellation-service.md` |
| D5 Product roadmap source of truth | Rewrite `docs/product/BACKLOG.md` around the four-mechanism product | Product/docs | ✅ Planned — `docs/superpowers/plans/2026-05-30-product-backlog-rewrite.md` |
| D6 Price history | Expose existing `PriceSnapshot` with endpoint and simple chart now | Product/UX/backend | ✅ Planned — `docs/specs/2026-05-30-price-history.md` + `docs/superpowers/plans/2026-05-30-price-history.md` |
| D7 Resolution transparency | Require resolution note and settlement metadata across all settlement paths | Trust/product/backend | ✅ Planned — `docs/specs/2026-05-30-resolution-transparency.md` + `docs/superpowers/plans/2026-05-30-resolution-transparency.md` |
| D8 Notifications/watchlist | Dedicated notification/watchlist tables | Product/backend | ✅ Planned — `docs/specs/2026-05-30-watchlists-notifications.md` + `docs/superpowers/plans/2026-05-30-d8-watchlists-notifications.md` |
| D9 Mobile/UX blocker policy | Unblock responsive web/mobile work from community features | UX/mobile | Todo |
| D10 Browser test matrix | Chromium per PR, Firefox/WebKit nightly | QA/release | Todo |
| D11 Docs/review process | Plan reviews for larger work, lightweight exception for surgical fixes | Docs/process | Todo |

## Dispatch Rules

- Each planning todo below is independent enough for a specialist agent.
- Each agent should update this file in the relevant row before handing off.
- Each completed planning todo must produce one concrete artifact path, not just a summary.
- If a todo expands into implementation work, create implementation plans under `docs/superpowers/plans/`; do not implement code in this PR.
- If an option affects multiple systems or establishes policy, create or update an ADR under `docs/adr/`.
- If a feature needs product requirements before implementation, create or update a spec under `docs/specs/`.

## Already-Implemented Audit

Checked against the current branch after merging `origin/main` on 2026-05-30. None of the D2-D11 todos should be deleted as already implemented.

| Todo | Audit result | Evidence |
|------|--------------|----------|
| D2-TODO-001 | Keep | No `app/services/market_cancellation_service.rb`; TD-017 still says no cancellation service exists. |
| D3-TODO-002 | Keep | `Web::OrdersController#create` has lifecycle guards, but `Admin::OrdersController#create` only checks CLOB and `Clob::OrderMatchingService` has no centralized open/close guard. |
| D4-TODO-003 | Keep | Admin cancel now locks order/wallet as a partial TD-013 follow-up, but there is no shared `Clob::OrderCancellationService`; web/admin still duplicate cancellation logic. |
| D5-TODO-004 | Keep | `docs/product/BACKLOG.md` still describes the project as a fixed-odds POC and has not been rewritten around four mechanisms. |
| D6-TODO-005 | Keep | `PriceSnapshot` and recorder exist, but there is no price-history endpoint or real chart consumer. |
| D7-TODO-006 | Keep | `resolution_note` and `settled_at` appear only in backlog prose; no schema/controller/service implementation exists. |
| D8-TODO-007 | Keep | No notification/watchlist models, tables, controllers, or routes exist. |
| D9-TODO-008 | Keep | `docs/wiki/UX_BACKLOG.md` still marks UX-034 deferred and blocked by community features. |
| D10-TODO-009 | Keep | Playwright has local Firefox/WebKit projects when not in Docker, but CI has no nightly schedule and Docker E2E remains Chromium-only. |
| D11-TODO-010 | Keep | Docs still describe strict sequencing; no surgical-exception checklist or policy update exists. |

## Planning Todos

### D2-TODO-001: Plan full cross-mechanism market cancellation

**Recommended option:** Full cross-mechanism atomic cancellation/refund service.

**Primary sources:**
- `docs/wiki/tech-debt-backlog.md` TD-017
- `docs/reviews/2026-05-29-deep-review/synthesis.md` Cluster 6
- `docs/reviews/2026-05-29-deep-review/security-trust.md`
- `docs/reviews/2026-05-29-deep-review/market-mechanics.md`

**Required planning artifacts:**
- [x] Spec: `docs/specs/2026-05-30-market-cancellation.md`.
- [x] Implementation plan: `docs/superpowers/plans/2026-05-30-market-cancellation.md` (`MarketCancellationService`, per-mechanism refund tasks, backoffice cancel action, tests).
- [x] TD-017 updated in `docs/wiki/tech-debt-backlog.md` (plan-written, full-service policy).

**Acceptance check:** ✅ The plan covers fixed-odds open bets, CLOB resting orders/reservations + filled-position net-cash refund/clawback, LMSR positions/cost refunds, parimutuel stakes, idempotency (locked market row), audit events, and wallet locking. CLOB filled-position refund documents its TD-023 ledger-taxonomy dependency.

### D3-TODO-002: Plan centralized CLOB trading-state guards

**Recommended option:** Centralize market lifecycle checks inside `Clob::OrderMatchingService`.

**Primary sources:**
- `docs/wiki/tech-debt-backlog.md` TD-020
- `docs/reviews/2026-05-29-deep-review/code-correctness.md`
- `docs/reviews/2026-05-29-deep-review/architecture.md`

**Required planning artifacts:**
- [x] Create an implementation plan for moving open/close_at lifecycle checks into `Clob::OrderMatchingService`: `docs/superpowers/plans/2026-05-30-d3-clob-trading-state-guards.md`.
- [x] Include admin and web controller regression tests for draft, closed, settled, cancelled, and expired markets.
- [ ] Update TD-020 with the selected centralized-service approach.

**Acceptance check:** The plan makes web/admin/API callers share one service-level lifecycle guard and prevents future privileged bypasses.

### D4-TODO-003: Plan shared CLOB order cancellation service

**Recommended option:** Shared `Clob::OrderCancellationService` with order row lock and wallet row lock.

**Primary sources:**
- `docs/wiki/tech-debt-backlog.md` TD-021
- `docs/reviews/2026-05-29-deep-review/synthesis.md` Cluster 9
- `docs/reviews/2026-05-29-deep-review/data-postgres.md`

**Required planning artifacts:**
- [x] Create an implementation plan for a shared cancellation service used by web and admin controllers: `docs/superpowers/plans/2026-05-30-d4-clob-order-cancellation-service.md`.
- [x] Include a regression test for double-cancel attempts.
- [ ] Update TD-021 with the selected shared-service locking policy.

**Acceptance check:** The plan keeps order state transition, reserved-fund release, audit logging, and authorization boundaries explicit.

### D5-TODO-004: Plan product backlog source-of-truth rewrite

**Recommended option:** Rewrite `docs/product/BACKLOG.md` around the current four-mechanism product.

**Primary sources:**
- `docs/product/BACKLOG.md`
- `docs/INDEX.md`
- `docs/wiki/market-mechanisms.md`
- `docs/reviews/2026-05-29-deep-review/product-roadmap.md`
- `docs/reviews/2026-05-29-deep-review/docs-handoff.md`

**Required planning artifacts:**
- [x] Rewrite plan: `docs/superpowers/plans/2026-05-30-product-backlog-rewrite.md` (removes fixed-odds-only assumptions).
- [x] Roadmap hierarchy defined (Now/Next/Later tiers + four-mechanism status matrix in the target structure).
- [x] ID cleanup rules proposed (`PROD-###` namespace, retire bare `F-###`, legacy map, INDEX legend).

**Acceptance check:** ✅ The target structure + legacy `F-### → PROD-###` map lets a future agent update the backlog without re-reading historical plans.

### D6-TODO-005: Plan PriceSnapshot endpoint and simple chart

**Recommended option:** Expose existing `PriceSnapshot` data with a web endpoint and simple chart now.

**Primary sources:**
- `docs/product/BACKLOG.md` F-004
- `docs/wiki/UX_BACKLOG.md` UX-004
- `docs/reviews/2026-05-29-deep-review/synthesis.md` Cluster 8
- `docs/reviews/2026-05-29-deep-review/architecture.md`

**Required planning artifacts:**
- [x] Spec: `docs/specs/2026-05-30-price-history.md` (normalization rule per mechanism).
- [x] Implementation plan: `docs/superpowers/plans/2026-05-30-price-history.md` (JSON endpoint + server-side SVG chart + **wiring snapshot recording**, which is currently dead code).
- [x] Retention/pruning deferred as TD-035 (called out in the plan), not blocking the chart.

**Acceptance check:** ✅ Scoped to existing `PriceSnapshot` data; retention explicitly deferred to TD-035. **Key finding:** the recorder/job are never enqueued today, so the plan also wires recording into the four mutating services.

### D7-TODO-006: Plan resolution transparency across settlement paths

**Recommended option:** Require resolution note and settlement metadata across all settlement paths.

**Primary sources:**
- `docs/product/BACKLOG.md` F-010
- `docs/wiki/UX_BACKLOG.md` UX-030
- `docs/reviews/2026-05-29-deep-review/security-trust.md`
- `docs/reviews/2026-05-29-deep-review/ux-research-ia.md`

**Required planning artifacts:**
- [x] Spec: `docs/specs/2026-05-30-resolution-transparency.md` (mandatory note, `settled_at`, audit metadata, customer display).
- [x] Decision recorded: **minimal mandatory-note path** (migration + central enforcement in `SettlementService.settle!`); the propose/approve/execute workflow is explicitly deferred to **SEC-003**.
- [x] Implementation plan: `docs/superpowers/plans/2026-05-30-resolution-transparency.md`.

**Acceptance check:** ✅ Enforced at the single `SettlementService.settle!` entry point, so every mechanism (fixed_odds/clob/lmsr/parimutuel) gets an auditable, player-visible explanation.

### D8-TODO-007: Plan dedicated notifications and watchlists

**Recommended option:** Dedicated notification/watchlist tables.

**Primary sources:**
- `docs/product/BACKLOG.md` F-008
- `docs/reviews/2026-05-29-deep-review/product-roadmap.md`
- `docs/reviews/2026-05-29-deep-review/data-postgres.md`

**Required planning artifacts:**
- [x] Create an ADR or spec choosing dedicated tables instead of repurposing `audit_events`: `docs/specs/2026-05-30-watchlists-notifications.md`.
- [x] Define first notification triggers: watched market close, settlement, cancellation, and material market update.
- [x] Create an implementation plan for watchlist persistence, notification records, and a simple profile notification surface: `docs/superpowers/plans/2026-05-30-d8-watchlists-notifications.md`.

**Acceptance check:** Audit logging remains operator/trust infrastructure; player notifications get their own queryable product model.

### D9-TODO-008: Plan responsive web/mobile independently of communities

**Recommended option:** Unblock responsive web/mobile work from community features.

**Primary sources:**
- `docs/wiki/UX_BACKLOG.md` UX-034
- `docs/reviews/2026-05-29-deep-review/mobile-design.md`
- `docs/reviews/2026-05-29-deep-review/ui-design.md`

**Required planning artifacts:**
- [ ] Update UX-034 so responsive web/mobile is no longer blocked by UX-033 communities.
- [ ] Create an ADR or planning note for the path: responsive web, then PWA manifest, then optional Turbo Native shell.
- [ ] Create an implementation plan for the first responsive web slice.

**Acceptance check:** Mobile planning can proceed without waiting for community groups, memberships, or invites.

### D10-TODO-009: Plan browser matrix rollout

**Recommended option:** Chromium on every PR; Firefox/WebKit on a nightly schedule.

**Primary sources:**
- `docs/wiki/tech-debt-backlog.md` TD-006
- `docs/reviews/2026-05-29-deep-review/qa-release.md`
- `.github/workflows/ci.yml`
- `e2e/playwright/playwright.config.js`

**Required planning artifacts:**
- [ ] Update TD-006 with the selected nightly Firefox/WebKit policy.
- [ ] Create an implementation plan for Playwright project config and GitHub Actions schedule changes.
- [ ] Include expected CI-time trade-offs and failure triage policy.

**Acceptance check:** PR feedback remains fast while Safari/Firefox regressions are discovered on a predictable cadence.

### D11-TODO-010: Plan docs/review process policy

**Recommended option:** Plan reviews for larger work, lightweight exception for surgical fixes.

**Primary sources:**
- `docs/INDEX.md`
- `docs/templates/plan-review.md`
- `docs/reviews/2026-05-29-deep-review/docs-handoff.md`
- `docs/reviews/2026-05-29-deep-review/synthesis.md` Cluster 13

**Required planning artifacts:**
- [ ] Update the docs sequencing policy with criteria for plan review required vs surgical exception.
- [ ] Create a small checklist agents can use before skipping a plan review.
- [ ] Update the attention tracker so large planning todos require a review artifact before implementation.

**Acceptance check:** Agents can move quickly on small fixes while larger cross-system work still gets a review checkpoint.

## Suggested Agent Dispatch Batches

| Batch | Todos | Rationale |
|-------|-------|-----------|
| Backend correctness planners | D2, D3, D4 | Same CLOB/trust/accounting context; can share findings but should write separate plans. |
| Product trust planners | D6, D7, D8 | All need user-facing trust/product requirements before implementation. |
| Product/docs planner | D5, D11 | Backlog source-of-truth and process policy should stay consistent. |
| UX/mobile planner | D9 | Needs design/mobile focus and can proceed independently. |
| QA/release planner | D10 | CI and browser-matrix work is isolated from product/code planning. |

## Status Log

- 2026-05-30: Created tracker from the approved recommended options for Decisions 2-11. Decision 1 intentionally left out because Claude is already progressing it.
- 2026-05-30 (Claude): Planned D2, D5, D6, D7 in detail. Artifacts: D2 spec+plan (`market-cancellation`), D5 rewrite plan (`product-backlog-rewrite`), D6 spec+plan (`price-history`), D7 spec+plan (`resolution-transparency`). D3, D4, D8–D11 remain Todo.
- 2026-05-30: Planned D3, D4, and D8 in detail. Refined D7 spec/plan consistency to the 20-character mandatory-note rule.
