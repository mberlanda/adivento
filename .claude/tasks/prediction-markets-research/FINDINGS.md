# Findings: Prediction Markets Mechanics Research

*Completed: 2026-05-27*

---

## The Four Main Mechanisms

### 1. Continuous Limit Order Book (CLOB)

**Used by:** Kalshi (CFTC-licensed DCM), Polymarket (current architecture since ~2022)

**How pricing works:**
Traders submit limit orders (price + quantity + side) to a centralised matching engine. The engine pairs compatible YES bids with NO asks on price-time priority. No automated agent stands between participants — prices emerge from order flow exactly as on a stock exchange.

**Who takes directional risk:**
Nobody at the platform level. The exchange is a pure intermediary. A Central Counterparty (CCP) or equivalent novates each matched trade so the two original traders face the exchange, not each other — but the exchange nets to zero.

**How the platform earns revenue:**
Fee on taker fills only. Maker posting is free (and sometimes rebated).

- Kalshi fee formula: `0.07 × P × (1 − P)` per contract, peaking at ~$1.75 per 100 contracts at P=0.50. Most markets carry 0% maker fee; major-event markets (NFL, presidential elections) charge a flat 0.25% maker fee. Separate 0.01%–0.05% transaction fee layer.
- Polymarket fee: taker pays up to 1.80% at 50/50 (also probability-weighted); maker rebates apply. Settlement is on-chain (Polygon/USDC.e). Off-chain order matching for speed, on-chain atomic settlement for transparency.

**Architecture nuance (Polymarket):**
Polymarket's CLOB is a hybrid-decentralized system: off-chain operator handles order matching, but the Exchange smart contract on Polygon handles atomic settlement. All trade data is publicly auditable on-chain. YES/NO outcome tokens are ERC-1155 tokens; the contract auto-mints complementary shares and resolves them at 0 or 1 USDC.

**Key research finding:**
A 2026 microstructure study (Dubach, arXiv:2604.24366) analysed 30 billion order-book events over 52 days on Polymarket and documented: a longshot spread premium, broad maker-wallet diversity with a concentrated tail, and median archive-ingestion latency of <50ms. A separate 2026 paper (Yang & Tsang, arXiv:2603.03136) found that naively reported October Trump-market volume ($958M) overstates true exchange-equivalent volume ($391M) because share minting/burning inflate naive counts.

---

### 2. Logarithmic Market Scoring Rule (LMSR / AMM)

**Used by:** Augur (originally), early Polymarket (before CLOB migration), Manifold Markets (play-money "maniswap" variant)

**How pricing works:**
An automated market maker always stands ready to trade. The cost function is:

```
C(q) = b * ln( sum_i e^(q_i / b) )
```

A trader who moves the quantity vector from q to q' pays C(q') - C(q). This guarantees prices stay in (0, 1) and behave like probabilities. The liquidity parameter b controls price sensitivity.

**Who takes directional risk:**
The operator/subsidizer. Worst-case operator loss is bounded at `b * ln(n)` where n is the number of outcomes.

**How the platform earns revenue:**
There is no inherent fee revenue. The operator accepts bounded loss in exchange for a running market. Practical uses: internal corporate forecasting, play-money platforms (Manifold), academic/research markets.

**Key nuance — AMM vs CFPM:**
Modern DeFi-influenced prediction markets (including Augur Turbo) often use constant-product AMMs (Uniswap-style x*y=k) instead of pure LMSR. A 2025 paper (Pillay, arXiv:2503.00201) proves that constant-product AMMs are inherently path-dependent — the final price reflects the sequence of trades, not just current beliefs. LMSR lacks this deficiency.

**Manifold Markets specifics:**
Manifold uses "maniswap" (a Uniswap-style AMM) with play-money mana (M). The platform subsidises 20M per unique trader for the first 50 traders, then 5M up to a cap. Half of trading fees go to the market creator. Since mana has no cash conversion, the subsidy costs the platform nothing real.

---

### 3. Parimutuel Pools

**Used by:** Horse racing, jai alai, lottery-linked political markets. PredictIt uses a hybrid model (order-book UI but profit-percentage fees).

