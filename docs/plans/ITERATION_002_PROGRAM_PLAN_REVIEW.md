# Iteration 002 Program Plan Review (Against V1)

## Review Summary
V1 is directionally correct but too broad for one safe iteration and under-specifies risk controls.

## Findings
1. Scope risk
- V1 combines large UX work, policy engine, templates, SSE, and architecture refactor in one pass.
- Risk: delayed delivery and unstable quality.

2. Permissions ambiguity
- V1 does not define precedence between role permissions and ad hoc grants.
- Risk: inconsistent access decisions.

3. Backoffice trust controls are underspecified
- Sensitive actions need explicit guardrails: reason capture, audit invariants, deny-overrides.

4. SSE contract incompleteness
- V1 lacks versioned event names and reconnection guarantees.

5. UX benchmark translation gap
- V1 references inspiration but lacks concrete IA requirements and anti-pattern checks.

6. Extraction seam enforcement needs coding standards
- V1 does not enforce boundaries in code review/test checks.

## Required Revisions
1. Split delivery into slices:
- Slice 1: policy engine + backoffice permission UI + customer web skeleton
- Slice 2: templates + SSE + extraction seam hardening

2. Define permission resolution algorithm:
- explicit deny grant > explicit allow grant > role permission > default deny

3. Add mandatory audit requirements:
- all permission/grant/template/settlement actions must produce audit records

4. Make SSE protocol explicit:
- event id, event type, data payload, retry hint, last-event-id handling

5. Add UX acceptance checklist:
- discoverability, trust panel visibility, responsive market card grid

6. Add measurable quality gates:
- keep test coverage >= 90%
- no new critical authz findings in integration tests
