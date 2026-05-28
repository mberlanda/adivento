# Tasks Requiring Attention or User Answers

Last updated: 2026-05-28

This file is the single index of open items. Check it at the start of each session.
Full tech-debt details + design decision options: `docs/wiki/tech-debt-backlog.md`.

---

## 🔴 Blocked — Need User Input

### DD-002 · LMSR v2 settlement payout model
**Blocks:** TD-001 (LMSR payouts currently non-functional for players)
**Options:** See `docs/wiki/tech-debt-backlog.md` → DD-002
- A: `lmsr_positions` table (recommended)
- B: Replay ledger entries
- C: Re-use `bets` table with `contracts` field

### DD-004 · Test DB adapter (SQLite → PostgreSQL)
**Blocks:** TD-009/TD-010 (trigger + jsonb gaps only caught in CI, not locally)
**Options:** See `docs/wiki/tech-debt-backlog.md` → DD-004
- A: Keep SQLite (current — fast, misses PG-specific behaviour)
- B: Switch to PostgreSQL (recommended — matches production)
- C: Dual adapter

### DD-006 · CLOB cashout mechanism
**Blocks:** TD-004 (CLOB players cannot exit before settlement)
**Options:** See `docs/wiki/tech-debt-backlog.md` → TD-004
- A: Sell limit order on book
- B: Operator buyback at mid-price
- C: No cashout — hold to settlement (current)

---

## 🟡 Ready for Autonomous Work

| Task | Notes |
|------|-------|
| F-016 / TD-003 LMSR subsidy exhaustion guard | Add `lmsr_realized_loss_minor` to markets + guard in `LmsrTradeService` |
| TD-007 Backoffice open-market E2E | Single Playwright test; requires Docker E2E stack |
| TD-011 Market edit form (backoffice) | Standard Rails edit/update form — decision on edit scope still open (see DD-007) |

---

## 🟢 Recently Completed

| Task | Completed | PR / Commit |
|------|-----------|-------------|
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

| ID | Item | Priority | Blocked by |
|----|------|---------|------------|
| TD-001 | LMSR individual settlement payouts | High | DD-002 |
| TD-002 | Parimutuel per-bettor model | Low | — |
| TD-003 | LMSR subsidy exhaustion guard | Medium | — |
| TD-004 | CLOB cashout | Medium | DD-006 |
| TD-005 | Cross-mechanism leaderboard P&L | ✅ done | — |
| TD-006 | E2E browser matrix (Firefox/WebKit) | Low | — |
| TD-007 | Backoffice open-market E2E | Low | — |
| TD-008 | Player positions + execution HTML views | ✅ done | — |
| TD-009 | SQLite ILIKE + jsonb test fidelity gap | Medium | DD-004 |
| TD-010 | Binary line trigger not tested in SQLite | Medium | DD-004 |
| TD-011 | Market edit form (backoffice) | Low | — |
| TD-012 | Market list pagination | ✅ done | — |
