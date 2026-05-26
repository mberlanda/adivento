<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 005 Plan V1: Binary Market Lines and Settlement Invariants

## Goal
Model multi-prop markets as collections of binary lines where each line has two options, and enforce settlement/accounting invariants.

## Core Design
- A market is a container for one or more lines.
- A line is a proposition with exactly two options (option_1, option_2).
- Bet references one side of one line.
- Settlement resolves each line to one winner side.

## Scope
1. Add explicit binary line taxonomy and label strategy for display-ready API view models.
2. Add settlement service to transition bet statuses and post payout ledger entries.
3. Add DB and model invariants for bet/line/market consistency.
4. Add integration coverage for all app endpoints and critical invariant branches.

## Deliverables
- Updated domain model docs and ADR.
- Integration tests for auth/web/backoffice/admin/sse/api endpoints.
- Action contract remains source for nav/capabilities.

## Exit Criteria
- No endpoint-level gaps in app route coverage.
- /auth/me returns actions reliably for logged users.
- Test suite passes with coverage threshold.
