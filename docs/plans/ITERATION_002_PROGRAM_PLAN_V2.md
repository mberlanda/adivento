<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 002 Program Plan (V2, Reviewed)

## Delivery Strategy
Two controlled slices with hard quality gates.

## Slice 1 (Execute Now)
### A. Policy and Authorization Foundation
- Add permission entities and role-permission mapping.
- Add user ad hoc grants (allow/deny).
- Implement resolution algorithm:
  - `deny grant > allow grant > role permission > deny`
- Replace hardcoded controller role checks with policy service checks.

### B. Admin Backoffice Web (Minimum Valuable)
- Backoffice layout and navigation.
- Permission matrix page (roles vs permissions).
- User grants page (allow/deny by permission).
- Enforce reason capture for grant changes.

### C. Customer Web Surface (Minimum Valuable)
- Guest-accessible market explore page.
- Market detail page with trust and status panel.
- Distinct customer layout from backoffice.

### D. Quality Gates
- Unit + integration tests for policy and permissions.
- Coverage remains >= 90%.
- Atomic commits by concern.

## Slice 2 (Immediately After Slice 1)
### E. Reusable Market Templates
- Template catalog CRUD in backoffice.
- Create market from template flow.
- Tests for instantiation correctness.

### F. SSE Streams
- `/sse/markets/:id` and `/sse/settlements/:id` endpoints.
- Versioned event names and IDs.
- Integration tests for event formatting and resume behavior.

### G. Microservice Extraction Seams
- Domain service boundaries and event contract docs.
- Avoid write-path cross-context joins.
- Add architecture lint checklist in docs.

## UX Benchmark Translation (from Kalshi/Polymarket)
1. Customer IA
- Top navigation includes Markets + Live.
- Cards show probability, volume, status, close time.
- Category and trend filters for rapid discovery.

2. Backoffice IA
- Hidden from public nav.
- Module-first navigation: permissions, market ops, templates, settlement.
- Every sensitive action logs reason and actor.

3. Trust affordances
- Market detail includes rule/source/status sections.
- Settlement updates visible through event timeline/SSE stream.

## Minimal Dependency Rules (V2)
- No SPA framework introduction.
- Use Rails-rendered pages and existing toolchain.
- SSE built with Rails primitives only.

## Atomic Commit Plan (V2)
1. `feat(authz): add permission model and policy resolution`
2. `feat(backoffice): add permission and grant web UI`
3. `feat(web): add customer market explore pages`
4. `feat(templates): add market template model and backoffice management`
5. `feat(sse): add market and settlement SSE endpoints`
6. `test(iteration2): add policy, web, template and sse integration coverage`
7. `docs(iteration2): update readme/spec/adr links and rollout notes`
