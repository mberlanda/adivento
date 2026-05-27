# Prediction Market Mechanics — Research Reference

> Added in response to the observation: *"prediction markets don't have a house margin — they charge a commission per contract and pay off from the pool depending on when you bought."*
>
> This document clarifies how real prediction markets work, how Adivento's current model differs, and what a more realistic implementation would look like.

---

## The Four Main Mechanisms

### 1. Continuous Limit Order Book (CLOB)
Used by **Kalshi** (CFTC-licensed Designated Contract Market) and **Polymarket** (current, hybrid-decentralized).

Mirrors stock exchange mechanics: traders submit limit orders specifying price and quantity; a matching engine pairs compatible buy/sell orders by price-time priority. No automated market maker stands between participants — prices emerge from order flow.

Key properties:
- **No house positions**: the exchange is a pure intermediary
- **Prices locked in at execution** — if you buy YES at 30¢ and it resolves YES, you receive $1 regardless of later trader prices
- Transparent per-trade fee (the only revenue source)
- Requires liquidity providers or market makers to maintain tight spreads

Kalshi's fee formula: `0.07 × P × (1 − P)`, peaking at ~$1.75 per 100 contracts at P=0.50. Most markets have 0% maker fee; major-event markets (NFL, elections) charge a flat 0.25% maker fee. There is a separate 0.01%–0.05% transaction fee layer [4][5].
Polymarket's fee: taker pays up to 1.80% at 50/50; maker rebates apply; platform takes no positions [6].

**Polymarket architecture detail:** Polymarket's CLOB is a *hybrid-decentralized* system — off-chain order matching for speed, on-chain atomic settlement via an Exchange smart contract on Polygon (USDC.e). YES and NO outcome tokens are ERC-1155 tokens; the contract auto-mints complementary shares. All matched trades are publicly auditable on-chain [7].

**Market microstructure findings (2026 research):** Dubach [8] analysed 30 billion order-book events over 52 days on Polymarket and documented a longshot spread premium, broad maker-wallet diversity with a concentrated tail, and median order-ingestion latency below 50 ms. Yang & Tsang [9] found that naively reported on-chain volume overstates exchange-equivalent turnover by ~2.5× due to share minting/burning. Market quality improved dramatically through 2024: Kyle's lambda (price impact) dropped from 0.53 to 0.01 and arbitrage-deviation half-lives fell from hours to under a minute.

### 2. Logarithmic Market Scoring Rule (LMSR / AMM)
Used historically by **Augur**, early **Polymarket**, and still by **Manifold Markets** (play-money).

An automated agent always stands ready to trade at algorithmically determined prices via a cost function `C(q) = b · ln(Σ e^(q_i/b))`. Buying YES shifts the cost function; the buyer pays the incremental cost difference.

Key properties:
- Guaranteed liquidity at all times (no counterparty needed)
- Prices live in (0, 1) and behave like probabilities
- Operator subsidizes the market (worst-case loss bounded at `b · ln(n)`)
- Used for internal forecasting tools or play-money markets where subsidy cost is acceptable

Academic reference: Hanson (2007) [1].

**AMM variants and path dependence:** Modern DeFi-influenced prediction markets (Augur Turbo, early Polymarket) often substitute a constant-product AMM (`x · y = k`, Uniswap-style) for LMSR because it is cheaper to deploy on-chain. However, Pillay (2025) [2] mathematically proves that constant-product AMMs are *path-dependent* — the final price reflects the sequence of trades, not only current beliefs — making them imperfect probability aggregators. LMSR does not share this defect.

**Manifold Markets "maniswap":** Manifold uses a Uniswap-style AMM with play-money mana (M, no cash conversion). Creating a market requires an initial mana liquidity subsidy; the platform adds 20 M per unique trader for the first 50 traders, then 5 M up to a cap. Half of trading fees accrue to the market creator. Because mana has no cash value, the subsidy costs the platform nothing real [3].

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

When the bookmaker balances the book — attracting equal proportional betting volumes on each side — they pay out winners with losers' stakes and earn the overround outcome-independently [10].

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

## Additional Research Findings

### Favourite-Longshot Bias in CLOB Markets

Even in CLOB markets with no house directional exposure, traders systematically misprice low-probability contracts. Burgi, Deng & Whelan (2026) [11] used transaction-level data on 300,000+ Kalshi contracts to show:
- Takers lose ~32% on average on longshot contracts
- Makers (informed traders who post limit orders) have an average loss of ~10%
- Low-price contracts win far less often than required to break even; high-price contracts yield small positive returns

This favourite-longshot bias is a well-documented market microstructure phenomenon, and it persists even without a house margin embedding it by design.

### PredictIt's Hybrid Model

