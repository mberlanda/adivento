# Docs / Backlog Handoff Deep Review

## Scope

Reviewed the documentation and handoff surface requested for the backlog/documentation hygiene pass:

- `CLAUDE.md`
- `docs/INDEX.md`
- `docs/WORK_LOG.md`
- `.claude/tasks/ATTENTION.md`
- `docs/wiki/`
- `docs/product/BACKLOG.md`
- `docs/specs/`
- `docs/superpowers/plans/`
- `docs/reviews/2026-05-29-deep-review/` reports already present

Focus was documentation consistency, stale statuses, ADR/spec/plan chain quality, backlog IDs, handoff readiness, checkpoint quality, and whether future agents can resume safely. No app code was modified.

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|
| P0 | Handoff queue is internally inconsistent: docs/backlog review was requested "after all reports are present", but the review index still marks DevOps pending and there is no `devops-operability.md` in the worktree. This creates a synthesis risk because the next agent may treat the review wave as complete while one family is absent. | `docs/reviews/2026-05-29-deep-review/CHECKPOINT.md:31-33` says `docs-handoff.md` should be dispatched after all reports are present, while `docs/reviews/2026-05-29-deep-review/README.md:21-23` still marks `devops-operability.md`, `docs-handoff.md`, and `synthesis.md` pending. `find docs/reviews/2026-05-29-deep-review -name '*devops*'` returned no files. | Update the checkpoint/report index before synthesis: either dispatch DevOps first or explicitly mark DevOps deferred and record that synthesis excludes it. |
| P0 | The highest-risk post-PR #36 bugs are tracked but not planned first. `ATTENTION.md` and `INDEX.md` tell agents to execute TD-013 through TD-017 first, while multiple specialist reports classify TD-018/TD-019 CLOB settlement/reservation as P0 balance-corrupting bugs. | `.claude/tasks/ATTENTION.md:23-32` orders TD-013 through TD-017 before TD-018/TD-019; `docs/INDEX.md:147-150` says execute backend-next-steps first, then create follow-up plans for TD-018 through TD-022. Specialist evidence: `architecture.md` P0 findings for CLOB overpay and sell reservation; `market-mechanics.md` P0 findings for the same; `security-trust.md` P0 CLOB overpay. | Create an urgent `2026-05-29-clob-sell-settlement-safety.md` plan for TD-018/TD-019 and move it ahead of UX/product polish and likely ahead of TD-014 through TD-017. |
| P1 | `docs/wiki/market-mechanisms.md` is stale in exactly the areas future agents need for safe mechanism work: it says CLOB cashout is not implemented and LMSR settlement payouts are not implemented, contradicting `INDEX.md`, `ATTENTION.md`, and PR #35/#36 work log entries. | `docs/wiki/market-mechanisms.md:37-39` says CLOB is fully implemented but cashout is not yet implemented; `docs/wiki/market-mechanisms.md:53-55` says LMSR individual payouts are not implemented. `docs/INDEX.md:144-145` says LMSR positions/settlement payouts and CLOB sell/buyback are done; `.claude/tasks/ATTENTION.md:40-42` lists DD-006 and DD-002 as completed. | Refresh `docs/wiki/market-mechanisms.md`: mark CLOB sell/buyback and LMSR payouts shipped; link remaining risks to TD-018/TD-019 and the LMSR sell-trade decision. |
| P1 | Product backlog is still labeled as a fixed-odds-only draft from 2026-05-27 even though ADR-0013/0014 and implementation status now describe four mechanisms and CLOB as default. This makes product priority handoff ambiguous. | `docs/product/BACKLOG.md:3-13` says last updated 2026-05-27, draft, and assumes no architectural shift to CLOB. `docs/INDEX.md:79-80` lists ADR-0013 and ADR-0014 accepted; `docs/INDEX.md:103-145` lists four mechanisms, CLOB order book completion, LMSR payouts, and CLOB sell/buyback as done. `product-roadmap.md` explicitly asks whether `docs/product/BACKLOG.md` is authoritative. | Replace or amend `docs/product/BACKLOG.md` with a current product roadmap note: four-mechanism reality, primary demo mechanism, near-term P0/P1 sequencing, and which legacy F-items remain active. |
| P1 | The plan/spec chain rule is clear, but several active plans intentionally bypass it or lack plan reviews, weakening "resume safely" guarantees. | `docs/INDEX.md:39-59` requires ADR/spec/plan/plan-review before implementation and says executable plans need exact paths, commands, and checkboxes. `docs/superpowers/plans/2026-05-29-backend-next-steps.md:13` says it is both review and plan, with no separate spec; `docs/INDEX.md:169` lists its review as `—`. Planned UX slices in `docs/wiki/UX_BACKLOG.md:58-61` also have no review files listed. | Add lightweight plan reviews for backend-next-steps and UX PR A-D, or explicitly tag them "surgical/no-review-needed" with rationale and owner. |
| P1 | UX backlog has stale blockers: CLOB cancel/open-order UI is marked blocked even though the endpoint exists, and mobile responsive layout is marked blocked by community features though mobile review says it is orthogonal. | `docs/wiki/UX_BACKLOG.md:25` says UX-010 is blocked by cancel endpoint design; `docs/wiki/UX_BACKLOG.md:50` says UX-035 needs cancel endpoint design. Product/UX reviews note `DELETE /web/orders/:id` exists and recommend unblocking. `docs/wiki/UX_BACKLOG.md:49` says UX-034 is blocked by community features; `mobile-design.md` says responsive web can be done independently and should be rescheduled. | Update UX backlog blockers and dependencies: UX-010/UX-035 should depend on existing cancel route testing/design polish, and UX-034 should be independent of community features. |
| P2 | Feature IDs are overloaded across different backlogs and eras, making handoff navigation error-prone. F-010 means "Market close UX" in tech-debt backlog but "Resolution Outcome Transparency" in product backlog. F-011/F-012 also differ across documents. | `.claude/tasks/ATTENTION.md:51-52` lists F-010 as Market close UX shipped in PR #28. `docs/product/BACKLOG.md:313-340` defines F-010 as Resolution Outcome Transparency. `docs/wiki/tech-debt-backlog.md:13-22` uses F-011 as LMSR payouts and F-012 as positions, while `docs/product/BACKLOG.md:344-420` uses F-011 as activity feed and F-012 as responsible gambling. | Freeze legacy product IDs and introduce a namespace convention: `PROD-F010` for product backlog, `UX-###`, `TD-###`, `DD-###`. Add an ID map to `docs/INDEX.md` or the synthesis. |
| P2 | The deep-review reports are high signal but not normalized enough for synthesis: some title sections deviate from the required structure and many duplicate the same P0s under different suggested IDs. | Dispatch contract requires `## Top Findings` and `## Backlog Candidates` in `docs/superpowers/plans/2026-05-29-specialist-review-dispatch.md:49-68`. `market-mechanics.md` uses `## Top Findings table with Priority/Finding/Evidence/Recommended next task`; reports propose duplicate CLOB tasks as TD-018, ARCH-001, PROD-002, QA-003, SEC-002. | Before synthesis, create a canonical finding map that merges duplicates into existing IDs, with source reports listed as evidence rather than creating new parallel backlog tasks. |
| P2 | Checkpoint quality is good but incomplete: it records worktree/branch/base and report status, but it does not include latest commit, dirty-file status, or exact next command. This matters in a multi-agent branch with reports "present, ready to commit". | `docs/reviews/2026-05-29-deep-review/CHECKPOINT.md:5-9` records worktree/branch/base. `CHECKPOINT.md:17-24` says several reports are present and ready to commit, but not whether they are staged/dirty or which command to run. `CHECKPOINT.md:37-39` warns about accidental writes in the main workspace. | Extend `CHECKPOINT.md` after each agent with `git status --short`, last commit SHA, and the exact next action. |

