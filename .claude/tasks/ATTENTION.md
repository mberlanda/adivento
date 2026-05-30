# Tasks Requiring Attention or User Answers

Last updated: 2026-05-30

This file is the single index of open items. Check it at the start of each session.
See **Backlog trackers** below for the other source-of-truth files and what each owns.

---

## 🔴 Blocked — Need User Input

_No blocked items. All pending design decisions have been resolved._

---

## Backlog trackers (sources of truth)

One concern per file. When you change status, update the tracker that **owns** the item, then reflect it here.

| Tracker | Owns | File |
|---------|------|------|
| **ATTENTION.md** (this file) | the single open-items index + the execution waves below | `.claude/tasks/ATTENTION.md` |
| Tech-debt backlog | `TD-###` engineering-debt detail + design options | `docs/wiki/tech-debt-backlog.md` |
| Decision dispatch | `D2–D11` decision plans + approved options | `docs/superpowers/plans/2026-05-30-decision-planning-dispatch.md` |
| UX backlog | `UX-###` gaps + the PR A–D slices | `docs/wiki/UX_BACKLOG.md` |
| Product backlog | `PROD/F-###` product features (rewrite pending **D5**) | `docs/product/BACKLOG.md` |
| Deep-review synthesis | consolidated Tier 0–3 findings (read-only record) | `docs/reviews/2026-05-29-deep-review/synthesis.md` |
| Status index | implemented vs planned map | `docs/INDEX.md` |
| Work log | dated build history | `docs/WORK_LOG.md` |

---

## 🟡 Ready for Autonomous Work

**Owner key** (who should execute):
- 🔴 **Opus 4.8** — financial correctness, concurrency/locking, ledger, settlement, cross-system architecture. Most complex.
- 🟢 **Sonnet** — standard feature slices, controllers/views, moderate planning.
- 🔵 **Codex** — trivial fixes (one file / params / lint) and docs/process planning.

Execute waves in order; within a wave, respect **Depends on**. `D#` and its `TD-###` are the **same work** (the plan implements the debt).

### Wave 1 — Backend quick wins (no dependencies)

✅ Completed 2026-05-30 on branch `codex/wave-1-backend-quick-wins`.

### Wave 2 — CLOB correctness ✅ D3/D4/D2 done; TD-034 needs plan
| Item | ID / D | Plan | Owner | Cx | Depends on | Status |
|------|--------|------|-------|----|-----------|--------|
| Centralize CLOB trading-state guards | TD-020 / D3 | `2026-05-30-d3-clob-trading-state-guards.md` | 🟢 Sonnet | M | — | ✅ done (wave 2) |
| Shared `Clob::OrderCancellationService` (order + wallet locks) | TD-021 / D4 | `2026-05-30-d4-clob-order-cancellation-service.md` | 🔴 Opus | M | D3 | ✅ done (wave 2) |
| `MarketCancellationService` + backoffice cancel (cross-mechanism refunds) | TD-017 / D2 | `2026-05-30-market-cancellation.md` | 🔴 Opus | L | D4 | ✅ done (wave 2) |
| Settlement & sell-order concurrency idempotency | TD-034 | needs plan | 🔴 Opus | M | D2 | ⏳ open — needs plan |

### Wave 3 — Trust & product features (plans written)
| Item | D | Plan | Owner | Cx | Depends on |
|------|---|------|-------|----|-----------|
| Resolution transparency (mandatory note + `settled_at` + audit) | D7 | `2026-05-30-resolution-transparency.md` (+spec) | 🔴 Opus | M | — |
| Price history endpoint + chart + wire snapshot recording | D6 | `2026-05-30-price-history.md` (+spec) | 🟢 Sonnet | M | — |
| Watchlists + notifications tables/surface | D8 | `2026-05-30-d8-watchlists-notifications.md` (+spec) | 🟢 Sonnet | M | D7 (settle events), D2 (cancel events) |

