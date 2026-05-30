# Spec: Cross-Mechanism Market Cancellation (D2)

<!-- Decision D2-TODO-001. Recommended option: full cross-mechanism atomic cancellation/refund service. -->
<!-- Closes TD-017. Sources: synthesis Cluster 6, security-trust.md, market-mechanics.md. -->

## Goal
An operator can cancel/void a non-settled market through the backoffice, atomically refunding every participant across all four mechanisms, releasing all reservations, writing audit + ledger entries, and transitioning the market to `cancelled`.

## Definitions
- **Cancellation**: an operator action that voids a market that should not (or cannot) be settled — bad rules, a cancelled real-world event, or an operator error. It returns participants to their pre-market cash position as nearly as the ledger allows.
- **Refundable participant**: any user with funds committed to the market — an open fixed-odds bet, a CLOB reservation or filled position, an LMSR position, or a parimutuel stake.
- **Make-whole**: refund equals the cash the participant put into the market for that mechanism.

## Background / current state
- `Market` status enum already includes `cancelled: 3` (`app/models/market.rb:5`), but **no `MarketCancellationService` and no cancel route/action exist** (TD-017). `SettlementService` refuses anything but `open`/`closed`.
- Refund precedent exists: `ParimutuelSettlementService#refund_all!` refunds `PARIMUTUEL_STAKE` ledger entries; `ClobSettlementHandler` Pass 1 releases open-order reservations. This spec generalizes those into one cancellation service.

## Status Taxonomy
Uses existing `markets.status` value `cancelled`. Bets transition to the existing `voided` status. LMSR positions are zeroed (`contracts: 0`) and marked refunded.

## Refund policy (per mechanism)
All refunds credit the user's wallet under a row lock and write a `MARKET_CANCEL_REFUND` ledger entry (`direction: credit`) with metadata `{ market_id:, mechanism:, source: }`.

1. **fixed_odds** — for each `open` bet: refund `stake_minor`; set bet `status: :voided`. (The full stake is returned, including the fee portion, since the market never resolved.)
2. **parimutuel** — for each `PARIMUTUEL_STAKE` ledger entry in the market: refund `amount_minor`; reset `parimutuel_pool_yes_minor`/`parimutuel_pool_no_minor` to 0. (Mirrors the existing zero-winning-pool refund path.)
3. **lmsr** — for each user, refund the total LMSR cost they paid: sum of `LMSR_TRADE_STAKE` debits attributed to the market (attribute via the `lmsr_trade.place` AuditEvents for the market when `LMSR_TRADE_STAKE` metadata lacks `market_id` — see ARCH-005/TD note). Zero each `LmsrPosition` for the market. Fees (`LMSR_FEE`) are **not** refunded.
4. **clob** — two parts:
   a. **Open/partial orders**: cancel them and release `reserved_minor` (exactly the existing `ClobSettlementHandler` Pass 1 logic).
   b. **Filled positions**: refund each user their **net cash outlay** = `Σ(ORDER_FILL_STAKE debits) − Σ(CLOB_SELL_CREDIT credits)` for the market. Net buyers receive a refund; net sellers (who already extracted cash) are clawed back the same amount, floored at their available balance with any shortfall recorded in the cancellation AuditEvent metadata as `clawback_shortfall_minor`. `CLOB_FEE` is not refunded.

> **Design note (implementation ordering):** parts 1–3 are unambiguous. CLOB part (4b) depends on the cash-vs-position ledger taxonomy (TD-023); the net-cash rule above is conservation-correct under the current entry types but has the net-seller clawback edge. Implement fixed_odds, parimutuel, and lmsr first (Tasks 2–4 of the plan), then CLOB (Task 5) behind the same service.

## Invariants
1. Only an `open` or `closed` market can be cancelled; any other status raises `MarketCancellationService::InvalidCancellation` and changes nothing.
2. The whole operation is atomic: a failure in any mechanism path rolls back all refunds and the status change.
3. Idempotency: the market row is locked at the start; a second concurrent or repeated cancellation of the same market finds it already `cancelled` and raises `InvalidCancellation` without double-refunding.
4. Every wallet credit/debit happens under a `wallet.lock!`.
5. Every refund writes one `MARKET_CANCEL_REFUND` ledger entry; the operation writes one `market.cancel` AuditEvent with a required `reason` and per-mechanism refund totals in metadata.
6. After success the market is `cancelled`, all its orders are `cancelled` or `filled` (no `open`/`partial` remain), all its bets are `voided` or already terminal, and all its `lmsr_positions` have `contracts: 0`.
7. Conservation: for fixed_odds/parimutuel/lmsr, total credited refunds equal total committed stakes/costs for the market.

## API / UI Contract
**Service** — `MarketCancellationService.call(market:, actor:, reason:)`
- Returns a `Result` struct `{ success?, refunded_total_minor, errors }`.

**Backoffice (HTML)** — `POST /backoffice/markets/:id/cancel`
- Permission: `market.cancel` (new permission; granted to admin by default, **not** moderator — see security-trust SEC-004 direction).
- Params: `reason` (required, min 10 chars).
- Success → redirect to market page, notice "Market cancelled — N refunds issued". Failure → redirect with alert.
- The settle and cancel actions are mutually exclusive in the UI (cancel only shown for `open`/`closed` markets).

**Admin (JSON)** — `POST /admin/markets/:id/cancel` (optional, parity with settle) — same params, returns `{ id, status, refunded_total_minor }`.

## Accounting / Ledger
| entry_type | direction | when |
|-----------|-----------|------|
| `MARKET_CANCEL_REFUND` | credit | each fixed_odds stake, parimutuel stake, lmsr cost, and CLOB net-buyer refund |
| `MARKET_CANCEL_CLAWBACK` | debit | each CLOB net-seller clawback (floored at available balance) |

AuditEvents: one `market.cancel` (actor, reason, metadata: per-mechanism totals, refund count, any `clawback_shortfall_minor`). Existing per-refund audit is optional; the market-level event is required.

## Test Requirements
- [ ] Cancelling a draft/settled/cancelled market raises and changes nothing.
- [ ] fixed_odds: each open bet's stake is refunded and the bet is voided; conservation holds.
- [ ] parimutuel: every stake refunded; pools reset to 0; conservation holds.
- [ ] lmsr: each trader's cost refunded; positions zeroed.
- [ ] clob: open orders cancelled + reservations released; net buyers refunded; a net seller is clawed back; shortfall recorded when balance insufficient.
- [ ] Repeated cancellation of the same market does not double-refund (idempotency).
- [ ] One `market.cancel` AuditEvent with the reason + totals is written.
- [ ] Backoffice cancel requires a reason and a `market.cancel` permission; moderator without the grant is forbidden.

## Out of scope
- Partial cancellation (cancelling individual bets/orders) — use existing void/cancel endpoints.
- Re-opening a cancelled market.
- Resolving the broader CLOB cash-vs-position ledger taxonomy (TD-023); this spec works within the current entry types and documents the clawback edge.
- Operator/house accounting for un-refunded fees.