**How pricing works:**
All bets on all outcomes go into a single pool. The operator deducts a fixed "takeout" (typically 10–25%) before distribution. Remaining pool divides proportionally among winners by their stake fraction. Crucially, the final odds are not known until the pool closes.

**Who takes directional risk:**
Nobody directionally. Winners receive a proportional share of losers' money. The operator earns the takeout regardless of which outcome wins.

**How the platform earns revenue:**
Fixed takeout percentage from the pool before any payouts. This is guaranteed revenue, outcome-independent.

**PredictIt fee model (hybrid):**
PredictIt does not use a pure parimutuel pool. It operates an order book with a 10% fee on net winnings plus a 5% withdrawal fee — the highest combined rate in regulated US prediction markets. It operates under a CFTC no-action letter with $850 position limits per contract.

---

### 4. Fixed-Odds House Underwriting

**Used by:** Traditional bookmakers (Betfair exchange aside), sports betting operators, and — currently — Adivento.

**How pricing works:**
The house sets odds for each outcome, embedding a margin ("vig" / "overround") of typically 4–15%. Each bet is a bilateral contract between the bettor and the house at the quoted price.

**Who takes directional risk:**
The house, directly. Every bet creates a directional position on the house's balance sheet.

**How the platform earns revenue:**
The overround guarantees positive expected value on each market if the book is balanced. Even without perfect balance, the margin plus any fee_bps layer generates revenue.

**Adivento's current implementation (ADR-0009):**
- `odds_minor / 10_000` = decimal odds coefficient
- `potential_payout_minor = stake * odds_minor / 10_000`
- `liability_cap_minor` caps worst-case loss per market
- `HouseRiskService` computes current exposure across all outcomes
- `fee_bps` applied at bet placement

---

## Comparison Table

| Mechanism | Price setter | Counterparty | Platform directional risk | Revenue model |
|-----------|-------------|--------------|--------------------------|---------------|
| CLOB (Kalshi, Polymarket) | Traders via order flow | Matched traders (CCP novates) | None | Taker fee 0–1.80%, probability-weighted |
| LMSR/AMM (Augur, Manifold) | Algorithm (cost function) | The AMM / operator subsidy | Yes (bounded loss) | None direct; play-money subsidy is costless |
| Parimutuel (horse racing) | Pool composition | The pool | None | Fixed takeout 10–25% |
| Fixed-odds bookmaker (Adivento) | Operator | Operator directly | Yes (full directional) | Vig/overround 4–15% + fee_bps |

---

## The Gap: Adivento vs Real Prediction Markets

| Property | Adivento (current) | Kalshi / Polymarket |
|---|---|---|
| Odds source | House-set | Trader-discovered |
| House position | Directional (yes, capped) | None |
| Revenue | Overround + fee_bps | Taker fee only |
| Counterparty | The house | Another trader |
| liability_cap_minor | Required | Not needed |

---

## Key Research Insights

1. **Favourite-longshot bias exists in CLOB markets.** Burgi, Deng & Whelan (2026) found Kalshi takers lose ~32% on longshot contracts on average. The bias is stronger for takers than makers.

2. **AMMs are path-dependent; LMSR is not.** Constant-product AMMs (Uniswap-style) accumulate state from the sequence of trades. Pillay (2025) proves this mathematically.

3. **On-chain volume metrics require adjustment.** Yang & Tsang (2026) show naively reported volume can overstate exchange-equivalent volume by ~2.5×.

4. **Market quality improved dramatically on Polymarket.** Kyle's lambda dropped from 0.53 to 0.01 as the market matured in 2024; arbitrage-deviation half-lives fell from hours to under a minute.

5. **CLOB cold-start liquidity is a real problem.** Markets with thin order books have wide spreads and poor price discovery. This is the core argument for keeping Adivento's simpler house model for now.

---

## All References Found

