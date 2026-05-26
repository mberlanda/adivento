<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 005 Plan V1: Betslip and Cashout Architecture

## Context (Current State)
- Current bet flow is single-market only: `POST /markets/:market_id/bets`.
- Execution is synchronous and fixed-odds per leg (`MarketLeg#odds_minor`).
- Risk guard exists at placement time (`HouseRiskService.worst_case_liability`).
- Wallet + ledger currently record `BET_STAKE` debit, but no settlement postings yet.
- SSE exists for market snapshots/settlement status, but not for betslip/cashout lifecycle.

## Problem
We need a production-ready architecture for:
1. Multi-market betslip UX and API contract.
2. Deterministic order execution semantics.
3. Position tracking for exposure and PnL.
4. Cashout pricing (house quote first, peer liquidity optional).
5. Risk controls and bounded liability.
6. Accounting postings with replay-safe idempotency.

## Goals
- Introduce a versioned contract usable by web and mobile clients.
- Keep MVP aligned with existing fixed-odds model and risk engine.
- Add clear extension points for peer liquidity in v2.
- Guarantee exactly-once financial effects under retries and worker replays.

## Non-Goals (MVP)
- Full central limit order book (CLOB) matching engine.
- Cross-user netting for liabilities across peer positions.
- Real-money regulatory accounting changes.

## Domain Additions
1. Betslip entities:
- `betslip_quotes`: ephemeral quote snapshot with expiry.
- `betslip_executions`: persisted execution aggregate.
- `betslip_execution_items`: one row per selected leg/market.

2. Position entities:
- `positions`: materialized by `(user_id, market_id, market_leg_id)`.
- `position_lots` (optional v2): lot-level tracking for precise cashout/realized PnL.

3. Cashout entities:
- `cashout_quotes`: priced exits linked to open positions.
- `cashout_executions`: accepted cashout operations.

4. Idempotency entities:
- `idempotency_records` with unique `(actor_id, endpoint, idempotency_key)`.
- Reusable helper for all write endpoints.

## Betslip UX Contract
1. User selects N items (N >= 1):
- Each item = market + leg + stake.
- MVP type: `single` and `parlay` in the same payload shape.

2. Client flow:
- Build local slip.
- Request server quote (`POST /betslips/quotes`).
- Display quote details, warnings, expiry countdown.
- Execute with idempotency key (`POST /betslips/execute`).
- Track settlement and optional cashout via position endpoints + SSE.

3. Quote expiry:
- House quote TTL: 5-10 seconds (configurable).
- Expired quote must be refreshed before execution.

## API Contract (MVP)

### 1) Quote betslip
`POST /betslips/quotes`

Headers:
- `Authorization: Bearer <jwt>`

Request:
```json
{
  "slip_type": "single",
  "items": [
    { "market_id": 101, "market_leg_id": 1001, "stake_minor": 500 },
    { "market_id": 102, "market_leg_id": 1011, "stake_minor": 750 }
  ],
  "accept_price_drift_bps": 0
}
```

Response `200`:
```json
{
  "quote_id": "q_01J...",
  "expires_at": "2026-05-25T12:00:05Z",
  "slip_type": "single",
  "items": [
    {
      "client_item_id": "0",
      "market_id": 101,
      "market_leg_id": 1001,
      "odds_minor": 5200,
      "stake_minor": 500,
      "fee_minor": 5,
      "net_stake_minor": 495,
      "potential_payout_minor": 260
    }
  ],
  "totals": {
    "gross_stake_minor": 1250,
    "fee_minor": 12,
    "net_stake_minor": 1238,
    "max_payout_minor": 910
  },
  "risk": {
    "post_trade_worst_case_liability_minor": 84000,
    "liability_cap_minor": 100000,
    "within_limits": true
  },
  "warnings": []
}
```

Validation errors `422`:
- market not open
- inactive leg
- stake too small
- insufficient wallet
- quote cannot be produced under risk caps

### 2) Execute betslip
`POST /betslips/execute`

Headers:
- `Authorization: Bearer <jwt>`
- `Idempotency-Key: <uuid>`

Request:
```json
{
  "quote_id": "q_01J...",
  "expected_expires_at": "2026-05-25T12:00:05Z"
}
```

Response `201`:
```json
{
  "execution_id": "bx_01J...",
  "status": "accepted",
  "wallet": {
    "available_minor": 8750,
    "reserved_minor": 1250
  },
  "items": [
    {
      "bet_id": 501,
      "market_id": 101,
      "market_leg_id": 1001,
      "stake_minor": 500,
      "odds_minor": 5200,
      "status": "open"
    }
  ],
  "ledger_refs": ["BET_STAKE", "BET_FEE"],
  "audit_ref": "betslip.execute"
}
```

Conflict `409`:
- quote expired
- quote version mismatch
- idempotency key reused with different payload
- request already in progress

