# Spec: CLOB Order Book

<!-- File location: docs/specs/2026-05-27-clob-order-book.md -->
<!-- Written BEFORE the implementation plan. Describes WHAT, not HOW. -->

## Goal
Enable traders to submit limit orders (YES or NO contracts at a price 0–99 cents) on open prediction markets, have compatible orders matched by price-time priority, view order book depth, cancel open orders, hold net positions, and receive $1 per winning contract at settlement.

## Definitions
- **Order**: a trader's instruction to buy a specified quantity of YES or NO contracts at a limit price. An order that rests in the book without being immediately matched is a **maker** order; one that crosses the spread and triggers a fill is a **taker** order.
- **Contract**: the atomic unit of a binary prediction market. YES + NO = $1 always. Buying 10 YES contracts at 30¢ costs $3.00 in reservation; settlement pays $10.00 if YES wins.
- **Order book**: two sorted lists — bids (YES orders, sorted by price descending) and asks (NO orders that are, equivalently, YES sells, sorted by price ascending) — that show available liquidity at each price level.
- **Matching**: pairing a YES bid at price P with a NO bid at price Q when P + Q >= 100. The matched price is the resting order's price (maker price).
- **Fill**: a matched execution record. One order can produce multiple fills (partial fills) if matched against several resting orders at different price levels.
- **Position**: a trader's net number of contracts on a given side of a market. Filled YES orders add to YES position; filled NO orders add to NO position.
- **GTC (Good Till Cancelled)**: order remains in the book until explicitly cancelled or the market settles.
- **IOC (Immediate or Cancel)**: fill as much as possible immediately; cancel the unfilled remainder.
- **FOK (Fill or Kill)**: fill the entire quantity immediately or cancel the entire order.
- **Maker fee**: fee charged to the party whose order was resting in the book when matched (default: 0%).
- **Taker fee**: fee charged to the party whose order crossed the spread and triggered the match (default: 0.70% of fill value).
- **Reserved funds**: wallet funds locked when an order is placed; released on cancellation or fill.
- **Fill value**: `price_cents × quantity` (in cents). For a YES fill of 10 contracts at 30¢: fill_value = 300 minor units.

## Invariants

1. `price_cents` must be an integer in the range [1, 99]. Orders at 0 or 100 are rejected.
2. `quantity` must be a positive integer. Fractional contracts are not supported.
3. `price_cents(YES) + price_cents(NO) >= 100` is the match condition. At 50¢ markets, YES bids ≥ 50 match NO bids ≥ 50.
4. A YES bid at price P and a NO bid at price Q that satisfy P + Q = 100 produce a zero-sum pair: one party wins $1 per contract; the other forfeits their P or Q cents stake.
5. An order can be placed only on a market with `status = open` and `mechanism_type = "clob"`.
6. When an order is placed, `price_cents × quantity` minor units are reserved from the trader's wallet (`wallet.available_minor` decreases, `wallet.reserved_minor` increases). No debit ledger entry is written until fill.
7. On a fill, each filled contract produces: a `BET_STAKE` debit ledger entry for the taker (fill_value minor units minus maker rebate if applicable), and reservation release for the maker.
8. Taker fee is deducted from the taker's fill: `fee_minor = (fill_value_minor * taker_fee_bps / 10_000).ceil`. Net credited to position: `fill_value_minor - fee_minor`.
9. A `CLOB_FEE` debit ledger entry is written for the fee amount when a taker fill occurs.
10. Order cancellation releases all reserved funds for the unfilled portion back to `wallet.available_minor` in a single transaction.
11. An order whose `time_in_force` is `ioc` or `fok` and is not fully filled on placement: for `ioc`, the unfilled remainder is immediately cancelled (funds released); for `fok`, the entire order is cancelled if the full quantity cannot be filled immediately.
12. At market settlement, all open (unfilled) orders are automatically cancelled and reserved funds are released before payout is computed.
13. Settlement pays exactly 100 minor units per winning contract from the platform's escrow (funded by losing-side reservations). Losing contracts pay $0; the reserved stake is forfeited to the settlement pool.
14. `filled_quantity + cancelled_quantity <= quantity` at all times on an Order record.
15. Every order write (placement, fill, cancellation) produces an `AuditEvent`.
16. The order book depth snapshot is written to Redis after every matching cycle (hot-storage extension; cold fallback to DB query if Redis is unavailable).

## API / UI Contract

All admin endpoints require JWT Bearer auth. All web endpoints require session cookie (player role).

### `POST /admin/markets/:market_id/orders`
Place a limit order on behalf of a player (admin-initiated for testing; player self-service via web endpoint).

Request:
```json
{
  "user_id": 42,
  "side": "YES",
  "price_cents": 35,
  "quantity": 10,
  "time_in_force": "GTC"
}
```
Success (201):
```json
{
  "order_id": 7,
  "market_id": 3,
  "side": "YES",
  "price_cents": 35,
  "quantity": 10,
  "filled_quantity": 0,
  "status": "open",
  "time_in_force": "GTC",
  "reserved_minor": 350
}
```
Errors: 422 (invalid price, market not open/clob, insufficient funds).

### `DELETE /admin/orders/:id`
Cancel an open or partially-filled order.

Success (200):
```json
{ "order_id": 7, "status": "cancelled", "released_minor": 350 }
```
Errors: 422 (order already filled or cancelled).

### `POST /web/markets/:market_id/orders`
Player self-service order placement (session auth, player role required).

Request/response shape identical to admin endpoint. Returns 401 if not authenticated, 403 if insufficient role.

