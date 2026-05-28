# Plan: F-009 Automated Market Close

Full plan: `docs/superpowers/plans/2026-05-28-f009-automated-market-close.md`

Read that file for the complete step-by-step implementation. This file tracks execution status.

## Execution status

- [ ] Step 1: Add `closed` to market status enum + migration
- [ ] Step 2: `CloseExpiredMarketsJob` — find and close expired markets
- [ ] Step 3: Wire job into ActiveJob scheduler or cron (Solid Queue / whenever)
- [ ] Step 4: Guard `BetPlacementService` and CLOB/LMSR/parimutuel services against `closed` status
- [ ] Step 5: Backoffice UI — show `closed` status badge; disable open/settle actions when closed
- [ ] Step 6: Admin API — `status: closed` in market responses
- [ ] Step 7: Tests — unit (job), integration (guard), E2E (market shows closed state)
- [ ] Step 8: Update WORK_LOG + INDEX