### 3) Get execution
`GET /betslips/executions/:id`

Response includes items + derived status (`accepted`, `partially_settled`, `settled`, `voided`).

### 4) List positions
`GET /positions`

Query:
- `market_id` optional
- `status` in `open|closed`

Response includes:
- `exposure_minor`
- `max_payout_minor`
- `avg_odds_minor`
- `realized_pnl_minor`
- `unrealized_pnl_minor`
- `cashout_eligible`

### 5) Cashout quote (house)
`POST /positions/cashout_quotes`

Request:
```json
{
  "position_ids": [9001, 9002],
  "quote_source": "house",
  "slippage_bps": 50
}
```

Response:
- `cashout_quote_id`
- `expires_at`
- `gross_value_minor`
- `fee_minor`
- `net_value_minor`
- `reason_codes` (if reduced/rejected)

### 6) Cashout execute
`POST /positions/cashout_execute`

Headers:
- `Idempotency-Key`

Request:
```json
{
  "cashout_quote_id": "cq_01J..."
}
```

Response `201`:
- `cashout_execution_id`
- settled legs/quantities
- wallet deltas
- ledger refs (`CASHOUT_PAYOUT`, `CASHOUT_FEE`, `POSITION_CLOSE`)

## Order Execution Semantics
1. Quote-time checks:
- Market status and leg activeness.
- Stake constraints and wallet spendability.
- Post-trade liability cap simulation (existing risk service).

2. Execute-time checks (must re-validate):
- Quote not expired.
- Market and odds version unchanged OR within allowed drift.
- Wallet still sufficient.
- Liability still below cap with all accepted items.

3. Atomicity model:
- MVP default: `all_or_nothing` execution for multi-item slip.
- Optional flag (v2): `allow_partial_fill` with explicit per-item statuses.

4. Isolation:
- Use DB transaction with row locks on affected wallet and markets.
- Deterministic lock order: wallet -> markets sorted by id -> market_legs sorted by id.

5. Failure semantics:
- Any failed re-check rolls back full execution (MVP).
- Return typed error code + human-safe message.

## Position Tracking
1. Position update on bet placement:
- Increase exposure for `(user, market, leg)`.
- Recompute weighted average odds.
- Update max payout and unrealized PnL snapshot fields.

2. Position update on settlement/cashout:
- Move quantities/exposure from open to closed.
- Increment realized PnL.
- Keep immutable bet-level audit trail.

3. Rebuild capability:
- Nightly or on-demand recomputation from bets/ledger for reconciliation.

## Cashout Pricing Architecture

### Option A: House quote (MVP default)
Formula baseline:
- `fair_value_minor = win_probability * payout_if_win_minor`
- `house_value_minor = fair_value_minor - spread_minor - fee_minor`

Pricing inputs:
- current leg odds/probability
- remaining time to close
- volatility/risk multiplier
- house liability pressure adjustment

Controls:
- min and max haircut bps
- max cashout amount per position and per user/day
- circuit breaker if price feed stale

### Option B: Peer liquidity (v2)
1. Add lightweight order intents:
- users post `cashout_bid` / `cashout_ask` by market-leg.

2. Matching policy:
- price-time priority
- house as fallback liquidity provider

3. Hybrid quote endpoint:
- `quote_source = house|peer|best`
- `best` chooses peer if executable size and better net value; else house.

## Risk Controls
1. Pre-trade:
- existing liability cap per market
- max stake per bet and per slip
- max open exposure per user and per market

2. Real-time guardrails:
- market suspension flag blocks execution and cashout
- stale quote detector
- rate-limit execute/cashout endpoints

3. Post-trade controls:
- exposure concentration alerts
- risk dashboard extension (`GET /admin/markets/:id/risk` remains source)
- kill-switch to disable cashout globally or per market

## Accounting and Ledger Entries

### Placement (MVP)
Per bet item:
- `BET_STAKE` debit user wallet available
- `BET_RESERVED` credit user reserved (or synthetic reserve tracking until full double-entry migration)
- `BET_FEE` credit system revenue account (or explicit fee ledger metadata)

### Settlement
Winner:
- `BET_SETTLE_PAYOUT` credit user available
- `BET_SETTLE_RELEASE` debit reserve

Loser:
- `BET_SETTLE_LOSS` debit reserve to system market escrow

Void/cancel:
- `BET_VOID_RELEASE` credit user available
- reverse fee if policy requires

### Cashout
- `CASHOUT_PAYOUT` credit user available
- `CASHOUT_CLOSE_POSITION` debit reserve/exposure bucket
- `CASHOUT_FEE` credit system revenue

Invariant targets:
- no negative `wallet.available_minor`
- no negative reserved for user accounts
- one settlement/cashout posting set per reference operation

## Idempotency Design
1. HTTP level:
- Require `Idempotency-Key` on all mutating financial endpoints.
- Key scope: `(user_id, endpoint, idempotency_key)`.