PredictIt does not use a pure parimutuel pool despite being grouped with "prediction markets". It operates an order book with a 10% fee on net winnings plus a 5% withdrawal fee — the highest combined rate in regulated US prediction markets. It operates under a CFTC no-action letter with $850 position limits per contract, which significantly limits individual trade scale.

### SoK Survey of Decentralized Prediction Markets

Rahman, Al-Chami & Clark (2025) [12] published a Systematization of Knowledge covering 100+ decentralized prediction market designs from 2011 to present. Their modular framework identifies eight lifecycle stages: infrastructure, market topic, share structure and pricing, initialization, trading, resolution, settlement, and archiving. Modern platforms like Polymarket "deviate materially" from earlier Truthcoin/Augur-v1 designs — the hybrid off-chain matching / on-chain settlement pattern is now the dominant architecture for high-volume decentralized markets.

---

## References

\[1\] R. Hanson, "Logarithmic Market Scoring Rules for Modular Combinatorial Information Aggregation," *Journal of Prediction Markets*, 2007. <https://mason.gmu.edu/~rhanson/mktscore.pdf>

\[2\] K. Pillay, "Path Dependence in AMM-Based Markets: Mathematical Proof and Implications for Truth Discovery," arXiv:2503.00201, February 2025. <https://arxiv.org/abs/2503.00201>

\[3\] Manifold Markets, "FAQ," Manifold Docs. <https://docs.manifold.markets/faq>

\[4\] Kalshi, "Orderbook Responses," API Documentation. <https://docs.kalshi.com/getting_started/orderbook_responses>

\[5\] C. Burgi, W. Deng, K. Whelan, "Makers and Takers: The Economics of the Kalshi Prediction Market," GWU Center for Economic Research Working Paper 2026-001. <https://www.karlwhelan.com/Papers/Kalshi.pdf> — also: CEPR VoxEU column <https://cepr.org/voxeu/columns/economics-kalshi-prediction-market>

\[6\] Polymarket, "Trading Fees," Developer Docs. <https://docs.polymarket.com/trading/fees>

\[7\] Polymarket, "CLOB Introduction," Developer Docs. <https://docs.polymarket.com/developers/CLOB/introduction>

\[8\] P. D. Dubach, "The Anatomy of a Decentralized Prediction Market: Microstructure Evidence from the Polymarket Order Book," arXiv:2604.24366, April 2026. <https://arxiv.org/abs/2604.24366>

\[9\] Z. Yang, K. P. Tsang, "The Anatomy of a Blockchain Prediction Market: Polymarket in the 2024 U.S. Presidential Election," arXiv:2603.03136, 2026. <https://arxiv.org/abs/2603.03136> — also SSRN: <https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6336679>

\[10\] K. Whelan, "Estimating Expected Loss Rates in Betting Markets: Theory and Evidence" (overround/vig). <https://www.karlwhelan.com/Papers/Overround.pdf>

\[11\] C. Burgi, W. Deng, K. Whelan — see \[5\] above. SSRN: <https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5502658>

\[12\] N. Rahman, J. Al-Chami, J. Clark, "SoK: Market Microstructure for Decentralized Prediction Markets (DePMs)," arXiv:2510.15612, October 2025 (v3: March 2026). <https://arxiv.org/abs/2510.15612>

\[13\] D. M. Pennock et al., "Prediction Markets, Mechanism Design, and Cooperative Game Theory," arXiv:1205.2654. <https://arxiv.org/abs/1205.2654>

\[14\] K. Pillay, "Path Dependence in AMM-Based Markets" — see \[2\] above.

\[15\] Wharton IFPR, "A Primer on Prediction Markets." <https://wifpr.wharton.upenn.edu/blog/a-primer-on-prediction-markets/>

\[16\] Wikipedia, "Parimutuel Betting." <https://en.wikipedia.org/wiki/Parimutuel_betting>

\[17\] Laika Labs, "Prediction Market Fees in 2026: Kalshi vs Polymarket." <https://laikalabs.ai/prediction-markets/kalshi-vs-polymarket-fees-comparison>

\[18\] Stanford OR, "A Unified Framework for Dynamic Prediction Market Design." <https://web.stanford.edu/class/msande310/ORfinal.pdf>

\[19\] T. Roughgarden et al., "Decentralized Prediction Markets" (technical report). <https://timroughgarden.github.io/fob21/reports/ZLRL.pdf>

\[20\] Oxford Economic Papers, "Market structure and prices in online betting markets," 2025. <https://academic.oup.com/oep/advance-article/doi/10.1093/oep/gpaf023/8244336>

\[21\] Gensyn AI Blog, "LMSR (Logarithmic Market Scoring Rule)." <https://blog.gensyn.ai/lmsr-logarithmic-market-scoring-rule/>

\[22\] Castle Capital, "The Evolution of Prediction Markets." <https://chronicle.castlecapital.vc/p/evolution-of-prediction-markets>
