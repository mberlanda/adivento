# Task: TD-005 Cross-mechanism Leaderboard P&L

The public leaderboard (`GET /web/leaderboard` → `Web::LeaderboardController`) currently calculates each player's net P&L by summing settled bets only. This misses:
- CLOB fills: `ORDER_FILL_CREDIT` ledger entries (maker credits from matched orders)
- LMSR payouts: ledger credits from `LmsrSettlementHandler` (once TD-001 is implemented)
- Parimutuel payouts: ledger credits from `ParimutuelSettlementService`
- Fixed-odds payouts already included (via settled bets → `potential_payout_minor`)

The fix is to aggregate all payout ledger entries (not just settled bets) for a complete P&L figure.
