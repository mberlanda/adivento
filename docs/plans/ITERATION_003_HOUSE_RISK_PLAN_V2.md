<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 003 Plan V2 (Reviewed)

## Slice
Implement fixed-odds bounded-liability baseline.

## Design Decisions
1. Per-market mechanism metadata:
- mechanism_type
- fee_bps
- liability_cap_minor

2. Bet contract:
- stake_minor
- fee_minor
- net_stake_minor
- odds_minor
- potential_payout_minor

3. Risk formulas:
- total_stake = sum(net_stake_minor)
- payout(outcome) = sum(potential_payout_minor where outcome leg)
- pnl(outcome) = total_stake - payout(outcome)
- worst_case_liability = max(0, -min(pnl(outcome)))

4. Guardrail:
- reject if worst_case_liability_post_trade > liability_cap_minor

## Implementation Steps
1. Add schema and model changes.
2. Add HouseRiskService and BetPlacementService.
3. Add bet placement endpoint for authenticated users.
4. Add admin market risk endpoint with `risk.read` permission.
5. Seed new permissions and role mappings.
6. Add unit and integration tests.

## Done Criteria
- bets can be placed on open market legs
- fees tracked and auditable
- liability cap enforced deterministically
- all tests pass with coverage >= 90%
