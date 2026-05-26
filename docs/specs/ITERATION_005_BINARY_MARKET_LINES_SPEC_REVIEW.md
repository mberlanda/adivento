<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 005 Binary Lines Spec Review

## Review Notes
- Spec supports business need for multiple binary props within one market context.
- Status taxonomy is aligned with no-hard-delete policy.
- Display-ready view model requirement reduces client conditional logic.

## Gaps to Address in Implementation
- Add explicit reason field for terminal statuses where missing.
- Add migration notes for market_leg to line-side abstraction.

## Decision
Approved with migration note and reason-code requirements.
