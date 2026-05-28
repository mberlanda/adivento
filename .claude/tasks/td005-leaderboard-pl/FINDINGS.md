# Findings: TD-005 Cross-mechanism Leaderboard P&L

## Not yet started

Key question before starting: verify the exact `entry_type` strings written by:
- `Clob::OrderMatchingService` (fill credits)
- `ParimutuelSettlementService` (payout credits)
- `SettlementService` (fixed-odds payout credits)
- `LmsrSettlementHandler` (currently a stub — v1 writes nothing)

Grep: `grep -rn "entry_type\|PARIMUTUEL\|ORDER_FILL\|BET_WIN\|LMSR" app/services/`
