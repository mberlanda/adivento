# Spec: Betslip + Cashout

<!-- File location: docs/specs/2026-05-26-betslip-cashout.md -->
<!-- Written BEFORE the implementation plan. Describes WHAT, not HOW. -->

## Goal
Enable players to submit multi-item betslips via a quote-then-execute flow with idempotency, and to cashout open positions at a current fair value.

## Definitions
- **BetslipQuote**: time-limited (60s TTL) quote for a list of `{ market_leg_id, stake_minor }` items; holds pre-calculated potential payouts and an `idempotency_key`. Status enum: `pending` (default) → `executed` | `expired`.
- **BetslipExecution**: durable record of executing a quote — contains the `bet_ids` created and execution status (`completed` | `failed`).
- **Position**: a player's open `Bet` (status `open?`) presented together with its `market` and `market_leg` context.
- **CashoutQuote**: current fair-value payout for an open position, computed on demand using the bet's stake and the leg's current `odds_minor`; **not persisted** to the database.
- **CashoutExecution**: closing an open bet at the cashout quote value — voids the bet and credits the net payout to the player's wallet.

## Invariants
1. A `BetslipQuote` expires 60 seconds after creation; executing an expired quote raises `ExpiredQuote` and the wallet is not debited.
2. Idempotency replay: a `POST /web/betslips/quotes` with the same `idempotency_key` and the same canonical payload returns the existing `BetslipQuote` (HTTP 200, replay-safe).
3. Idempotency conflict: a `POST /web/betslips/quotes` with the same `idempotency_key` and a different canonical payload returns HTTP 409 Conflict.
4. Execution is all-or-nothing: if any item's market is not `open?` at execution time, the entire `BetslipExecution` fails, no `Bet` rows are created, the wallet is not debited, and the quote remains `pending` (so a fresh quote can be requested).
5. A `BetslipQuote` can only be executed once; re-executing an `executed` quote raises `AlreadyExecuted`.
6. `CashoutExecution` voids the original `Bet` (status → `voided`) and credits `cashout_net_payout_minor` to the player's wallet in a single transaction.
7. Cashout math is deterministic:
   - `gross_payout_minor = (bet.stake_minor * bet.market_leg.odds_minor / 10_000.0).floor`
   - `fee_minor = (gross_payout_minor * bet.market.fee_bps / 10_000.0).ceil`
   - `net_payout_minor = gross_payout_minor - fee_minor`
8. Every execution writes the appropriate `LedgerEntry` rows and a single `AuditEvent`.
9. Stake debit accounting is owned by `BetPlacementService` (one `BET_STAKE` debit per bet); the betslip layer must not double-debit the wallet.
10. Cashout is only valid for a bet whose status is `open` and whose market is still `open?`; otherwise `InvalidPosition` is raised.

## API / UI Contract

All endpoints below live under `namespace :web` and require a player session cookie (set via `POST /signin`). Responses are JSON.

### `POST /web/betslips/quotes`
Request body:
```json
{
  "items": [
    { "market_leg_id": 12, "stake_minor": 500 },
    { "market_leg_id": 17, "stake_minor": 1000 }
  ],
  "idempotency_key": "client-uuid-v4"
}
```
Success (200 or 201):
```json
{
  "quote_id": 42,
  "items": [
    { "market_leg_id": 12, "stake_minor": 500, "potential_payout_minor": 1000 },
    { "market_leg_id": 17, "stake_minor": 1000, "potential_payout_minor": 1800 }
  ],
  "total_stake_minor": 1500,
  "expires_at": "2026-05-26T12:34:56Z"
}
```
Errors: 409 (idempotency conflict), 422 (invalid item, closed market, unknown leg).

### `POST /web/betslips/execute`
Request body: `{ "quote_id": 42 }`
Success: `{ "execution_id": 7, "bet_ids": [101, 102], "status": "completed" }`
Errors: 422 (`ExpiredQuote`, `AlreadyExecuted`, `ExecutionFailed`).

