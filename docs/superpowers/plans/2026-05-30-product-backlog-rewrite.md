# Product Backlog Source-of-Truth Rewrite Plan (D5)

> **For agentic workers:** This is a documentation rewrite plan (no application code). Execute task-by-task; each task is one atomic docs commit. Use superpowers:executing-plans.

**Goal:** Rewrite `docs/product/BACKLOG.md` so it describes the current four-mechanism product (not a fixed-odds-only POC), establishes a non-colliding product ID scheme, and is maintainable without re-reading historical plans.

**Architecture:** A single rewrite of `docs/product/BACKLOG.md` plus an ID-namespace legend added to `docs/INDEX.md`. Content is sourced from the deep-review product roadmap, the implemented-feature record, and the synthesis backlog — not invented.

**Spec:** none (docs rewrite). Authority for "what exists" = `docs/INDEX.md` + `docs/WORK_LOG.md` + `docs/wiki/market-mechanisms.md`.

---

## Problem statement

- `docs/product/BACKLOG.md` is dated **2026-05-27, "Draft — ready for prioritisation"** and states: *"The fixed-odds house underwriting model is intentionally preserved; these features assume no architectural shift to CLOB. A separate ADR would be required before tackling order-book mechanics."* This is now false — ADR-0013/0014 are accepted and all four mechanisms (fixed_odds, clob, lmsr, parimutuel) plus CLOB sell/buyback and LMSR payouts are shipped.
- **ID collisions:** product `F-###` IDs overlap and conflict with tech-debt `F-###`/`TD-###`. The deep review (docs-handoff) found `F-010`, `F-011`, `F-012` meaning different things in `docs/product/BACKLOG.md` vs `docs/wiki/tech-debt-backlog.md` vs `.claude/tasks/ATTENTION.md`.
- Consequence: a future agent cannot trust the product backlog and must reverse-engineer current state from many plans.

## Sources (read before rewriting)
- `docs/product/BACKLOG.md` (current, to be replaced)
- `docs/INDEX.md` (authoritative implemented/TODO status)
- `docs/WORK_LOG.md` (what shipped, when)
- `docs/wiki/market-mechanisms.md` (mechanism comparison)
- `docs/reviews/2026-05-29-deep-review/product-roadmap.md` (gaps + sequencing)
- `docs/reviews/2026-05-29-deep-review/docs-handoff.md` (ID-collision findings)
- `docs/reviews/2026-05-29-deep-review/synthesis.md` (Tier 0-3 backlog)

---

## Target structure for the rewritten `docs/product/BACKLOG.md`

```
# Adivento — Product Backlog
**Last updated:** 2026-05-30 · **Status:** Living document

## 1. Product reality (current state)
- One paragraph: Adivento is a fantasy prediction-markets POC running FOUR market
  mechanisms — fixed-odds (house-underwritten), CLOB (peer order book, default per ADR-0014),
  LMSR (subsidized market maker), parimutuel (pooled). Remove all "fixed-odds only / no CLOB" language.
- Link to docs/wiki/market-mechanisms.md for the mechanism comparison.

## 2. Mechanism status matrix
| Mechanism | Trading | Cashout/exit | Settlement | Notes |
(fill from INDEX/WORK_LOG: fixed-odds bet+cashout+settle done; CLOB book+sell+buyback+net-settle done;
 LMSR buy+payout done, sell deferred; parimutuel stake+settle done)

## 3. Roadmap tiers (sourced from synthesis)
- **Now (demo-blocking):** any open Tier 0/Tier 1 items not yet shipped.
- **Next:** Tier 1/2 product items (price history D6 ✅planned, resolution transparency D7 ✅planned,
  notifications/watchlist D8, profile P&L, CLOB open-orders UI).
- **Later:** communities (UX-033), mobile/native (D9), responsible-gaming, activity feed.

## 4. Feature entries (PROD-### scheme — see §6)
Each entry: ID, title, mechanism scope (all / clob / etc.), status (shipped / planned / idea),
linked plan or spec, linked TD/UX/synthesis IDs. Keep entries short; details live in the linked plan.

## 5. Primary mechanism for the demo narrative
- State the chosen headline mechanism (open product decision — see synthesis Open Question 1).
  If undecided, mark "DECISION PENDING" and link the question.

## 6. ID scheme + legend (see §6 rules below)
```

