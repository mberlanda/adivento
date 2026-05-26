<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 005 Plan Review: Binary Market Lines

## Findings
- Plan aligns with business requirement for binary lines grouped under broader markets.
- Requires explicit separation between market display container and executable binary line.
- Must preserve migration path from current market_leg model to line-side model.

## Required Changes
1. Keep API view-model display-ready for client minimization.
2. Introduce reasoned statuses for bets and line outcomes.
3. Enforce non-hard-delete semantics via canceled/voided states.

## Review Decision
Approved for implementation in phases, starting with invariant and test hardening.
