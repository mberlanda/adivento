# ADR-0013: Pluggable Market Mechanisms

## Status
Proposed — partially supersedes ADR-0009 (fixed-odds remains valid as one of four options).

---

## Context

Adivento was built with a fixed-odds house underwriting model (ADR-0009): the operator sets odds, caps liability with `liability_cap_minor`, and earns a margin via `fee_bps`. This model mirrors traditional bookmakers and is appropriate for a first POC, but it does not represent how real prediction markets work.

Real prediction market platforms use three structurally distinct mechanisms:

1. **CLOB (Continuous Limit Order Book)** — used by Kalshi and Polymarket. Traders post limit orders; a matching engine pairs compatible orders by price-time priority. The platform takes no directional positions and earns only a taker commission (~0.07%–1.80%).
2. **LMSR / AMM (Logarithmic Market Scoring Rule)** — used by Augur and Manifold. An automated market maker always stands ready to trade. The operator subsidises the market (bounded loss at `b · ln(n)`) and collects a spread fee on each trade.
3. **Parimutuel** — used in horse racing and partially by PredictIt. All stakes pool together; the operator deducts a fixed takeout (10–30%), and winnings are distributed proportionally from the pool.

Operators who want to showcase the differences between prediction market models — or who want to tailor the mechanism to their audience's liquidity profile and risk appetite — cannot do so if the platform supports only one mechanism. A CLOB requires market makers to seed liquidity; an LMSR guarantees liquidity at subsidy cost; a parimutuel is simple and commission-certain.

The `markets.mechanism_type` column already exists in the schema (currently constrained to `"fixed_odds"`). Extending it is the natural place for this branching.

---

## Decision

Support four market mechanisms as first-class choices, selected by the operator at market creation time. The mechanism is stored in `markets.mechanism_type` and is **immutable once the market moves to `open` status**.

### Mechanism enumeration

| Value | Model | Platform analogue |
|-------|-------|-------------------|
| `fixed_odds` | House underwriting, risk-capped | Traditional bookmakers |
| `clob` | Limit order book, price-time priority | Kalshi, Polymarket |
| `lmsr` | AMM / cost-function pricing | Augur, Manifold |
| `parimutuel` | Pool-share, post-takeout payout | Horse racing, PredictIt |

### Per-mechanism commission configuration (all stored on `markets` row)

| Mechanism | Revenue field(s) | Constraint |
|-----------|-----------------|------------|
| `fixed_odds` | `fee_bps` (existing) | 0–2000 bps |
| `clob` | `taker_fee_bps` (new integer column) | 0–200 bps; maker always 0% |
| `lmsr` | `liquidity_subsidy_minor` (new bigint) + `spread_fee_bps` (new integer) | subsidy ≥ 1; spread 0–500 bps |
| `parimutuel` | `takeout_bps` (new integer) | 1000–3000 bps |

Unused fee columns for a given mechanism are stored as `NULL` in the DB and ignored by all services. No polymorphic table splitting is introduced; the single-row layout is sufficient for the POC.

### Pricing engines

Each mechanism exposes a `pricing_engine` object returned by a factory method on `Market`:

- `fixed_odds` → `FixedOddsPricingEngine` (existing, no change)
- `clob` → `ClobPricingEngine` (best bid/ask from order book)
- `lmsr` → `LmsrPricingEngine` (cost function `C(q) = b · ln(Σ e^(q_i/b))`)
- `parimutuel` → `ParimutuelPricingEngine` (implied probability from pool composition)

### Shared infrastructure (unchanged for all mechanisms)

- Market lifecycle: `draft → open → settled` (or `cancelled`)
- RBAC: same permission model for all mechanisms
- Wallet/ledger: all financial transactions go through `LedgerEntry`; all order/trade writes produce `AuditEvent`
- SSE stream (`/sse/markets/:id`): extended to push mechanism-appropriate snapshots; field names are namespaced to avoid collisions
- `SettlementService`: branches on `mechanism_type` to delegate to a mechanism-specific settlement handler

### Mechanism-specific settlement logic

| Mechanism | Settlement rule |
|-----------|----------------|
| `fixed_odds` | Existing: WON/LOST per bet; payout via `potential_payout_minor` |
| `clob` | Each winning contract pays exactly 100 minor units; losing reservation forfeited |
| `lmsr` | Winning side receives proportional share of the total cost function pool |
| `parimutuel` | `payout = stake × (total_pool_after_takeout / winning_pool)` |

---

## Consequences