### `DELETE /web/orders/:id`
Player self-service cancellation of own order.

Success (200): `{ "order_id": 7, "status": "cancelled", "released_minor": 350 }`
Errors: 404 (not found or not owned), 422 (already filled/cancelled).

### `GET /web/markets/:market_id/order_book`
Returns the current depth snapshot for the market.

Response:
```json
{
  "market_id": 3,
  "bids": [
    { "price_cents": 55, "quantity": 20 },
    { "price_cents": 50, "quantity": 45 }
  ],
  "asks": [
    { "price_cents": 45, "quantity": 15 },
    { "price_cents": 40, "quantity": 30 }
  ],
  "last_trade_price": 55,
  "spread": 0
}
```
`bids` = YES orders sorted by price descending. `asks` = NO orders sorted by price ascending (equivalently, YES sell orders). `spread = best_ask - (100 - best_bid)` — negative spread means crossed book (matching available).

### `GET /web/positions`
Returns the authenticated player's net contract positions across all markets (extended from current betslip positions endpoint to include CLOB positions).

```json
{
  "positions": [
    {
      "market_id": 3,
      "market_question": "Will X happen?",
      "yes_contracts": 10,
      "no_contracts": 0,
      "avg_yes_price_cents": 35,
      "unrealised_value_minor": 650
    }
  ]
}
```

### `GET /sse/markets/:id` (extended)
Existing SSE endpoint extended: the snapshot payload gains an `order_book` key with bids/asks depth (top 5 levels). Format is backward-compatible — clients ignoring `order_book` are unaffected.

## Status Taxonomy

`Order.status` enum:
| value | int | meaning |
|-------|-----|---------|
| open | 0 | resting in book, partially or fully unfilled |
| partial | 1 | some quantity filled, remainder resting |
| filled | 2 | fully matched, no remainder |
| cancelled | 3 | cancelled by trader or auto-cancelled at settlement |

`Order.time_in_force` enum:
| value | int | meaning |
|-------|-----|---------|
| gtc | 0 | Good Till Cancelled — rests in book indefinitely |
| ioc | 1 | Immediate Or Cancel — unfilled remainder cancelled on placement |
| fok | 2 | Fill Or Kill — full quantity must fill immediately or entire order cancelled |

## Accounting / Ledger

| entry_type | direction | amount | when |
|-----------|-----------|--------|------|
| `ORDER_RESERVE` | — | not a ledger entry; wallet balance adjustment only | on order placement: `available_minor -= reservation`, `reserved_minor += reservation` |
| `ORDER_FILL_STAKE` | debit | fill_value_minor for taker | written per fill for the taker |
| `CLOB_FEE` | debit | fee_minor (taker only, when > 0) | written per fill for the taker |
| `ORDER_FILL_CREDIT` | credit | fill_value_minor for maker | written per fill for the maker |
| `ORDER_CANCEL_RELEASE` | — | not a ledger entry; wallet balance adjustment only | on cancellation: `reserved_minor -= unfilled_reservation`, `available_minor += unfilled_reservation` |
| `SETTLEMENT_WIN` | credit | 100 × winning_contracts | written by SettlementService for winning position holder |

`AuditEvent` rows:
| action | target | when |
|--------|--------|------|
| `order.place` | `Order` | on placement |
| `order.fill` | `Order` | on each fill (metadata: fill_quantity, fill_price, counterparty_order_id) |
| `order.cancel` | `Order` | on cancellation (metadata: released_minor, unfilled_quantity) |
| `order.settlement_cancel` | `Order` | auto-cancel at settlement |

## Test Requirements
- [ ] Order placement reserves correct wallet funds (`available_minor` decreases, `reserved_minor` increases)
- [ ] Order placement rejected if market is not `open` or `mechanism_type != "clob"`
- [ ] Order placement rejected if `price_cents` outside [1, 99]
- [ ] Order placement rejected if insufficient wallet funds
- [ ] Matching engine pairs YES bid at P with NO bid at Q when P + Q >= 100, at maker's price
- [ ] Partial fill: order status becomes `partial`, `filled_quantity` updated, remainder rests in book
- [ ] Full fill: order status becomes `filled`, reservation fully released
- [ ] Taker fee deducted on fill: `CLOB_FEE` ledger entry written
- [ ] Maker receives full fill value credit: `ORDER_FILL_CREDIT` ledger entry written
- [ ] GTC order remains in book after partial fill
- [ ] IOC order: unfilled remainder cancelled and funds released after placement cycle
- [ ] FOK order: entire order cancelled if full quantity not immediately available
- [ ] Order cancellation releases reserved funds in a single transaction
- [ ] Order cancellation rejected if order is already `filled` or `cancelled`
- [ ] Settlement: all open orders cancelled, reserved funds released, winning positions paid $1/contract
- [ ] Order book depth snapshot matches resting orders in DB
- [ ] SSE snapshot includes `order_book` key
- [ ] Concurrent order submissions do not produce double-fills (locking test)
- [ ] `AuditEvent` written for every order.place, order.fill, order.cancel

## Out of scope
- Market orders (orders with no price limit).
- Stop orders, trailing stops, bracket orders.
- Automated market maker or liquidity seeding.
- Cross-market spreads or combination orders.
- Negative maker fee (maker rebate).
- On-chain settlement or tokenised contracts.
- Real-money wallet integration.
- Migration of existing `Bet` records to `Order` records (existing bets remain as-is under `fixed_odds` markets).
- `fixed_odds` market deprecation — existing markets and services remain functional.
