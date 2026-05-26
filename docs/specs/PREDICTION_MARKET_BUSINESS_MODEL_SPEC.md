<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Prediction Market Business Model Spec (Fixed-Odds House Underwriting)

## 1. Objective
Define the first house-exposure model for Adivento fantasy markets and implement enforceable risk controls.

## 2. Mechanism
- fixed-odds, house-underwritten
- house accepts first side without needing opposing user liquidity

## 3. Fee and Margin
- per-bet fee: `fee_minor = stake_minor * fee_bps / 10_000`
- `net_stake_minor = stake_minor - fee_minor`
- fee is booked immediately in ledger metadata

## 4. Liability Model
For each outcome leg:
- `total_stake = sum(net_stake_minor)`
- `payout_if_leg_wins = sum(potential_payout_minor for bets on that leg)`
- `pnl_if_leg_wins = total_stake - payout_if_leg_wins`
- `worst_case_liability = max(0, -min(pnl_if_leg_wins across legs))`

## 5. Guardrails
- each market has `liability_cap_minor`
- pre-trade simulation computes post-trade worst-case liability
- bet rejected if post-trade liability exceeds cap

## 6. Permissions
- `bet.place` for customers
- `risk.read` for moderators/admins

## 7. Endpoints
- `POST /markets/:market_id/bets`
- `GET /admin/markets/:id/risk`

## 8. Auditing
Bet placement writes:
- ledger entry
- audit event

## 9. Future compatibility
Current schema must support migration to:
- orderbook execution (CLOB)
- AMM/LMSR
without invalidating current risk data.
