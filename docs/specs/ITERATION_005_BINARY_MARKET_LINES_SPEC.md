<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 005 Spec: Binary Market Lines

## Definitions
- Market: container for related binary lines.
- Binary line: proposition with exactly two options.
- Bet side: selected option within one line.

## Taxonomy
- Canonical internal sides: OPTION_1, OPTION_2.
- Display labels are template-driven and localization-ready.
- Common rendered labels:
  - YES / NO
  - UP / DOWN
  - Candidate A / Candidate B

## Status Taxonomy
### Bet status
- ACTIVE
- WON
- LOST
- CANCELED

### Bet status reasons (examples)
- settlement.outcome_won
- settlement.outcome_lost
- cashout.partial
- cashout.full
- market.voided
- operator.correction

## Invariants
1. Bet belongs to exactly one market and one line side.
2. Bet line side must belong to bet market.
3. Canceled/voided bets are never hard-deleted.
4. Settled lines must have one winning side.

## API View Model Requirement
Responses should include:
- display_title
- display_subtitle
- line_display_label_option_1
- line_display_label_option_2
- resolved localized strings when available

## MVP Implementation Constraint
Current schema may keep market_leg while enforcing binary constraints and display metadata to support migration.