### `GET /web/betslips/executions/:id`
Returns: `{ "execution_id": 7, "quote_id": 42, "bet_ids": [101, 102], "status": "completed" }` for the current user. 404 if not owned.

### `GET /web/positions`
Returns the player's open bets:
```json
{
  "positions": [
    {
      "bet_id": 101,
      "market_id": 9,
      "market_question": "...",
      "market_leg_id": 12,
      "leg_label": "YES",
      "stake_minor": 500,
      "odds_minor": 20000,
      "potential_payout_minor": 1000,
      "status": "open"
    }
  ]
}
```

### `POST /web/positions/cashout_quotes`
Request body: `{ "bet_id": 101 }`
Success:
```json
{
  "bet_id": 101,
  "gross_payout_minor": 1000,
  "fee_minor": 10,
  "net_payout_minor": 990,
  "expires_at": "2026-05-26T12:35:56Z"
}
```
Errors: 422 (`InvalidPosition`).

### `POST /web/positions/cashout_execute`
Request body: `{ "bet_id": 101 }`
Success: `{ "status": "completed", "credited_minor": 990 }`
Errors: 422 (`InvalidPosition`).

## Status Taxonomy

`BetslipQuote.status` enum:
| value | int | meaning |
|-------|-----|---------|
| pending | 0 | created, not yet executed |
| executed | 1 | execute! completed successfully |
| expired | 2 | TTL passed without execution (informational; set lazily on lookup if useful) |

`BetslipExecution.status` enum:
| value | int | meaning |
|-------|-----|---------|
| completed | 0 | all bets placed |
| failed | 1 | one or more items failed at placement (no bets persisted) |

## Accounting / Ledger
| entry_type | direction | amount | when |
|-----------|-----------|--------|------|
| `BET_STAKE` | debit | per-bet stake_minor | written by `BetPlacementService` for each item during `BetslipExecutionService.execute!` |
| `BET_CASHOUT_PAYOUT` | credit | `net_payout_minor` | `CashoutExecutionService.execute!` |
| `BET_CASHOUT_FEE` | debit | `fee_minor` (only if `> 0`) | `CashoutExecutionService.execute!` |

`AuditEvent` rows:
| action | target | when |
|--------|--------|------|
| `betslip.execute` | `BetslipExecution` | one event per successful execution; metadata includes `quote_id` and `bet_count` |
| `bet.cashout` | `Bet` | one event per cashout; metadata: `{ bet_id, net_payout_minor, fee_minor }` |

## Test Requirements
- [ ] Quote expires after TTL → execute returns 422 with expiry message and wallet unchanged
- [ ] Idempotency replay (same key, same payload) → returns existing quote (200), no duplicate row
- [ ] Idempotency conflict (same key, different stake) → 409
- [ ] All-or-nothing: one item references a non-open market → execution fails, wallet unchanged, no Bet rows created, quote remains pending
- [ ] Cashout: net payout credited to wallet, fee deducted, original bet voided
- [ ] Cashout: `LedgerEntry` rows `BET_CASHOUT_PAYOUT` (credit) and `BET_CASHOUT_FEE` (debit, when fee > 0) written
- [ ] `AuditEvent` `betslip.execute` written per successful execution
- [ ] `AuditEvent` `bet.cashout` written per cashout
- [ ] Cashout on a non-open bet (settled or voided) → `InvalidPosition` (422)
- [ ] Cashout on a bet whose market is no longer open → `InvalidPosition` (422)
- [ ] `GET /web/positions` returns only the current user's open bets

## Out of scope (MVP)
- Partial execution (some items succeed, some fail) — execute is all-or-nothing.
- Multi-currency staking — only `ADIV` is supported.
- Peer-liquidity cashout pricing — pricing is derived from the leg's current `odds_minor` only.
- `CashoutQuote` persistence — quotes are computed on demand and not stored.
- Background expiration sweep for old `BetslipQuote` rows — expiry is checked lazily at execution time.
- HTML rendering of betslip/positions screens — the contract here is JSON only; UI work is a separate plan.
