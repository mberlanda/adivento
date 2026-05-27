# ADR-0014: CLOB Order Book Migration

## Status
Accepted

## Context
Adivento was built with a fixed-odds house underwriting model (ADR-0009) as the simplest path to a working POC: the house sets odds, holds directional risk, and caps liability per market. This is the model used by traditional bookmakers, not prediction markets. Real prediction market platforms — Kalshi (CFTC-licensed DCM) and Polymarket — use a Continuous Limit Order Book (CLOB) where traders post limit orders and a matching engine pairs compatible buyers and sellers by price-time priority. The platform earns a taker commission only and takes no directional positions.

The fixed-odds model has a structural mismatch with prediction market semantics: the `liability_cap_minor` field exists solely to limit house exposure, `HouseRiskService` computes a bookmaker-style worst-case PnL, and `fee_bps` charges a percentage of stake rather than a per-contract execution fee. These primitives are appropriate for a bookmaker but wrong for an exchange. As the platform moves toward a credible prediction market design, the trading engine must be replaced.

The binary contract model (ADR-0010) is preserved: YES + NO always sum to 1 USD (100 cents), and winning contracts pay exactly $1 at settlement. What changes is how those contracts are created and transferred — through order matching, not house-underwritten bets.

## Decision
Replace the fixed-odds house underwriting engine with a CLOB model:

- Traders submit **limit orders** specifying price (1–99 cents), quantity (integer contracts), side (YES or NO), and time-in-force (GTC / IOC / FOK).
- A **matching engine** (`OrderMatchingService`) pairs compatible orders by price-time priority: a YES bid at price P matches a NO ask at price ≤ (100 − P), because YES + NO = $1.
- **No house positions**: the platform never holds YES or NO inventory. Every matched contract pair is between two traders.
- **Maker/taker fee structure**: maker (the order that was resting in the book) pays 0%; taker (the order that crosses the spread) pays a configurable percentage of the fill value (default 0.7%). This mirrors Kalshi's fee schedule [4][5].
- The `Order` model replaces `Bet` as the primary trading primitive. Open orders reserve wallet funds; filled contracts create position records. The existing `Bet` model and all previously placed bets are retained read-only under the legacy `fixed_odds` mechanism.
- The `OrderBook` projection is held in Redis (extending the existing hot-storage layer from ADR-0012) with sorted sets: bids sorted descending by price, asks sorted ascending.
- Settlement is unchanged in concept: winning side receives $1 per contract; `SettlementService` is extended to iterate orders rather than bets.

Key parameters (configurable per market):
- `maker_fee_bps = 0` (0%)
- `taker_fee_bps = 70` (0.70%)
- Maximum price: 99 cents. Minimum price: 1 cent. (Ensures both sides always have positive value.)

## Consequences
- The `markets.mechanism_type` column, currently always `"fixed_odds"`, gains a new value `"clob"`. New markets default to `"clob"`; existing markets retain `"fixed_odds"` and continue to accept bets through the legacy flow.
- `liability_cap_minor` and `HouseRiskService` are no longer consulted for CLOB markets. They remain in place for legacy `fixed_odds` markets.
- ✅ Platform no longer holds directional risk — credit exposure is eliminated for CLOB markets.
- ✅ Prices are set by trader supply/demand — the overround disappears and the platform's revenue model becomes purely commission-based.
- ✅ RBAC, wallet, ledger, and SSE infrastructure are reused without change.
- ✅ The hot-storage layer (ADR-0012) is extended to hold order-book depth snapshots alongside market metadata — no new Redis architecture required.
- ⚠️ Cold-start liquidity problem: a CLOB with no resting orders has infinite bid/ask spread and is untradeable. The v1 implementation does not include an automated market maker; the operator must seed initial orders or recruit market makers manually.
- ⚠️ Partial fills introduce fractional position accounting complexity not present in the existing whole-bet model. The `Order` model must track `filled_quantity` separately from `quantity`.
- ⚠️ Atomic matching under concurrent order submissions requires database-level row locking (`FOR UPDATE`) on the order book to prevent double-fills. PostgreSQL advisory locks or `SELECT FOR UPDATE SKIP LOCKED` are the implementation mechanism.
- 🔜 Future path: once CLOB is stable, `Bet`, `BetPlacementService`, `BetVoidService`, `BetslipQuoteService`, `BetslipExecutionService`, and `HouseRiskService` can be deprecated and removed. Migration of existing open bets to the settlement-only path is a separate ADR.
- 🔜 Future path: market-maker rebate (negative taker fee for designated liquidity providers) can be added as a per-user fee override without architectural change.

## Alternatives considered

**Keep fixed-odds house underwriting:** Simple and working, but misrepresents the platform as a prediction market. Requires growing the house balance sheet as trading volume increases, which is an unsustainable liability model at scale.

**LMSR / AMM:** Guaranteed liquidity at all times; no cold-start problem. However, the operator subsidises every market (bounded loss of `b · ln(2)` per binary market), which is costly at scale. LMSR prices are path-independent but AMM variants (constant-product) are mathematically path-dependent [2] — a defect for a probability-aggregating platform. AMMs also do not support limit orders, making them incompatible with Kalshi-style trading UX.

**Parimutuel pools:** Operator earns a guaranteed takeout; no directional risk. But odds are not fixed at trade time — they shift with every subsequent bet until the pool closes. This "pays from the pool" semantic is confusing to traders expecting price certainty. PredictIt operates a hybrid but under a CFTC no-action letter with $850 position caps that limit scalability.

**Hybrid CLOB + AMM:** Polymarket uses off-chain matching with on-chain settlement via ERC-1155 outcome tokens on Polygon [7]. Technically superior for decentralisation but introduces smart contract risk, on-chain gas costs, and a full blockchain integration out of scope for this Rails monolith.

## References
[2] Pillay (2025) — path dependence in AMM-based markets: https://arxiv.org/abs/2503.00201
[4] Kalshi API docs — orderbook responses: https://docs.kalshi.com/getting_started/orderbook_responses
[5] Burgi, Deng, Whelan (2026) — Kalshi fee economics: https://www.karlwhelan.com/Papers/Kalshi.pdf
[7] Polymarket CLOB introduction: https://docs.polymarket.com/developers/CLOB/introduction