### Wave 4 — Planning & process (produce docs; can run anytime)
| Item | D | Deliverable | Owner | Cx |
|------|---|-------------|-------|----|
| Product backlog rewrite (four-mechanism, `PROD-###` scheme) | D5 | execute `2026-05-30-product-backlog-rewrite.md` | 🔵 Codex | S |
| Unblock responsive web/mobile from communities + first slice | D9 | backlog update + mobile plan | 🔵 Codex | S |
| Browser matrix: Chromium per PR, FF/WebKit nightly | D10 / TD-006 | QA implementation plan | 🟢 Sonnet | S |
| Plan-review policy (review-required vs surgical exception) | D11 | docs policy update | 🔵 Codex | XS |

### Wave 5 — UX slices (after their backend deps land)
| Slice | Plan | Owner | Depends on |
|-------|------|-------|-----------|
| PR A — market browse + detail | `2026-05-29-ux-market-browse-detail.md` | 🟢 Sonnet | D6 (price chart) |
| PR B — leaderboard/profile/auth/positions | `2026-05-29-ux-leaderboard-profile-auth.md` | 🟢 Sonnet | TD-014, TD-015 |
| PR C — settlement explainer page | `2026-05-29-ux-settlement-explainer-page.md` | 🟢 Sonnet | D7 |
| PR D — backoffice dashboard/settle/faucet | `2026-05-29-ux-backoffice-dashboard-settle.md` | 🟢 Sonnet | D2 (cancel UI), D7 (settle preview) |

---

## 🟢 Recently Completed

| Task | Completed | PR / Commit |
|------|-----------|-------------|
| Wave 1 backend quick wins: TD-014/015/016/022 | 2026-05-30 | branch `codex/wave-1-backend-quick-wins` |
| TD-020/D3 CLOB trading-state guards centralized | 2026-05-30 | wave-2 branch |
| TD-021/D4 Clob::OrderCancellationService shared service | 2026-05-30 | wave-2 branch |
| TD-017/D2 MarketCancellationService + backoffice cancel | 2026-05-30 | wave-2 branch |
| UX-036/UX-023 web registration form + session login | 2026-05-30 | branch `feat/ux-036-web-registration` |
| TD-013 lock wallet rows across all mutation paths | 2026-05-29 | branch `fix/td-013-wallet-locking` |
| TD-019 reserve contracts for open CLOB sell orders | 2026-05-29 | branch `fix/td-019-clob-sell-reservation` |
| TD-018 CLOB settlement pays net positions | 2026-05-29 | branch `fix/td-018-clob-net-settlement` |
| DD-006 CLOB sell orders + operator buyback | 2026-05-29 | PR #36 `8a67f3c` |
| DD-002 LMSR positions + settlement payouts | 2026-05-29 | PR #35 `f0a8b12` |
| DD-004 PostgreSQL test DB + structure.sql | 2026-05-29 | PR #33 `889d951` |
| UX wireframes v1 | 2026-05-29 | PR #34 `f784b9b` |
| TD-007 Backoffice open-market E2E | 2026-05-28 | PR #31 `256932d` |
| TD-011 Market edit description field | 2026-05-28 | PR #31 `256932d` |
| F-016 / TD-003 LMSR subsidy exhaustion guard | 2026-05-28 | PR #30 `284928b` |
| F-012 Player positions HTML view | 2026-05-28 | PR #29 |
| F-013 Betslip execution confirmation HTML view | 2026-05-28 | PR #29 |
| F-015 Cross-mechanism leaderboard P&L | 2026-05-28 | PR #29 |
| F-017 Market list pagination | 2026-05-28 | PR #29 |
| F-009 Automated market close | 2026-05-28 | PR #28 |
| F-010 Market close UX | 2026-05-28 | PR #28 (shipped in F-009) |
| Wiki consolidation + task cleanup | 2026-05-28 | PR #27 |
| E2E Docker Compose + Zeitwerk production fix | 2026-05-28 | PR #26 `490f215` |
| Multi-player settlement E2E (all 4 mechanisms) | 2026-05-28 | PR #25 `d0dbd5a` |
| CLOB/LMSR/parimutuel quick-bet E2E + side fix | 2026-05-28 | PR #23 `6a61122` |
| F-006 Market create UX | 2026-05-28 | PR #21 `528e7ba` |
| F-003 Market detail enrichment | 2026-05-28 | PR #18 `3dd6be1` |
| F-007 Leaderboard | 2026-05-28 | PR #18 `3dd6be1` |
| Quick-bet form (all 4 mechanisms) | 2026-05-28 | PR #18 `3dd6be1` |
| F-005 User profile | 2026-05-27 | PR #17 `07d79ce` |
| F-002 Full-text search | 2026-05-27 | PR #16 `c400e5f` |
| F-001 Market taxonomy | 2026-05-27 | PRs #13–15 |
| CLOB order book completion | 2026-05-27 | PRs #10–12 `5d48ac1` |
| Pluggable market mechanisms (all 4) | 2026-05-27 | PRs #5–10 `4a7555d` |
| Betslip + cashout | 2026-05-26 | `c686641` |
| Binary line DB invariants | 2026-05-26 | `c686641` |
| Hot/cold storage + SSE | 2026-05-26 | `c686641` |
| Settlement engine | 2026-05-26 | `3a1789a` |

