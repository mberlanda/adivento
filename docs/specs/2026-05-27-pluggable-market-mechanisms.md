# Spec: Pluggable Market Mechanisms

<!-- File location: docs/specs/2026-05-27-pluggable-market-mechanisms.md -->
<!-- Written BEFORE the implementation plan. Describes WHAT, not HOW. -->

## Goal

Operators can choose one of four market mechanisms (Fixed-odds, CLOB, LMSR, Parimutuel) when creating a market, with mechanism-specific pricing, fee configuration, and settlement logic, while sharing the same lifecycle, RBAC, wallet/ledger, and SSE infrastructure.

---

## Definitions

- **Mechanism type**: the trading model that governs price formation, order/bet placement, and settlement for a given market. Stored in `markets.mechanism_type`; immutable once the market is `open`.
- **Fixed-odds**: the operator sets prices; the house underwrites every bet up to a `liability_cap_minor`. Existing model (ADR-0009); unchanged.
- **CLOB (Continuous Limit Order Book)**: traders submit limit orders; a matching engine pairs compatible YES and NO orders by price-time priority. No house position.
- **LMSR (Logarithmic Market Scoring Rule)**: an automated market maker always quotes prices via a cost function. The operator subsidises the market (bounded loss).
- **Parimutuel**: all stakes pool together; the operator deducts a fixed takeout; winnings are paid proportionally from the remaining pool.
- **Contract**: the atomic unit for CLOB and LMSR markets. YES + NO = 100 minor units always. A winning contract pays exactly 100 minor units at settlement.
- **Pool**: the aggregate of all stakes in a parimutuel market, split by outcome.
- **Takeout**: the operator's deduction from the parimutuel pool before payout. Expressed in basis points (`takeout_bps`).
- **Subsidy parameter b**: the LMSR liquidity parameter derived from `liquidity_subsidy_minor`. Higher b → flatter price curve → lower price impact per trade → higher subsidy cost.
- **Spread fee**: the LMSR platform fee collected on each trade as a percentage of the trade cost (`spread_fee_bps`).
- **Taker fee**: the CLOB fee charged only to the order that crosses the spread (`taker_fee_bps`). Maker fee is always 0%.
- **Pricing engine**: the per-mechanism object responsible for computing the current price/probability for each outcome. Returned by `market.pricing_engine`.

---

## Invariants

1. `mechanism_type` must be one of: `fixed_odds`, `clob`, `lmsr`, `parimutuel`. Any other value is rejected.
2. `mechanism_type` is immutable once `market.status` transitions to `open`. A draft market may have its mechanism changed.
3. Exactly one commission configuration is required per mechanism:
   - `fixed_odds`: `fee_bps` present and in [0, 2000]
   - `clob`: `taker_fee_bps` present and in [0, 200]
   - `lmsr`: `liquidity_subsidy_minor` ≥ 1 AND `spread_fee_bps` in [0, 500]
   - `parimutuel`: `takeout_bps` present and in [1000, 3000]
   - Fee fields for other mechanisms are ignored (stored as NULL; not validated).
4. All mechanisms share the same market lifecycle: `draft → open → settled` (or `cancelled`).
5. All mechanisms share the same RBAC: market creation requires `markets.create` permission; settlement requires `markets.settle` permission.
6. All financial transactions (stake, fee, payout, refund) write `LedgerEntry` rows; all state-changing actions write `AuditEvent` rows.
7. The SSE stream at `/sse/markets/:id` is available for all mechanism types; the snapshot payload includes a `mechanism_type` key and mechanism-specific sub-object.
8. `HouseRiskService` is called only for `fixed_odds` markets. It is not invoked for CLOB, LMSR, or parimutuel.
9. `liability_cap_minor` is enforced only for `fixed_odds`. For `lmsr`, the operator's maximum loss is bounded at `b × ln(2)` (binary market); this is computed at market creation and stored as informational metadata, not as a hard block on trades.
10. A market with `mechanism_type = parimutuel` displays implied probability, not fixed price. The displayed odds change with every bet until the pool closes.
11. For parimutuel, `payout = stake × (total_pool_after_takeout / winning_pool)`. If the winning pool is zero (no bets on the winning side), all stakes are refunded.
12. All open CLOB orders are auto-cancelled at settlement; reserved funds are released before payout computation begins.

---

## Section 2a: Market Creation

