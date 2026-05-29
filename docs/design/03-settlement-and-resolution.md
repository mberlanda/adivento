# 03 · Settlement & Resolution

The wireframe `extra/x-settle` ("How settlement works") makes this user-facing. This doc is the spec behind it. It aligns with `docs/wiki/market-mechanisms.md` and `PRIVATE_PREDICTION_MARKETS.md` (§2.6, §5.6).

## Lifecycle

```
DRAFT → OPEN → CLOSED → (RESOLUTION proposed → DISPUTE window) → SETTLED
                                                              ↘ CANCELLED → refunds
```

| State | Meaning | UI signal |
|-------|---------|-----------|
| Open | accepting bets, prices live | live dot + bet form |
| Closed | `close_at` passed, no new bets (F-009) | "Betting closed" banner |
| Resolution proposed | moderator declares outcome + evidence | "Awaiting settlement" |
| Dispute (optional) | participants can contest | dispute panel |
| Settled | payouts credited, ledger written | settled-outcome banner |
| Cancelled | voided; stakes refunded | refund banner |

## Payout by mechanism
*(shown as four cards in the explainer)*

- **Fixed-odds** — winning bets paid `stake ÷ implied_probability`; the house covered the opposite side. Losing bets pay 0.
- **CLOB** — each winning contract redeems for **1 ADIV**, losing contracts expire at 0; two-pass settlement first cancels open/partial orders and releases reservations, then credits winners.
- **LMSR** — outcome marked, winning shares pay from the maker. **v1 limitation (TD-001):** per-position payout not yet credited — the explainer shows the label, not a number, until the position model lands.
- **Parimutuel** — the winning pool splits the **total pool minus takeout** pro-rata to stake; if no one is on the winning side, all stakes refund.

## Disputes (from PRIVATE_PREDICTION_MARKETS.md §2.6)
States: `OPEN · ACCEPTED · REJECTED · REVERSED`. Any participant opens a dispute with a reason within the window; a **Resolver** reviews evidence and finalizes or reverses. `dispute_comments` thread the discussion.

## Trust model (surface this to users)
- **Append-only ledger** — balances are derived from `ledger_entries`; no silent balance edits.
- **Idempotent settlement** — running it twice never double-credits (`settlement_items` unique per user/outcome).
- **Separation of duties** — market creator ≠ resolver (configurable abuse control).
- **Audit everything** — each transition writes an `audit_event` (before/after state).

## UI hooks
- Market resolution panel → "How does settlement work?" link to `/web/settlement`.
- Settled banner → show winning outcome + payout summary + link to your settled position.
- Backoffice settle screen → two-step confirm showing **# winning bets** and **total credit** before committing (irreversible).

## Acceptance criteria
- [ ] `/web/settlement` explainer page renders the lifecycle, four mechanism cards, dispute states, trust list.
- [ ] Every market detail links to it from resolution details + settled banner.
- [ ] Backoffice settlement requires explicit two-step confirmation and previews payout totals.
