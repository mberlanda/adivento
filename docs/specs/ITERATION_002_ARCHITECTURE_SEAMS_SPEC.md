<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 002 Architecture Seams Spec

## 1. Context Boundaries
- Access Control
- Markets
- Wallet/Ledger
- Settlement
- Web Customer
- Web Backoffice
- Realtime

## 2. Boundary Rules
1. Controllers call service layer, not foreign-context models directly.
2. Cross-context communication uses explicit service methods and event envelopes.
3. Read composition for web surfaces can use query/projection objects, not write logic mixing.

## 3. Event Contracts
Required events (slice-level):
- `access.permission_changed.v1`
- `access.grant_changed.v1`
- `market.template_used.v1`
- `market.status_changed.v1`
- `settlement.changed.v1`

## 4. Extraction Readiness Checklist
- permission decisions centralized in one service.
- SSE payload schemas versioned.
- market template instantiation isolated in dedicated service.
- web surfaces do not embed business rules outside services.

## 5. Dependency Constraints
- Rails built-ins preferred.
- no JS framework dependency for MVP web surfaces.
- no external realtime broker required in this slice.
