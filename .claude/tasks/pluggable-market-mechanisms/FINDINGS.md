# Findings

## Session: 2026-05-27 — Documentation phase

### Architecture decisions made during spec/plan writing

mechanism_type stays as string column (not Rails enum) — schema already has it as string with default "fixed_odds". Avoids DB enum migration.

Per-mechanism fee columns on markets row — nullable columns simpler than a polymorphic join table at this scale.

lmsr_q_yes / lmsr_q_no as bigint on markets — stored directly on market row with SELECT FOR UPDATE. Simpler than a separate lmsr_state table.

No ParimutuelBet model in v1 — individual bettor tracking uses LedgerEntry rows with entry_type="PARIMUTUEL_STAKE" and metadata:{market_id:, side:}. ParimutuelBet model deferred to v2.

b_from_subsidy formula: b = liquidity_subsidy_minor / (ln(2) * 100) — ensures operator worst-case loss for binary market equals exactly liquidity_subsidy_minor. From Hanson (2007).

LMSR subsidy exhaustion not blocked in v1 — known gap. V2 add lmsr_realized_loss_minor column and reject trades exceeding subsidy.

CLOB settlement two-pass: pass 1 cancels open/partial orders and releases reservations; pass 2 credits winning contracts. Prevents race conditions.

SSE via Redis pull: services call MarketSnapshotProjector.project(market) to refresh Redis; SSE controller serves the snapshot. Decouples trading logic from SSE transport.

### Known v2 gaps
- LMSR subsidy exhaustion check and lmsr_realized_loss_minor column
- ParimutuelBet model for per-bettor history
- Cashout extensions for CLOB positions
- Cross-mechanism position aggregation for leaderboard (BACKLOG F-007)