### Functional Requirements

- FR-2a-1: The backoffice "New Market" form includes a **Mechanism** selector (dropdown): `Fixed-odds | CLOB | LMSR | Parimutuel`.
- FR-2a-2: Selecting a mechanism shows mechanism-specific configuration fields:
  - Fixed-odds: Fee (bps) [existing field], Liability cap [existing field]
  - CLOB: Taker fee (bps)
  - LMSR: Initial subsidy (ADIV minor units), Spread fee (bps)
  - Parimutuel: Takeout (bps)
- FR-2a-3: All mechanism-specific fee fields are validated per Invariant 3 before the market is saved.
- FR-2a-4: `mechanism_type` defaults to `fixed_odds` if not explicitly set (backward compatibility).
- FR-2a-5: Once a market transitions to `open`, the mechanism picker and fee fields are disabled in the edit form; they cannot be changed.
- FR-2a-6: The admin JSON API `POST /admin/markets` accepts `mechanism_type` and mechanism-specific fee fields. Omitting `mechanism_type` defaults to `fixed_odds`.

---

## Section 2b: CLOB Mechanism

### Overview

Traders submit limit orders specifying side (YES/NO), price (1–99 cents), quantity (positive integer contracts), and time-in-force (GTC / IOC / FOK). A matching engine pairs compatible orders by price-time priority. The platform earns `taker_fee_bps` on each fill; the maker pays 0%.

### Functional Requirements

- FR-2b-1: A player can place a limit order on any `open` market with `mechanism_type = clob` via `POST /web/markets/:market_id/orders`.
- FR-2b-2: Order fields: `side` (YES or NO), `price_cents` (1–99 integer), `quantity` (positive integer), `time_in_force` (gtc / ioc / fok, default gtc).
- FR-2b-3: On placement, `price_cents × quantity` minor units are reserved from the player's wallet (`available_minor` decreases, `reserved_minor` increases). No ledger debit is written at this point.
- FR-2b-4: The matching engine runs immediately after order placement. Match condition: a YES bid at price P and a NO bid at price Q where `P + Q >= 100`. Matched price is the resting (maker) order's price.
- FR-2b-5: Partial fills are supported. `Order.filled_quantity` is updated per fill; `Order.status` transitions to `partial` (some filled) or `filled` (fully matched).
- FR-2b-6: On each fill, the taker pays `CLOB_FEE` ledger debit of `(fill_value_minor × taker_fee_bps / 10_000).ceil` minor units. The maker receives an `ORDER_FILL_CREDIT` ledger entry of the full fill value.
- FR-2b-7: Time-in-force semantics: GTC rests indefinitely; IOC cancels unfilled remainder after one matching pass; FOK cancels the entire order if full quantity cannot be filled immediately.
- FR-2b-8: A player can cancel their own open or partial order via `DELETE /web/orders/:id`. All reserved funds for the unfilled portion are released in a single transaction.
- FR-2b-9: Order book depth (`GET /web/markets/:market_id/order_book`) returns top 5 bids (YES, price descending) and top 5 asks (NO, price ascending) with cumulative quantities, last traded price, and spread.
- FR-2b-10: Price display on market show page: best bid, best ask, last traded price, 24h volume. If the order book is empty, display "No orders — spread unavailable".
- FR-2b-11: At settlement, all open and partial orders are auto-cancelled; reserved funds are released before payout. Winning contracts receive 100 minor units each from the settlement pool.
- FR-2b-12: The order book depth snapshot is written to Redis (hot storage) after every matching cycle. The SSE snapshot includes an `order_book` sub-object with the same depth format.

### Ledger entries for CLOB

| entry_type | direction | amount | when |
|------------|-----------|--------|------|
| `ORDER_FILL_STAKE` | debit | `fill_value_minor` | per fill, taker |
| `CLOB_FEE` | debit | `fee_minor` | per fill, taker (when fee > 0) |
| `ORDER_FILL_CREDIT` | credit | `fill_value_minor` | per fill, maker |
| `SETTLEMENT_WIN` | credit | `100 × winning_contracts` | at settlement, winning position holder |

Wallet adjustments (not ledger entries):

| action | wallet effect |
|--------|--------------|
| Order placement | `available_minor -= reservation`, `reserved_minor += reservation` |
| Order cancel / IOC/FOK unfilled | `reserved_minor -= unfilled_reservation`, `available_minor += unfilled_reservation` |
| Fill (taker) | `reserved_minor -= fill_value_minor` |
| Fill (maker) | `reserved_minor -= fill_value_minor` |