---

## ID cleanup rules (proposed)

1. **Namespaces are disjoint and prefix-typed:**
   - `PROD-###` — product feature backlog (this file only).
   - `TD-###` — engineering tech debt (`docs/wiki/tech-debt-backlog.md`).
   - `UX-###` — UX gaps (`docs/wiki/UX_BACKLOG.md`).
   - `DD-###` — design/architecture decisions already executed.
   - `D#-TODO-###` — decision-ballot planning todos (the dispatch tracker).
2. **Retire bare `F-###`.** Replace every product `F-###` with a fresh `PROD-###` and keep a one-time **legacy map** table at the bottom of the rewritten backlog (`F-010 → PROD-0xx`, etc.) so old plan references resolve.
3. **One ID, one meaning, one home file.** An ID is defined in exactly one backlog file; other files reference it, never redefine it.
4. **Status vocabulary:** `shipped` / `planned` (has a plan/spec) / `idea` (no plan yet). No ad-hoc statuses.
5. **New IDs are append-only** (never renumber a shipped ID).

---

## Tasks

### Task 1: Audit current `F-###` items → status + new IDs
- [ ] Read `docs/product/BACKLOG.md` and list every `F-###`.
- [ ] For each, determine current status from `docs/INDEX.md`/`WORK_LOG.md` (shipped vs open) and the deep-review product-roadmap.
- [ ] Produce a mapping table `legacy F-### → PROD-### + status` (this becomes the legacy-map appendix). Save as a scratch list in the PR description or a temp note.
- [ ] Commit nothing yet (analysis step).

### Task 2: Rewrite `docs/product/BACKLOG.md`
- [ ] Replace the whole file with the §-structure above. Remove every "fixed-odds only / no CLOB / ADR required before order book" sentence.
- [ ] Fill §2 mechanism matrix from `market-mechanisms.md` + INDEX (cross-check both agree; if they disagree, INDEX wins and note the discrepancy for DOC-002).
- [ ] Fill §4 entries using `PROD-###` IDs from Task 1; each links to its plan/spec/TD where one exists (e.g., price history → `docs/superpowers/plans/2026-05-30-price-history.md`; resolution → D7 plan; cancellation → D2 plan).
- [ ] Add §5 primary-mechanism section (mark DECISION PENDING if unresolved, linking synthesis Open Question 1).
- [ ] Append the §6 legend + the legacy `F-### → PROD-###` map.
- [ ] Commit: `docs(product): rewrite BACKLOG.md around four-mechanism product (D5)`

### Task 3: Add the ID legend to `docs/INDEX.md`
- [ ] Add a short "ID namespaces" subsection to `docs/INDEX.md` listing the five prefixes from the rules above and which file owns each (resolves docs-handoff DOC-009).
- [ ] Commit: `docs: add ID-namespace legend to INDEX (D5)`

### Task 4: Update cross-references
- [ ] In `.claude/tasks/ATTENTION.md` "Product / UX Backlog Pointers", point to the rewritten backlog and the new ID scheme.
- [ ] In `docs/wiki/tech-debt-backlog.md`, where TD entries reference product `F-###`, update to the new `PROD-###` (or note the legacy map).
- [ ] Commit: `docs: reconcile backlog cross-references to PROD-### scheme (D5)`

---

## Acceptance check (from the dispatch tracker)
- A future agent can open `docs/product/BACKLOG.md`, see the four-mechanism reality, current per-feature status, and the linked plan for each open item — **without** re-reading historical iteration plans.
- No `F-###` ID is ambiguous: every legacy ID resolves through the legacy map to exactly one `PROD-###`.

## Out of scope
- Deciding the primary demo mechanism (that is a product decision; this plan only surfaces it).
- Rewriting `tech-debt-backlog.md` or `UX_BACKLOG.md` structure (only cross-reference fixes here).
- Creating new product features — this is a source-of-truth rewrite, not net-new scope.
