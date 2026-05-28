# Plan: TD-005 Cross-mechanism Leaderboard P&L

No separate plan file — implementation is small enough to track here.

## Approach

Replace the settled-bets-only aggregation in `Web::LeaderboardController` with a ledger-based aggregation:

```sql
SELECT user_id,
       SUM(CASE WHEN entry_type IN ('BET_WIN_PAYOUT','ORDER_FILL_CREDIT','PARIMUTUEL_PAYOUT','LMSR_PAYOUT') THEN amount_minor ELSE 0 END)
     - SUM(CASE WHEN entry_type IN ('BET_STAKE','ORDER_FILL_STAKE','PARIMUTUEL_STAKE','LMSR_STAKE') THEN amount_minor ELSE 0 END)
       AS net_pl_minor
FROM ledger_entries
GROUP BY user_id
ORDER BY net_pl_minor DESC
LIMIT 50
```

The exact `entry_type` values should be verified against `Catalogs::ActionCatalog` and the actual ledger writes in the services.

## Steps

- [ ] Read `app/controllers/web/leaderboard_controller.rb` — understand current SQL
- [ ] Read `app/domain/catalogs/action_catalog.rb` — verify entry_type constants
- [ ] Grep ledger writes in services to enumerate all payout entry_types
- [ ] Rewrite the aggregation query
- [ ] Update `test/integration/web_leaderboard_test.rb` with a CLOB/parimutuel player
- [ ] Run `bin/rails test` — verify 0 failures, ≥90% coverage
- [ ] Update WORK_LOG + ATTENTION.md