---

## Section 2c: LMSR Mechanism

### Overview

An automated market maker always stands ready to trade at algorithmically determined prices. The operator seeds the market with an initial `liquidity_subsidy_minor`, which determines the liquidity parameter `b`. The platform collects `spread_fee_bps` on each trade. Prices always sum to 1 across outcomes.

### Functional Requirements

- FR-2c-1: A player can place a trade on any `open` market with `mechanism_type = lmsr` via `POST /web/markets/:market_id/lmsr_trades`.
- FR-2c-2: Trade fields: `side` (YES or NO), `quantity` (positive integer contracts, can be negative to sell). Minimum quantity is 1.
- FR-2c-3: The liquidity parameter `b` is derived from `liquidity_subsidy_minor`. For a binary market (2 outcomes), `b = liquidity_subsidy_minor / (ln(2) × 100)` so that the operator's worst-case loss equals `liquidity_subsidy_minor` minor units. (`b` is stored on `markets` as `lmsr_b_parameter` — a computed float persisted at open time for audit purposes.)
- FR-2c-4: The current probability for outcome i is `p_i = e^(q_i/b) / (e^(q_YES/b) + e^(q_NO/b))` where `q_i` is the cumulative signed quantity of contracts purchased for outcome i.
- FR-2c-5: The cost of a trade that moves outcome i's quantity from `q_i` to `q_i + delta` is `C(q_after) - C(q_before)` where `C(q) = b × ln(e^(q_YES/b) + e^(q_NO/b))`.
- FR-2c-6: The spread fee is applied on top of the raw trade cost: `total_cost = trade_cost × (1 + spread_fee_bps / 10_000)`. The fee portion is recorded as an `LMSR_FEE` ledger entry.
- FR-2c-7: On trade placement, `total_cost` minor units are debited from the player's wallet. If the trade is a sell (negative quantity), the player receives `|trade_cost|` minor units minus the spread fee.
- FR-2c-8: Price display on market show page: current YES probability (0–100%), current NO probability, cost to buy 1 more YES contract, cost to buy 1 more NO contract.
- FR-2c-9: `LmsrPricingService` is stateless. It receives `(q_YES, q_NO, b)` and returns current prices and trade costs. Quantity state is stored on `markets` as `lmsr_q_yes` and `lmsr_q_no` (two bigint columns, count of net contracts purchased per outcome).
- FR-2c-10: At settlement, the winning side's contracts are paid proportionally from the total pool. Payout per winning contract = `(total_amount_paid_in - subsidy_consumed) / total_winning_contracts`. The subsidy consumed is `C(final_state) - C(initial_state)` over all trades.
- FR-2c-11: SSE snapshot includes `lmsr` sub-object with `yes_probability`, `no_probability`, `cost_per_yes`, `cost_per_no`.

### Ledger entries for LMSR

| entry_type | direction | amount | when |
|------------|-----------|--------|------|
| `LMSR_TRADE_STAKE` | debit | `trade_cost_minor` | on trade buy |
| `LMSR_FEE` | debit | `fee_minor` | on trade (when spread > 0) |
| `LMSR_TRADE_CREDIT` | credit | `|trade_cost_minor|` | on trade sell |
| `LMSR_FEE_SELL` | debit | `fee_minor` | on trade sell |
| `SETTLEMENT_WIN` | credit | `payout_per_contract × contracts` | at settlement, winning side |

---

## Section 2d: Parimutuel Mechanism

### Overview

All stakes for a given outcome go into a pool. The operator deducts `takeout_bps` from the total pool at close. The remainder is divided proportionally among tickets on the winning outcome by stake size. Implied odds shift continuously as bets arrive.

### Functional Requirements

