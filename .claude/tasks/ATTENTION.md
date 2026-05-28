# Tasks Requiring Attention or User Answers

Last updated: 2026-05-28

This file is the single index of open items that either block autonomous work or need a product/priority decision from the user. Check this at the start of each session.

---

## 🔴 Blocked — Need User Input

_(none currently)_

---

## 🟡 Ready for Autonomous Work

- **F-009: Automated market close** — plan at `docs/superpowers/plans/2026-05-28-f009-automated-market-close.md`. Adds `CloseExpiredMarketsJob` + `closed` market status. No blocking decisions.

---

## 🟢 Recently Completed

| Task | Completed | Notes |
|------|-----------|-------|
| F-001 Market taxonomy | 2026-05-27 | PRs #13–15 |
| F-002 Full-text search | 2026-05-27 | PR #16 |
| F-005 User profile | 2026-05-27 | PR #17 |
| F-003 Market detail enrichment | 2026-05-28 | PR #18 `3dd6be1` |
| F-007 Leaderboard | 2026-05-28 | PR #18 `3dd6be1` |
| Quick-bet form (all 4 mechanisms) | 2026-05-28 | PR #18 `3dd6be1` |
| UX polish + rich seeds | 2026-05-28 | PR #18 `3dd6be1` |
| F-006 Market create UX | 2026-05-28 | PR #21 `528e7ba` |
| CLOB/LMSR/parimutuel E2E + side fix | 2026-05-28 | PR #23 `6a61122` |
| E2E Docker Compose + Zeitwerk production fix | 2026-05-28 | PR #26 `490f215` |
| Multi-player settlement E2E (all 4 mechanisms) | 2026-05-28 | PR #25 |

---

## Open Design Decisions

Full options + trade-offs in `docs/wiki/tech-debt-backlog.md` under "Open design decisions".

| Decision | Summary |
|----------|---------|
| DD-001 F-009 automated close | Option A recommended: `CloseExpiredMarketsJob` + `closed` status |
| DD-002 LMSR v2 settlement | Option A recommended: `lmsr_positions` table |
| DD-003 Parimutuel v2 model | Option A (ParimutuelBet) when traffic justifies it |
| DD-004 Test DB adapter | Option B (PostgreSQL) for correctness; currently SQLite |
| DD-005 ADR-0013 duplicate | Fixed: deleted duplicate, marked ADR-0013 accepted |

---

## Known Technical Debt

Full details in `docs/wiki/tech-debt-backlog.md`.

| ID | Item | Priority |
|----|------|---------|
| TD-001 | LMSR individual settlement payouts | High (LMSR settlement broken for payouts) |
| TD-002 | Parimutuel per-bettor model | Low (pool math works; history awkward) |
| TD-003 | LMSR subsidy exhaustion guard | Medium |
| TD-004 | CLOB cashout | Medium |
| TD-005 | Cross-mechanism leaderboard P&L | Low |
| TD-006 | E2E browser matrix (Firefox/WebKit) | Low |
| TD-007 | Backoffice open-market E2E | Low |
| TD-008 | Player positions + execution HTML views | Medium |
