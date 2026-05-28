# Task: F-009 Automated Market Close

Implement automatic closing of markets when their `close_at` datetime passes.
The `close_at` field already exists on markets (added in F-003). Currently nothing happens when it passes — markets remain `open` and still accept bets past their intended deadline.

The plan adds a new `closed` market status, a `CloseExpiredMarketsJob` background job, and a bet-placement guard so that closed markets reject new bets. The backoffice UI should reflect the new status. Settlement (marking a winner) remains a manual operator action after closing.

Full implementation plan: `docs/superpowers/plans/2026-05-28-f009-automated-market-close.md`