## Detailed Notes

### Source-of-truth health

The project has a strong entrypoint model: `CLAUDE.md` requires `docs/INDEX.md` first, defines the ADR/spec/plan/review/implement/verify/docs sequence, and requires task folders for multi-session work. `docs/INDEX.md` mirrors this well and gives future agents a compact file map and run commands. The handoff problem is not lack of documentation; it is that several source-of-truth files have drifted after a fast run of PRs and specialist reports.

The most reliable current status files are `docs/INDEX.md`, `.claude/tasks/ATTENTION.md`, `docs/WORK_LOG.md`, and `docs/wiki/tech-debt-backlog.md`. The weakest current-status file is `docs/product/BACKLOG.md`, because it still describes the system as fixed-odds-first and draft. The most stale wiki page is `docs/wiki/market-mechanisms.md`.

### ADR/spec/plan chain

The architecture chain is mostly healthy through ADR-0014. `docs/INDEX.md:63-80` lists all ADRs as accepted, and the implemented status table reflects the corresponding work. The gap is in active follow-up work. `docs/superpowers/plans/2026-05-29-backend-next-steps.md` is explicitly both a review and plan, with no separate spec. That is reasonable for small surgical fixes, but it should be called out as an exception because `CLAUDE.md` and `docs/INDEX.md` make the chain normative.

The UX plans are more concerning. `2026-05-29-ux-market-browse-detail.md` says the architecture is pure view changes with no new routes or migrations, yet the same plan adds controller filter params and an empty `@price_history` stub. Its open design questions admit CLOB depth arrays need backend changes and price-history range buttons need an endpoint. Future agents can execute it, but they may accidentally ship placeholders as if they were feature completion.

### Backlog and ID hygiene

The ID situation needs a cleanup pass before synthesis. `TD-013` through `TD-022` are clear and should remain canonical for backend correctness. The new specialist reports add valuable findings but should not be copied wholesale as new IDs where existing IDs already exist. For example, TD-018 maps to ARCH-001, PROD-002, QA-003, SEC-002, and DB-002. TD-019 maps to ARCH-002, PROD-010, QA-004, and market-mechanics TD-019.