2. Request hashing:
- Store SHA256 of normalized request payload.
- Same key + different hash => `409 IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST`.

3. Status lifecycle:
- `IN_PROGRESS`, `COMPLETED`, `FAILED`.
- `COMPLETED` returns original status/body.
- `IN_PROGRESS` returns `409 REQUEST_ALREADY_IN_PROGRESS`.

4. Ledger-level dedupe:
- Unique reference constraints by transaction type + bet/cashout id.
- Prevent duplicate postings from retries/worker restarts.

## SSE / Realtime Events
Add versioned events:
- `betslip.execution.accepted.v1`
- `position.updated.v1`
- `cashout.quote.expired.v1`
- `cashout.execution.completed.v1`

Publish to per-user stream and market stream.

## Delivery Plan (MVP -> V2)

### Phase 1 (MVP-A): Multi-market betslip with house quote and execute
1. Add quote/execution models + migrations.
2. Implement `BetslipQuoteService` and `BetslipExecuteService`.
3. Add endpoints:
- `POST /betslips/quotes`
- `POST /betslips/execute`
- `GET /betslips/executions/:id`
4. Add idempotency table + concern.
5. Keep execution mode `all_or_nothing`.

### Phase 2 (MVP-B): Position and cashout (house only)
1. Add `positions` projection and updater service.
2. Add cashout quote/execute services.
3. Add endpoints:
- `GET /positions`
- `POST /positions/cashout_quotes`
- `POST /positions/cashout_execute`
4. Add risk limits and kill-switch configuration.

### Phase 3 (Hardening): Settlement-accounting completion
1. Implement bet settlement postings (win/loss/void).
2. Add reconciliation queries/jobs.
3. Add replay-safe worker behavior with ledger dedupe.
4. Extend admin risk endpoint with cashout liabilities.

### Phase 4 (V2): Peer liquidity cashout
1. Add cashout intent book tables.
2. Add matching service and partial-fill semantics.
3. Add hybrid quote source (`best`).
4. Add market depth endpoint and event feed.

## Concrete Endpoint Summary
- `POST /betslips/quotes`
- `POST /betslips/execute`
- `GET /betslips/executions/:id`
- `GET /positions`
- `POST /positions/cashout_quotes`
- `POST /positions/cashout_execute`
- v2: `GET /markets/:market_id/cashout_book`
- v2: `POST /markets/:market_id/cashout_intents`
- v2: `DELETE /markets/:market_id/cashout_intents/:id`

## Test Plan

### Unit tests
1. `test/services/betslip_quote_service_test.rb`
- computes totals and fees correctly for multi-item slip
- rejects inactive market/leg
- enforces quote TTL and drift policy metadata

2. `test/services/betslip_execute_service_test.rb`
- executes all items atomically
- rolls back all items if one fails risk re-check
- enforces wallet/risk limits and lock ordering assumptions

3. `test/services/position_projection_service_test.rb`
- weighted avg odds and exposure updates
- settlement and cashout transitions update realized/unrealized fields

4. `test/services/cashout_pricing_service_test.rb`
- house quote deterministic for given odds and config
- rejects stale odds input
- applies spread/fee bounds

5. `test/services/idempotency_service_test.rb`
- same key same request returns stored response
- same key different hash returns conflict
- in-progress duplicate returns conflict

### Integration tests
1. `test/integration/betslips_test.rb`
- authenticated user can quote and execute multi-item slip
- insufficient balance returns `422`
- expired quote returns `409`
- duplicate execute with same idempotency key returns same response

2. `test/integration/positions_test.rb`
- positions reflect newly executed betslip items
- filtering by market/status works

3. `test/integration/cashout_test.rb`
- quote + execute cashout credits wallet and closes exposure
- idempotent cashout execute is replay-safe
- suspended market blocks cashout

4. `test/integration/admin_risk_test.rb`
- risk endpoint includes exposure and cashout-adjusted liability fields

### Accounting integrity tests
1. `test/services/ledger_reconciliation_service_test.rb`
- no duplicate settlement postings
- debits and credits balanced per transaction
- no negative available balances after execute/cashout/settle scenarios

## Acceptance Criteria
- Multi-market betslip quote/execute works with deterministic all-or-nothing semantics.
- Position API shows user exposure and PnL snapshots.
- House cashout quote/execute works with bounded risk controls.
- Financial writes are idempotent at API and ledger layers.
- Settlement and cashout postings are replay-safe and auditable.
- Full suite passes with coverage >= 90%.

## Open Questions
1. Should MVP reserve stake in `wallet.reserved_minor` immediately, or keep current available-only model until settlement ledger migration lands?
2. Do we require partial fill support before mobile launch, or can we ship all-or-nothing first?
3. Should cashout pricing read directly from `market_legs.odds_minor` in MVP, or from a dedicated pricing feed abstraction from day one?