### Official Platform Documentation
1. Polymarket CLOB Developer Docs — https://docs.polymarket.com/developers/CLOB/introduction
2. Polymarket Trading Fees — https://docs.polymarket.com/trading/fees
3. Kalshi API: Orderbook Responses — https://docs.kalshi.com/getting_started/orderbook_responses
4. Kalshi: How Prediction Markets Work — https://news.kalshi.com/p/how-prediction-markets-work
5. Kalshi: Who Am I Trading Against? — https://news.kalshi.com/p/who-am-i-trading-against-on-kalshi
6. Kalshi: How Are Prices Determined? — https://help.kalshi.com/markets/markets-101/how-are-prices-determined
7. Manifold Markets FAQ — https://docs.manifold.markets/faq

### Academic Papers
8. Hanson (2007): Logarithmic Market Scoring Rules for Modular Combinatorial Information Aggregation — https://mason.gmu.edu/~rhanson/mktscore.pdf
9. Burgi, Deng & Whelan (2026): Makers and Takers: The Economics of the Kalshi Prediction Market — https://www.karlwhelan.com/Papers/Kalshi.pdf (SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5502658)
10. Yang & Tsang (2026): The Anatomy of a Blockchain Prediction Market: Polymarket in the 2024 U.S. Presidential Election — arXiv:2603.03136 — https://arxiv.org/abs/2603.03136
11. Dubach (2026): The Anatomy of a Decentralized Prediction Market: Microstructure Evidence from the Polymarket Order Book — arXiv:2604.24366 — https://arxiv.org/abs/2604.24366
12. Rahman, Al-Chami & Clark (2025-2026): SoK: Market Microstructure for Decentralized Prediction Markets (DePMs) — arXiv:2510.15612 — https://arxiv.org/abs/2510.15612
13. Pillay (2025): Path Dependence in AMM-Based Markets: Mathematical Proof and Implications for Truth Discovery — arXiv:2503.00201 — https://arxiv.org/abs/2503.00201
14. Pennock et al. (2012): Prediction Markets, Mechanism Design, and Cooperative Game Theory — arXiv:1205.2654 — https://arxiv.org/abs/1205.2654
15. Whelan: Estimating Expected Loss Rates in Betting Markets — https://www.karlwhelan.com/Papers/Overround.pdf
16. Prediction Markets with Intermittent Contributions — arXiv:2510.13385 — https://arxiv.org/abs/2510.13385
17. Stanford: A Unified Framework for Dynamic Prediction Market Design — https://web.stanford.edu/class/msande310/ORfinal.pdf
18. Roughgarden et al.: Decentralized Prediction Markets (technical report) — https://timroughgarden.github.io/fob21/reports/ZLRL.pdf
19. Oxford Economic Papers (2025): Market structure and prices in online betting markets — https://academic.oup.com/oep/advance-article/doi/10.1093/oep/gpaf023/8244336

### Analytical / Journalism
20. Wharton IFPR Primer on Prediction Markets — https://wifpr.wharton.upenn.edu/blog/a-primer-on-prediction-markets/
21. Prediction Market Fees in 2026: Kalshi vs Polymarket (Laika Labs) — https://laikalabs.ai/prediction-markets/kalshi-vs-polymarket-fees-comparison
22. How Prediction Market Order Books Work (DeFiRate) — https://defirate.com/prediction-markets/how-order-books-work/
23. CEPR VoxEU: The Economics of the Kalshi Prediction Market — https://cepr.org/voxeu/columns/economics-kalshi-prediction-market
24. Wikipedia: Parimutuel Betting — https://en.wikipedia.org/wiki/Parimutuel_betting
25. Prediction Markets vs Sportsbooks (4.5% Vig Gap analysis) — https://tech-insider.org/prediction-markets/prediction-markets-vs-sportsbooks/
26. Castle Capital: The Evolution of Prediction Markets — https://chronicle.castlecapital.vc/p/evolution-of-prediction-markets
27. LMSR Explainer (Gensyn AI Blog) — https://blog.gensyn.ai/lmsr-logarithmic-market-scoring-rule/
28. Cultivate Labs: How LMSR Works — https://www.cultivatelabs.com/crowdsourced-forecasting-guide/how-does-logarithmic-market-scoring-rule-lmsr-work