Product `F-###` IDs are the biggest ambiguity. The same number can mean a shipped implementation feature in tech-debt/work-log context or a draft product roadmap item in `docs/product/BACKLOG.md`. A synthesis agent should preserve existing references but introduce a prefix like `PROD-F010` when referring to the product backlog document.

### Handoff readiness

Future agents can resume backend work from `.claude/tasks/ATTENTION.md` and `docs/superpowers/plans/2026-05-29-backend-next-steps.md`, but the recommended order should be revisited. The review wave found that CLOB sell orders created two P0 correctness defects after PR #36. Those defects are acknowledged as TD-018/TD-019 but are still "needs plan" and listed after TD-013 through TD-017. That ordering is risky because any further CLOB UX or demo work will rest on unsafe accounting.

The deep-review handoff itself is not yet synthesis-ready unless DevOps is intentionally skipped. The dispatch plan defined A11 DevOps/operability, README marks it pending, and no report exists. The checkpoint says docs-handoff should run after all reports are present, which is false in this worktree. This is easy to repair, but it should be repaired before synthesis so the final report does not claim full coverage.

### Documentation consistency examples

`docs/wiki/market-mechanisms.md` says LMSR settlement is "UI label only" and individual payouts are deferred. That conflicts directly with `docs/INDEX.md`, `WORK_LOG.md`, and the completed DD-002 entry in `ATTENTION.md`.

`docs/wiki/market-mechanisms.md` says CLOB cashout is not implemented. That conflicts with DD-006 and PR #36, which added sell limit orders, net position service, CLOB cashout service, operator buyback, and UI entrypoints.

`docs/wiki/UX_BACKLOG.md` says CLOB open-order/cancel UI is blocked by endpoint design. Existing specialist reports found a cancel route exists and the remaining task is UI/test/design polish, not endpoint discovery.

`docs/wiki/UX_BACKLOG.md` says mobile responsive layout is blocked by community features. The mobile review found responsive web is a near-term standalone task and community features are unrelated.

## Open Questions

1. Should `devops-operability.md` be dispatched before synthesis, or should the synthesis explicitly state that DevOps/operability was deferred?
2. Is `docs/product/BACKLOG.md` still an authoritative product backlog, or should it be archived/replaced by a new four-mechanism roadmap?
3. Should TD-018/TD-019 preempt the current backend-next-steps order, or should TD-013 wallet locking remain first because it affects multiple services?
4. Should "plan review required" remain strict for all current plans, or should the docs define a lighter exception path for surgical follow-up tasks?
5. What canonical ID namespace should synthesis use for findings that appear in multiple reports: existing `TD-###`, report-prefixed IDs, or a new synthesis ID map?

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|---------------|------|------|--------------|------------------|
| DOC-001 | Resolve deep-review wave status before synthesis: dispatch `devops-operability.md` or mark it explicitly deferred in README and CHECKPOINT. | XS | None | `README.md` and `CHECKPOINT.md` agree on every report status; synthesis scope states whether DevOps is included. |
| DOC-002 | Refresh `docs/wiki/market-mechanisms.md` after PR #35/#36. | S | None | Page states LMSR payouts exist, CLOB sell/cashout/buyback exist, and remaining gaps link to TD-018/TD-019/TD-026. |
| DOC-003 | Create urgent TD-018/TD-019 executable plan and move it into the ready-work queue ahead of CLOB UX polish. | S | Specialist reports completed | New plan has tests-first steps for buy-sell-settle and duplicate sell reservation; `.claude/tasks/ATTENTION.md` links it. |
| DOC-004 | Add canonical synthesis finding map to merge duplicate specialist backlog candidates. | S | All family reports present | Each duplicate CLOB/wallet/UX/security finding maps to one canonical ID with source reports listed. |
| DOC-005 | Reconcile product backlog with four-mechanism reality. | M | Product decision on primary demo mechanism | `docs/product/BACKLOG.md` or replacement roadmap no longer says fixed-odds-only; stale F-ID conflicts are documented. |
| DOC-006 | Add lightweight plan reviews or documented exception rationale for active backend and UX plans. | S | Plan owners available | Backend-next-steps and UX PR A-D either have `*-review.md` files or explicit `review-exempt` rationale with risks. |
| DOC-007 | Update UX backlog blockers and dependencies. | XS | None | UX-010/UX-035 no longer say blocked on cancel endpoint design; UX-034 is independent from community features. |
| DOC-008 | Improve checkpoint template for multi-agent review waves. | XS | None | `CHECKPOINT.md` includes last commit, dirty-file status, staged status, and exact next action. |
| DOC-009 | Add ID namespace guidance to `docs/INDEX.md`. | XS | DOC-005 decision | `docs/INDEX.md` explains `TD-###`, `UX-###`, `DD-###`, and product backlog IDs so future agents do not conflate F-010 meanings. |
