# Tasks Requiring Attention or User Answers

Last updated: 2026-05-28

This file is the single index of open items that either block autonomous work or need a product/priority decision from the user. Check this at the start of each session.

---

## 🔴 Blocked — Need User Input

_(none currently)_

---

## 🟡 Ready for Autonomous Work

### F-007: Leaderboard ✅ DONE (PR #18 merged)
- Public `/web/leaderboard` page, ranked by net P&L
- Nav link, unit tests, E2E tests
- Commit: `d311fa3`

### Quick-bet form ✅ DONE (PR #18)
- Fixed-odds market show page now has a quick-bet form for signed-in players
- Unauthenticated users see a "Sign in to bet" prompt
- `Web::BetsController#create`, unit tests (`web_bets_test.rb`), E2E tests (`quick-bet.spec.js`)
- Commit: `f7e2e6a`

### F-006: Market creation UX (backoffice)
- **Status:** Not started
- **Action:** Backoffice market create form is functional but long. Could add: live mechanism preview, better field grouping, form validation feedback. Medium complexity.

### Faucet admin approval UX
- **Status:** Backend exists (admin approve/reject). Backoffice faucet list and action buttons exist.
- **Gap:** The faucet approval in backoffice may need review. Check if `backoffice/faucet_requests#index` with approve/reject buttons works end-to-end.
- **Action:** Write an E2E test for the admin/moderator faucet approval flow.

### CLOB order placement UI
- **Status:** CLOB backend complete. Web UI for placing orders (limit + market) doesn't exist yet on the customer surface.
- **Action:** Customer-facing order form for CLOB markets. Medium complexity.

### LMSR trade UI
- **Status:** LMSR backend complete. Web UI for placing trades exists at `POST /web/lmsr_trades` but no customer-facing form.
- **Action:** Customer-facing form for LMSR markets.

### Parimutuel bet UI
- **Status:** Parimutuel backend complete. Web UI for placing parimutuel bets at `POST /web/parimutuel_bets` but no customer-facing form.
- **Action:** Customer-facing form for parimutuel markets.

---

## 🟢 Completed (for context)

| Task | Completed | Notes |
|------|-----------|-------|
| F-001 Market taxonomy | 2026-05-27 | PRs #13–15 |
| F-002 Full-text search | 2026-05-27 | PR #16 |
| F-005 User profile | 2026-05-27 | PR #17 |
| F-003 Market detail enrichment | 2026-05-28 | PR #18 merged `3dd6be1` |
| F-007 Leaderboard | 2026-05-28 | PR #18 merged `3dd6be1` |
| Quick-bet form (all mechanisms) | 2026-05-28 | PR #18 merged `3dd6be1` |
| UX polish + rich seeds | 2026-05-28 | PR #18 merged `3dd6be1` |
| Faucet controller unit tests | 2026-05-28 | PR #18 |
| Profile + F-003 E2E tests | 2026-05-28 | PR #18 |
| CLOB order book | 2026-05-27 | PRs #10–12 |
| Pluggable mechanisms | 2026-05-27 | PRs #5–10 |

---

## Known Technical Debt

- LMSR settlement: individual payouts deferred (needs position tracking model `lmsr_realized_loss_minor`)
- `ParimutuelBet` model: per-bettor history not tracked (stakes are via LedgerEntry)
- LMSR subsidy exhaustion check missing
- Cross-mechanism leaderboard aggregation for accurate P&L