- FR-2d-1: A player can place a bet on any `open` market with `mechanism_type = parimutuel` via `POST /web/markets/:market_id/parimutuel_bets`.
- FR-2d-2: Bet fields: `side` (YES or NO), `stake_minor` (positive integer, minimum 1).
- FR-2d-3: On placement, `stake_minor` is debited from the player's wallet and added to `markets.parimutuel_pool_yes_minor` or `markets.parimutuel_pool_no_minor` (two new bigint columns).
- FR-2d-4: The current implied probability for YES is `pool_yes / (pool_yes + pool_no)`. This is displayed to the player before and after placing the bet, with a disclaimer that it will change as other bets arrive.
- FR-2d-5: At pool close (when the market transitions from `open` to a pre-settlement state), `takeout_minor = total_pool × takeout_bps / 10_000` is computed and recorded as a `PARIMUTUEL_TAKEOUT` debit (operator revenue audit entry).
- FR-2d-6: Settlement: `payout_per_minor_staked = (total_pool_minor - takeout_minor) / winning_pool_minor`. Each winning bettor receives `stake_minor × payout_per_minor_staked` minor units credited as `SETTLEMENT_WIN`.
- FR-2d-7: If `winning_pool_minor = 0` (no bets on the winning side), all stakes on all sides are refunded as `PARIMUTUEL_REFUND` credit entries. Takeout is not collected.
- FR-2d-8: Price display on market show page: pool composition bar (% in YES, % in NO), total pool size in ADIV, and implied probability per outcome. No "odds" field — implied probability is the only price signal.
- FR-2d-9: SSE snapshot includes `parimutuel` sub-object with `pool_yes_minor`, `pool_no_minor`, `total_pool_minor`, `yes_probability`, `takeout_bps`.

### Ledger entries for Parimutuel

| entry_type | direction | amount | when |
|------------|-----------|--------|------|
| `PARIMUTUEL_STAKE` | debit | `stake_minor` | on bet placement |
| `PARIMUTUEL_TAKEOUT` | debit (operator audit) | `takeout_minor` | at pool close |
| `SETTLEMENT_WIN` | credit | `payout_minor` | at settlement, winning bettors |
| `PARIMUTUEL_REFUND` | credit | `stake_minor` | at settlement, if winning pool is zero |

---

## Section 2e: Fixed-Odds (Current — Unchanged)

The fixed-odds mechanism is preserved exactly as specified in ADR-0009 and the existing implementation. `BetPlacementService`, `HouseRiskService`, `BetVoidService`, `BetslipQuoteService`, and `BetslipExecutionService` are not modified.

The only change is that `mechanism_type = "fixed_odds"` is now one value among four in the enum, and the market creation form includes the mechanism picker (defaulting to `fixed_odds` for backward compatibility).

Reference: [ADR-0009](../adr/ADR-0009-fixed-odds-house-liability-model.md)

---

## Section 2f: Shared Concerns

### Market lifecycle

All four mechanisms share the same lifecycle transitions:

| Status | Meaning |
|--------|---------|
| `draft` | Market created; mechanism and fees configured; no trading yet |
| `open` | Trading live; mechanism locked; `mechanism_type` immutable |
| `settled` | Outcome determined; payouts complete |
| `cancelled` | Market voided; all stakes refunded |

`mechanism_type` may be changed while the market is `draft`. Once `open`, the field is locked.

### SettlementService routing

`SettlementService.call(market:, winning_leg:, settled_by:)` dispatches to mechanism-specific handlers:

```
case market.mechanism_type
when "fixed_odds"  -> FixedOddsSettlementHandler
when "clob"        -> ClobSettlementHandler
when "lmsr"        -> LmsrSettlementHandler
when "parimutuel"  -> ParimutuelSettlementService
end
```

All handlers write `SETTLEMENT_WIN` ledger entries and a `market.settle` audit event.

### SSE snapshot shape

The SSE snapshot for any market includes a top-level `mechanism_type` field and a mechanism-specific sub-object. Example for CLOB:

```json
{
  "market_id": 3,
  "mechanism_type": "clob",
  "status": "open",
  "clob": {
    "bids": [...],
    "asks": [...],
    "last_trade_price": 55,
    "spread": 0
  }
}
```

For parimutuel:

```json
{
  "market_id": 7,
  "mechanism_type": "parimutuel",
  "parimutuel": {
    "pool_yes_minor": 40000,
    "pool_no_minor": 60000,
    "total_pool_minor": 100000,
    "yes_probability": 40,
    "takeout_bps": 1500
  }
}
```

For LMSR:

```json
{
  "market_id": 9,
  "mechanism_type": "lmsr",
  "lmsr": {
    "yes_probability": 62,
    "no_probability": 38,
    "cost_per_yes": 72,
    "cost_per_no": 44
  }
}
```

