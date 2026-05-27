# Tasks Requiring Attention or User Answers

Last updated: 2026-05-28

This file is the single index of open items that either block autonomous work or need a product/priority decision from the user. Check this at the start of each session.

---

## 🔴 Blocked — Need User Input

_(none currently)_

---

## 🟡 Ready for Autonomous Work

### F-006: Market creation UX (backoffice)
- **Status:** Not started
- **Action:** Backoffice market create form is functional but long. Could add: live mechanism preview, better field grouping, form validation feedback. Medium complexity.

---

## 🟢 Completed (for context)

| Task | Completed | Notes |
|------|-----------|-------|
| F-001 Market taxonomy | 2026-05-27 | PRs #13–15 |
| F-002 Full-text search | 2026-05-27 | PR #16 |
| F-005 User profile | 2026-05-27 | PR #17 |
| F-003 Market detail enrichment | 2026-05-28 | PR #18 merged `3dd6be1` |
| F-007 Leaderboard | 2026-05-28 | PR #18 merged `3dd6be1` |
| Quick-bet form (all 4 mechanisms) | 2026-05-28 | PR #18 merged `3dd6be1` |
| UX polish + rich seeds | 2026-05-28 | PR #18 merged `3dd6be1` |
| Faucet controller unit tests | 2026-05-28 | PR #18 |
| Profile + F-003 E2E tests | 2026-05-28 | PR #18 |
| Faucet admin approval E2E tests | 2026-05-28 | PR #19 merged `d9aa8b8` |
| CLOB order book | 2026-05-27 | PRs #10–12 |
| Pluggable mechanisms | 2026-05-27 | PRs #5–10 |

---

## Known Technical Debt

- LMSR settlement: individual payouts deferred (needs position tracking model `lmsr_realized_loss_minor`)
- `ParimutuelBet` model: per-bettor history not tracked (stakes are via LedgerEntry)
- LMSR subsidy exhaustion check missing
- Cross-mechanism leaderboard aggregation for accurate P&L
