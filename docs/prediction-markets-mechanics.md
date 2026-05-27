# Prediction Market Mechanics — Research Reference

> Added in response to the observation: *"prediction markets don't have a house margin — they charge a commission per contract and pay off from the pool depending on when you bought."*
>
> This document clarifies how real prediction markets work, how Adivento's current model differs, and what a more realistic implementation would look like.

---

## The Four Main Mechanisms

### 1. Continuous Limit Order Book (CLOB)
Used by **Kalshi** and **Polymarket** (current).

Mirrors stock exchange mechanics: traders submit limit orders specifying price and quantity; a matching engine pairs compatible buy/sell orders by price-time priority. No automated market maker stands between participants — prices emerge from order flow.

Key properties:
- **No house positions**: the exchange is a pure intermediary
- **Prices locked in at execution** — if you buy YES at 30¢ and it resolves YES, you receive $1 regardless of later trader prices
- Transparent per-trade fee (the only revenue source)
- Requires liquidity providers or market makers to maintain tight spreads

Kalshi's fee formula: `0.07 × P × (1 − P)`, peaking at ~1.75% at P=0.50. Makers pay 0%. No directional exposure.
Polymarket's fee: taker pays up to 1.80% at 50/50; maker rebates apply; platform takes no positions.

### 2. Logarithmic Market Scoring Rule (LMSR / AMM)
Used historically by **Augur**, early **Polymarket**, and still by **Manifold Markets** (play-money).

An automated agent always stands ready to trade at algorithmically determined prices via a cost function `C(q) = b · ln(Σ e^(q_i/b))`. Buying YES shifts the cost function; the buyer pays the incremental cost difference.

Key properties:
- Guaranteed liquidity at all times (no counterparty needed)
- Prices live in (0, 1) and behave like probabilities
- Operator subsidizes the market (worst-case loss bounded at `b · ln(n)`)
- Used for internal forecasting tools or play-money markets where subsidy cost is acceptable

Academic reference: Hanson (2007), [Logarithmic Markets Scoring Rules](https://mason.gmu.edu/~rhanson/mktscore.pdf).

### 3. Parimutuel Pools
Used by **PredictIt** (partially), horse racing, jai alai.

All bets go into a single pool; the operator deducts a fixed "takeout" (10–25%), and the remainder divides proportionally among winners.

Key properties:
- **Odds NOT fixed at bet time** — they shift with every subsequent bet until pool closes
- The operator takes a guaranteed percentage regardless of outcome
- No counterparty risk: winners share the losers' money
- "Pays from the pool depending on when you bought" — this is what the friend's comment describes (more accurately, it depends on how the pool composes, not specifically when you bought)

### 4. Fixed-Odds House Underwriting
Used by **traditional bookmakers** (not real prediction markets).

The bookmaker sets odds, embeds a margin ("vig" / "overround" ~4–15%), and acts as direct counterparty to every bet. Risk is managed by shading lines and limiting sharp bettors.

**This is the model Adivento currently implements** (see [ADR-0009](adr/ADR-0009-fixed-odds-house-liability-model.md)).

---

## Comparison Table

| Mechanism | Who prices | Counterparty | House edge |
|-----------|------------|--------------|------------|
| CLOB (Kalshi, Polymarket) | Traders via order flow | Other traders (CCP novates) | None — commission only (~0–1.75%) |
| LMSR/AMM (Augur, Manifold) | Algorithm | Market maker (operator-subsidized) | None — operator subsidizes |
| Parimutuel (horse racing, PredictIt) | Pool composition | The pool | Yes — fixed takeout 10–25% |
| Fixed-odds bookmaker | Operator | Operator directly | Yes — vig/overround 4–15% |

---

## How Adivento Differs from Real Prediction Markets

The friend's observation is **directionally correct** for CLOB-based markets (Kalshi, Polymarket):

- ✅ No embedded margin in prices — prices are set by trader supply/demand
- ✅ Commission only (per-trade fee, not per-outcome)
- ✅ Platform takes no directional positions
- ⚠️ "Pays from the pool" applies to **parimutuel**, not CLOB — in CLOB your counterparty is another specific trader, not a pool

**Adivento's current design** (fixed-odds house underwriting) is structurally a bookmaker model:
- The house sets odds, holds the position, and profits from the overround
- `liability_cap_minor` limits maximum loss per market
- `HouseRiskService` computes worst-case exposure per outcome
- `fee_bps` is applied at bet placement (on top of the odds spread)

This is a **valid POC design** — it's simpler to reason about, avoids cold-start liquidity problems, and mirrors familiar regulated gambling models. It is, however, not how Polymarket or Kalshi work.

### What a CLOB Implementation Would Look Like

A proper prediction market CLOB would require:
1. **Order book** — per-market limit order table (price, quantity, side, user, timestamp)
2. **Matching engine** — pair YES bids against NO asks when prices are complementary (bid_yes + bid_no ≥ 1.00)
3. **Binary contract model** — YES + NO = $1 always; settlement pays exactly $1 to winning side
4. **Fee on taker only** — maker posts orders for free; taker's fill triggers a percentage fee
5. **No house position** — the platform never holds YES or NO inventory

This is significant additional complexity (order book persistence, matching latency, partial fills, cancellations) that is out of scope for this POC but worth noting for future evolution.

---

## Authoritative Sources

### Official Platform Documentation
- [Polymarket CLOB Developer Docs](https://docs.polymarket.com/developers/CLOB/introduction)
- [Polymarket Trading Fees](https://docs.polymarket.com/trading/fees)
- [Kalshi: How Prediction Markets Work](https://news.kalshi.com/p/how-prediction-markets-work)
- [Kalshi: Who Am I Trading Against?](https://news.kalshi.com/p/who-am-i-trading-against-on-kalshi)
- [Kalshi: How Are Prices Determined?](https://help.kalshi.com/markets/markets-101/how-are-prices-determined)
- [Manifold Markets FAQ](https://docs.manifold.markets/faq)

### Academic and Analytical
- [Prediction Markets, Mechanism Design, and Cooperative Game Theory — arXiv:1205.2654](https://arxiv.org/abs/1205.2654)
- [Hanson (2007): Logarithmic Markets Scoring Rules](https://mason.gmu.edu/~rhanson/mktscore.pdf)
- [The Economics of the Kalshi Prediction Market — Karl Whelan, CEPR](https://www.karlwhelan.com/Papers/Kalshi.pdf)
- [The Anatomy of Polymarket: Evidence from the 2024 Presidential Election — arXiv:2603.03136](https://arxiv.org/html/2603.03136v1)
- [Wharton Primer on Prediction Markets](https://wifpr.wharton.upenn.edu/blog/a-primer-on-prediction-markets/)
- [Wikipedia: Parimutuel Betting](https://en.wikipedia.org/wiki/Parimutuel_betting)

### Comparisons
- [Prediction Markets vs Sportsbooks — The Lines](https://www.thelines.com/prediction-markets/guide/prediction-markets-vs-sportsbooks/)
- [Kalshi vs Polymarket Fees Comparison 2026 — Laika Labs](https://laikalabs.ai/prediction-markets/kalshi-vs-polymarket-fees-comparison)