### Mechanism type in API responses

All admin JSON API responses for `GET/POST /admin/markets` and `GET /admin/markets/:id` include:

```json
{
  "mechanism_type": "clob",
  "fee_config": {
    "taker_fee_bps": 70
  }
}
```

`fee_config` contains only the fields relevant to the market's mechanism; null fields are omitted.

### Out of scope for v1

- Cross-mechanism arbitrage detection.
- Migrating a market from one mechanism to another after it is opened.
- CLOB automated market maker / liquidity seeding.
- LMSR combinatorial markets (more than 2 outcomes in this iteration).
- Parimutuel exotic bets (exacta, trifecta).
- Market orders on CLOB (all orders are limit orders).
- Negative maker fee (maker rebate) for CLOB.

---

## Test Requirements

### Market creation
- [ ] Market creation with each of the four `mechanism_type` values succeeds with valid config
- [ ] Market creation with invalid `mechanism_type` returns 422
- [ ] Creating a market with CLOB mechanism and missing `taker_fee_bps` returns 422
- [ ] Creating a market with LMSR mechanism and `liquidity_subsidy_minor = 0` returns 422
- [ ] Creating a market with parimutuel and `takeout_bps = 500` (below 1000) returns 422
- [ ] `mechanism_type` cannot be changed once market is `open`

### CLOB
- [ ] Order placement reserves correct wallet funds
- [ ] Order placement rejected on non-CLOB or non-open market
- [ ] Matching engine pairs YES bid at P and NO bid at Q when P + Q >= 100
- [ ] Partial fill: `filled_quantity` updated, status becomes `partial`, remainder rests
- [ ] Full fill: status becomes `filled`, reservation fully released
- [ ] Taker fee (`CLOB_FEE`) ledger entry written on fill
- [ ] Maker receives `ORDER_FILL_CREDIT` ledger entry
- [ ] GTC order rests after partial fill
- [ ] IOC order: unfilled remainder cancelled after matching pass
- [ ] FOK order: entire order cancelled if full quantity unavailable
- [ ] Order cancellation releases reserved funds atomically
- [ ] Order cancellation rejected if already `filled` or `cancelled`
- [ ] Settlement: all open orders cancelled, winning contracts paid 100 minor units
- [ ] Order book depth snapshot in Redis matches DB state
- [ ] SSE snapshot includes `clob.bids` and `clob.asks`
- [ ] `AuditEvent` written for order.place, order.fill, order.cancel

### LMSR
- [ ] Correct `b` derived from `liquidity_subsidy_minor`
- [ ] `C(q)` cost function returns correct value for known inputs
- [ ] Trade cost delta matches `C(q_after) - C(q_before)`
- [ ] `LMSR_FEE` ledger entry written when `spread_fee_bps > 0`
- [ ] Sell trade credits wallet correctly
- [ ] `lmsr_q_yes` and `lmsr_q_no` updated atomically on each trade
- [ ] SSE snapshot includes `lmsr.yes_probability`
- [ ] Settlement pays winning side proportionally from total pool
- [ ] `AuditEvent` written for each trade

### Parimutuel
- [ ] Bet placement debits wallet and increments pool column atomically
- [ ] Implied probability updates correctly after each bet
- [ ] `takeout_minor` computed correctly at pool close
- [ ] Settlement `SETTLEMENT_WIN` credit matches stake × payout_ratio
- [ ] Zero winning pool triggers `PARIMUTUEL_REFUND` for all bettors
- [ ] SSE snapshot includes `parimutuel.pool_yes_minor` and `parimutuel.yes_probability`
- [ ] `AuditEvent` written for each bet

### Shared
- [ ] `SettlementService` routes to correct handler for each mechanism type
- [ ] `HouseRiskService` not called for CLOB, LMSR, parimutuel markets
- [ ] SSE snapshot includes `mechanism_type` for all four mechanism values
- [ ] Admin API market JSON includes `mechanism_type` and `fee_config`

---

## Out of Scope

- Cross-mechanism arbitrage detection and prevention.
- Mechanism migration after a market is opened.
- CLOB market orders (no price limit).
- LMSR with more than 2 outcomes.
- Parimutuel exotic wagers.
- Automated market maker / liquidity seeding for CLOB cold-start.
- Negative maker fee (maker rebate).
- On-chain settlement or tokenised contracts.
- Real-money wallet integration.
