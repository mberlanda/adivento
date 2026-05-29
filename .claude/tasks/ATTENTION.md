# Tasks Requiring Attention or User Answers

Last updated: 2026-05-29

This file is the single index of open items. Check it at the start of each session.
Full tech-debt details + design decision options: `docs/wiki/tech-debt-backlog.md`.
Backend next-steps plan: `docs/superpowers/plans/2026-05-29-backend-next-steps.md`

---

## 🔴 Blocked — Need User Input

_No blocked items. All pending design decisions have been resolved._

---

## 🟡 Ready for Autonomous Work

Recommended order: finish the backend correctness tasks first, then move to the planned UX slices in `docs/wiki/UX_BACKLOG.md`.

| Task | ID | Priority | Plan |
|------|----|----------|------|
| Expose LMSR positions on player positions page | TD-014 | P2 — High | Task 2 in 2026-05-29-backend-next-steps.md |
| Fix leaderboard P&L (CLOB_SELL_CREDIT, LMSR_FEE, CLOB_FEE) | TD-015 | P3 — Medium | Task 3 in 2026-05-29-backend-next-steps.md |
| Admin API: permit category and tags in market params | TD-016 | P4 — Medium | Task 4 in 2026-05-29-backend-next-steps.md |
| MarketCancellationService + backoffice cancel action | TD-017 | P5 — Medium | Task 5 in 2026-05-29-backend-next-steps.md |
| Add admin CLOB order trading-state guards | TD-020 | P3 — Medium | Needs plan |
| Lock CLOB order cancellation consistently | TD-021 | P3 — Medium | Needs plan |
| Clear RuboCop Rails/FilePath offense | TD-022 | P5 — Low | No plan needed |

---

## 🟢 Recently Completed

| Task | Completed | PR / Commit |
|------|-----------|-------------|
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
| TD-013 | BetPlacementService wallet lock (race condition) | High | Open — see plan |
| TD-014 | LMSR positions missing from positions page | High | Open — see plan |
| TD-015 | Leaderboard P&L missing CLOB_SELL_CREDIT + fees | Medium | Open — see plan |
| TD-016 | Admin API missing category/tags params | Medium | Open — see plan |
| TD-017 | Market cancellation service + backoffice action | Medium | Open — see plan |
| TD-018 | CLOB settlement pays sold positions as winners | High | Open — needs plan |
| TD-019 | CLOB sell orders do not reserve contracts | High | Open — needs plan |
| TD-020 | Admin CLOB orders skip trading-state guards | Medium | Open — needs plan |
| TD-021 | CLOB order cancellation locking | Medium | Open — needs plan |
| TD-022 | RuboCop Rails/FilePath offense | Low | Open |
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

| Area | Next action |
|------|-------------|
| UX market browse/detail | Execute PR A in `docs/wiki/UX_BACKLOG.md` |
| UX leaderboard/profile/auth/positions | Execute PR B in `docs/wiki/UX_BACKLOG.md` |
| Settlement explainer | Execute PR C in `docs/wiki/UX_BACKLOG.md` |
| Backoffice dashboard/settle/faucet | Execute PR D in `docs/wiki/UX_BACKLOG.md` |
| Price history, watchlists, resolution notes, activity feed, responsible-gaming controls | Create specs/plans from `docs/product/BACKLOG.md` |
