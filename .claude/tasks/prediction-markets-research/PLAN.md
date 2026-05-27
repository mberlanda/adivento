# Plan: Align Adivento with Real Prediction Market Mechanics

This plan covers the ADR, spec, and implementation tasks needed to evolve Adivento from its current fixed-odds bookmaker model toward a genuine commission-only CLOB-style prediction market.

Each task is independent unless noted. The research phase (this session) is complete.

---

## Phase 0: Research (completed)

- [x] Web research on CLOB, LMSR, Parimutuel, Fixed-odds mechanics
- [x] Find ≥6 authoritative references (arXiv, SSRN, official docs)
- [x] Document findings in `.claude/tasks/prediction-markets-research/FINDINGS.md`
- [x] Update `docs/prediction-markets-mechanics.md` with formal References section and new nuances
- [x] Create this task artifact

---

## Phase 1: Architecture Decision (ADR)

- [ ] Write ADR-0013: Migration from Fixed-Odds House Model to CLOB Exchange Model
  - Decision: adopt commission-only CLOB with no house directional position
  - Consequences: `liability_cap_minor` becomes irrelevant; `HouseRiskService` is retired
  - Alternatives considered: keep bookmaker model, use LMSR/AMM
  - File: `docs/adr/ADR-0013-clob-exchange-model.md`

---

## Phase 2: Spec — Order Book Data Model

- [ ] Write spec: `docs/specs/YYYY-MM-DD-order-book-model.md`
  - `orders` table: `(id, market_id, user_id, side: yes|no, price_minor: integer 0–10000, quantity_minor: integer, status: open|filled|cancelled|expired, filled_quantity_minor, expires_at, created_at)`
  - `trades` table: `(id, market_id, maker_order_id, taker_order_id, price_minor, quantity_minor, taker_fee_minor, created_at)` — replaces current `bets` table or sits alongside it
  - Binary invariant: `YES price + NO price = 10_000` always (complementary shares)
  - Tick size: 1 basis point (price_minor range 1–9999)

---

## Phase 3: Spec — Matching Engine

- [ ] Write spec: `docs/specs/YYYY-MM-DD-matching-engine.md`
  - Match condition: `bid_yes_price_minor + bid_no_price_minor >= 10_000`
  - Equivalently: a YES buyer at 6000 matches a NO buyer at 4000 (they together pay 10_000 per contract)
  - Price-time priority: best price first, then FIFO within same price
  - Partial fill support: order quantity reduced, remainder stays on book
  - Cancellation: user may cancel any open order before fill
  - Settlement: on market close, winning side receives `quantity_minor` units at face value; losing side receives 0

---

## Phase 4: Spec — Fee Model

- [ ] Write spec or update ADR-0013 with fee formula
  - Taker fee: `fee_minor = round(fee_rate_bps * quantity_minor * price_minor * (10_000 - price_minor) / 10_000^2)`
    - Equivalent to Kalshi's `0.07 × P × (1 − P)` pattern
    - At P=0.50 and 100 contracts of 100 minor each: fee ≈ 1.75% of notional
  - Maker fee: 0 (or small rebate for deep-liquidity markets)
  - Platform earns fee on every taker fill; no directional exposure

---

## Phase 5: Implementation — Database

- [ ] Migration: create `orders` table (see Phase 2 spec)
- [ ] Migration: create `trades` table
- [ ] Migration: add `order_id` foreign key to existing `bets` table (if keeping bets as legacy read path) OR deprecate `bets` in favour of `trades`
- [ ] Model: `Order` with scopes `open`, `for_market`, `bids_yes`, `bids_no`
- [ ] Model: `Trade` with associations to `Order` (maker/taker) and `Market`

---

## Phase 6: Implementation — Matching Engine Service

- [ ] `MatchingEngineService.call(order)` — find counterparty, create trade, update order quantities, calculate fee
- [ ] Must be wrapped in a DB transaction with row-level locking on counterparty orders
- [ ] Unit tests: exact fills, partial fills, no-match (order rests on book), cancellation
- [ ] Integration test: two users place complementary orders, trade is created, both wallets adjusted

---

## Phase 7: Implementation — Settlement

- [ ] Update `SettlementService` to handle `Trade` records instead of (or alongside) `Bet` records
- [ ] Winning side: credit `quantity_minor` to wallet; losing side: no credit (stake already committed at order time)
- [ ] Handle partial fills at settlement: unfilled open orders must be voided and stake returned

---

## Phase 8: Implementation — Admin + SSE Updates

- [ ] Admin controller: `admin/orders_controller.rb` (list, cancel)
- [ ] Remove or archive `HouseRiskService` (no longer needed — no house position)
- [ ] SSE: push order book depth updates on new order/trade events
- [ ] Update `MarketLeg` to remove `liability_cap_minor` column (or keep for backward compat)

---

## Phase 9: Testing and Documentation

- [ ] Integration tests: order placement, matching, settlement, cancellation
- [ ] Coverage check: `bin/rails test` must pass at 90%+ threshold
- [ ] Update `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` status table
- [ ] Update `docs/plans/ITERATION_005_MASTER_TODO_TREE.md` (or successor)

---

## Notes

- Phases 1–4 are documentation-only and can be done without touching production code.
- Phase 5–7 are the core data model and service changes. This is the highest-risk phase.
- Phase 8 is cleanup and frontend plumbing.
- The current `BetPlacementService` + `SettlementService` can coexist with the new engine during transition; run both on separate market types if needed.
- Cold-start liquidity remains an open problem: without initial orders on the book, new markets have no prices. Options: seed orders from operator account, use LMSR as fallback for illiquid markets, or accept thin markets initially.
