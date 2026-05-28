# Market Mechanisms

Adivento supports four trading mechanisms, selectable per market. All markets are binary (exactly two legs). Mechanism is set at creation and cannot be changed after the market opens.

---

## Fixed-odds (house underwriting)

**How it works:** The house sets a price (implied probability) for each leg. Players bet at that price. The house covers the opposite side. Liability is bounded by `liability_cap_minor`.

**Payout:** `payout = stake / implied_probability`. At 50% odds (`odds_minor: 5000`), winners receive 2× their stake.

**Operator risk:** The operator bears worst-case exposure up to the cap. Revenue comes from the spread between implied probability and true probability.

**Key config:** `liability_cap_minor`, `fee_bps` (per-bet fee deducted upfront).

**Settlement:** Winning bets receive payout; losing bets receive nothing.

**Current status:** ✅ Fully implemented. Default mechanism.

---

## CLOB (Central Limit Order Book)

**How it works:** Players post limit orders (bid/ask). Matching engine fills orders by price-time priority. No house involvement — player vs player.

**Order types:** GTC (good-till-cancelled), IOC (immediate-or-cancel), FOK (fill-or-kill).

**Payout:** Each contract trades at the agreed price. Winning contracts are worth 1 ADIV each at settlement; losing contracts are worth 0.

**Operator risk:** None on the matched book. Operator earns a taker fee (`taker_fee_bps`).

**Key config:** `taker_fee_bps`.

**Settlement:** Two-pass: (1) cancel all open/partial orders and release reservations; (2) credit winners for their contract holdings.

**Current status:** ✅ Fully implemented. Fill ledger entries, `last_fill_price`, spread, positions endpoint (`GET /web/positions`).

**Known gap:** CLOB cashout (selling contracts before settlement) not yet implemented. See [tech-debt-backlog](tech-debt-backlog.md).

---

## LMSR (Logarithmic Market Scoring Rule / AMM)

**How it works:** An automated market maker (AMM) provides continuous two-sided liquidity using a cost function. Price responds to demand: buying YES makes YES more expensive. Based on Hanson (2007).

**Price formula:** `p(YES) = q_yes / (q_yes + q_no)` where `q_yes`, `q_no` are log-scaled quantities. The `b` parameter controls market depth: `b = liquidity_subsidy_minor / (ln(2) * 100)`.

**Operator risk:** Operator provides initial liquidity (`liquidity_subsidy_minor`). Worst-case loss equals exactly the subsidy. Operator earns via the spread between the log cost function and linear price.

**Key config:** `liquidity_subsidy_minor` (also determines `lmsr_b_parameter`, computed on market open).

**Settlement:** Market marked settled; outcome label shown. Individual position payouts are **not yet implemented** (v1 limitation — see [tech-debt-backlog](tech-debt-backlog.md)).

**Current status:** ✅ Mechanism implemented. Settlement → UI label only. Individual payouts deferred.

---

## Parimutuel (pool betting)

**How it works:** All bets on the same side go into a pool. After settlement, the winning pool is distributed proportionally to winners (minus the takeout). No pre-set odds — final odds depend on total pool sizes.

**Payout:** Winner receives `stake / total_winning_pool * (total_pool * (1 - takeout_bps/10000))`.

**Operator risk:** None on the bet side. Operator earns takeout (`takeout_bps`).

**Key config:** `takeout_bps` (percentage of pool retained by operator, e.g. 1500 = 15%).

**Settlement:** Winning pool shared proportionally. If winning pool is zero (no bets on winning side), all bets refunded.

**Current status:** ✅ Fully implemented including settlement payouts.

**Known gap:** Per-bettor history tracked via `LedgerEntry` only (no dedicated `ParimutuelBet` model). See [tech-debt-backlog](tech-debt-backlog.md).

---

## Mechanism comparison

| Property | Fixed-odds | CLOB | LMSR | Parimutuel |
|----------|-----------|------|------|------------|
| Operator risk | Up to cap | None | Up to subsidy | None |
| Initial liquidity needed | No | No (thin book) | Yes (subsidy) | No |
| Price discovery | Operator sets | Market | AMM formula | Post-close |
| Taker fee | `fee_bps` | `taker_fee_bps` | Implicit (spread) | `takeout_bps` |
| Cashout | ✅ via void | ❌ not yet | ❌ not yet | ❌ not yet |
| Settlement payouts | ✅ | ✅ | ❌ v1 limited | ✅ |
