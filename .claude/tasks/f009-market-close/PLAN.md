# Plan: F-009 Automated Market Close

Full plan: `docs/superpowers/plans/2026-05-28-f009-automated-market-close.md`

Read that file for the complete step-by-step implementation. This file tracks execution status.

## Execution status

- [x] Step 1: Add `closed` to market status enum + migration
- [x] Step 2: `CloseExpiredMarketsJob` — find and close expired markets
- [x] Step 3: Wire job into ActiveJob scheduler or cron (Solid Queue / whenever)
- [x] Step 4: Guard `BetPlacementService` against `closed` status and past `close_at`
- [x] Step 5: Backoffice UI — "Closed — awaiting settlement" banner; settle form for closed markets
- [x] Step 6: SettlementService + backoffice controller accept `open? || closed?`
- [x] Step 7: Tests — 261 runs, 0 failures, 91.02% coverage
- [x] Step 8: Update WORK_LOG + INDEX