---

## Known Technical Debt (index)

Full details + options in `docs/wiki/tech-debt-backlog.md`.

| ID | Item | Priority | Status |
|----|------|---------|--------|
| TD-001 | LMSR individual settlement payouts | High | ✅ done (DD-002, PR #35) |
| TD-002 | Parimutuel per-bettor model | Low | Deferred (not urgent for POC) |
| TD-003 | LMSR subsidy exhaustion guard | — | ✅ done (PR #30) |
| TD-013 | BetPlacementService wallet lock (race condition) | High | ✅ done (PR #44) |
| TD-014 | LMSR positions missing from positions page | High | ✅ done (wave 1) |
| TD-015 | Leaderboard P&L missing CLOB_SELL_CREDIT + fees | Medium | ✅ done (wave 1) |
| TD-016 | Admin API missing category/tags params | Medium | ✅ done (wave 1) |
| TD-017 | Market cancellation service + backoffice action | Medium | ✅ done (wave 2, D2) |
| TD-018 | CLOB settlement pays sold positions as winners | High | ✅ done (PR #42) |
| TD-019 | CLOB sell orders do not reserve contracts | High | ✅ done (PR #46) |
| TD-020 | Admin CLOB orders skip trading-state guards | Medium | ✅ done (wave 2, D3) |
| TD-021 | CLOB order cancellation locking | Medium | ✅ done (wave 2, D4) |
| TD-022 | RuboCop Rails/FilePath offense | Low | ✅ done (wave 1) |
| TD-034 | Settlement & sell-order concurrency idempotency | Medium | Open — needs plan (relates to D2) |
| TD-004 | CLOB cashout | Medium | ✅ done (DD-006, PR #36) |
| TD-005 | Cross-mechanism leaderboard P&L | — | ✅ done (PR #29) |
| TD-006 | E2E browser matrix (Firefox/WebKit) | Low | Deferred |
| TD-007 | Backoffice open-market E2E | — | ✅ done (PR #31) |
| TD-008 | Player positions + execution HTML views | — | ✅ done (PR #29) |
| TD-009 | SQLite ILIKE + jsonb test fidelity gap | — | ✅ resolved (DD-004, PR #33) |
| TD-010 | Binary line trigger not tested in SQLite | — | ✅ resolved (DD-004, PR #33) |
| TD-011 | Market edit form (backoffice) | — | ✅ done (PR #31) |
| TD-012 | Market list pagination | — | ✅ done (PR #29) |

---

## Product / UX Backlog Pointers

UX slices PR A–D are now scheduled in **Wave 5** above (with owners + backend deps).
Detail lives in `docs/wiki/UX_BACKLOG.md`. Remaining un-planned product features
(activity feed, responsible-gaming controls) still need specs/plans from
`docs/product/BACKLOG.md` — author after the **D5** rewrite so they use the `PROD-###` scheme.