- ✅ Operators can showcase all three real prediction market models alongside the existing fixed-odds baseline — the platform becomes educational and configurable.
- ✅ Cold-start liquidity problem handled per-mechanism: CLOB requires manual market makers; LMSR uses the operator subsidy; parimutuel bootstraps from the first bet.
- ✅ Existing `fixed_odds` markets and all associated services (`BetPlacementService`, `HouseRiskService`, `BetslipQuoteService`) continue to work without modification.
- ✅ RBAC, wallet, ledger, SSE, and hot-storage infrastructure are reused across all mechanisms with minimal branching.
- ⚠️ Bet placement, settlement, and price display all branch on `mechanism_type`. Code paths multiply; test surface grows proportionally.
- ⚠️ CLOB partial fills introduce fractional reservation accounting not present in the whole-bet model. `Order.filled_quantity` must be tracked separately from `Order.quantity`.
- ⚠️ LMSR subsidy is a real financial commitment by the operator. Exhausted subsidy must be detected and surfaced clearly; market should automatically close if subsidy falls below a configurable floor.
- ⚠️ Parimutuel implied odds change continuously until pool close. Players see probability, not a fixed price — this UX is different from all other mechanisms and must be labelled clearly.
- ⚠️ `liability_cap_minor` and `HouseRiskService` are meaningful only for `fixed_odds` and `lmsr` (where the operator has bounded loss). They are ignored for `clob` and `parimutuel`.
- 🔜 Future path: once all mechanisms are stable, a mechanism-agnostic "positions" API can aggregate holdings across all types for the user profile and leaderboard features (BACKLOG F-005, F-007).
- 🔜 Future path: cross-mechanism arbitrage detection (e.g. LMSR price diverging from parimutuel implied probability on the same question) is a future analytics feature and is out of scope for v1.

---

## Areas Affected (Implementation Checklist)

- [ ] `markets` table: add `taker_fee_bps`, `liquidity_subsidy_minor`, `spread_fee_bps`, `takeout_bps` columns
- [ ] `Market` model: extend `mechanism_type` string validation to four values; add mechanism-specific validations; add `pricing_engine` factory method
- [ ] Market creation form (backoffice HTML): mechanism picker dropdown + conditionally shown fee fields per mechanism
- [ ] Pricing representation: CLOB shows best bid/ask; LMSR shows cost-function probability + cost-to-move; parimutuel shows pool composition bar + implied probability
- [ ] Bet/Order placement: separate service per mechanism (`BetPlacementService` stays for fixed-odds; new services for CLOB, LMSR, parimutuel)
- [ ] Settlement router: `SettlementService` branches on `mechanism_type` to delegate
- [ ] Price history: track differently per mechanism (CLOB: trade price; LMSR: marginal cost; parimutuel: pool composition over time)
- [ ] Pool/order-book visualisation: parimutuel shows pool bar; LMSR shows probability curve; CLOB shows order book depth
- [ ] SSE events: push mechanism-appropriate snapshots per trade
- [ ] `HouseRiskService`: only consulted for `fixed_odds`; skip for CLOB/LMSR/parimutuel
- [ ] `liability_cap_minor`: enforced only for `fixed_odds` and `lmsr` (bounded subsidy loss)
- [ ] API responses (admin JSON + SSE): include mechanism-specific fields; use `mechanism_type` key in all market payloads
- [ ] `Order` model + migration: new first-class record for CLOB orders (price_cents, quantity, side, status, tif, user, market, leg)
- [ ] `OrderMatchingService`: price-time priority, partial fills, atomic ledger debit/credit
- [ ] `LmsrPricingService`: cost function `C(q)`, marginal cost, trade cost delta
- [ ] `LmsrTradeService`: place trade, update quantities, ledger debit, audit
- [ ] `ParimutuelPoolService`: add stake to pool, recalculate implied odds
- [ ] `ParimutuelSettlementService`: takeout deduction, pro-rata payout

---

## Alternatives Considered

**Single unified pricing model:** Rejected. The mathematical models for CLOB (discrete order matching), LMSR (continuous cost function), and parimutuel (pool division) are structurally incompatible. A single model would mean picking one and misrepresenting the others.

**CLOB-only migration (narrow ADR-0013 draft):** Rejected as the final state. CLOB is the most realistic mechanism for a credible prediction market exchange, but it has a cold-start liquidity problem that makes it unsuitable as the *only* mechanism for a POC showcase. Preserving all four mechanisms lets the platform demonstrate the full design space.

**Polymarket hybrid (off-chain matching, on-chain settlement):** Rejected. Introduces smart contract risk, on-chain gas, and blockchain integration that are out of scope for this Rails monolith POC [7].

**Separate tables per mechanism:** Rejected for the POC. A polymorphic split adds join complexity with no query-performance benefit at this scale. A single `markets` row with nullable fee columns is simpler and sufficient.

---

## References

[1] R. Hanson, "Logarithmic Market Scoring Rules," *Journal of Prediction Markets*, 2007. https://mason.gmu.edu/~rhanson/mktscore.pdf

[2] K. Pillay, "Path Dependence in AMM-Based Markets," arXiv:2503.00201, 2025. https://arxiv.org/abs/2503.00201

[4] Kalshi API docs — orderbook responses: https://docs.kalshi.com/getting_started/orderbook_responses

[5] Burgi, Deng, Whelan (2026) — Kalshi fee economics: https://www.karlwhelan.com/Papers/Kalshi.pdf

[6] Polymarket trading fees: https://docs.polymarket.com/trading/fees

[7] Polymarket CLOB introduction: https://docs.polymarket.com/developers/CLOB/introduction

[12] Rahman, Al-Chami, Clark, "SoK: DePMs," arXiv:2510.15612, 2025. https://arxiv.org/abs/2510.15612

[16] Wikipedia, "Parimutuel Betting." https://en.wikipedia.org/wiki/Parimutuel_betting
