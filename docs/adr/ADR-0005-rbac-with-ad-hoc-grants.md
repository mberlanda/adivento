# ADR-0005: RBAC with Ad Hoc Grants

## Status
Accepted

## Context
Role checks alone are not sufficient for nuanced moderator/admin operations.

## Decision
Adopt policy resolution with role-permission matrix plus user-level ad hoc grants.

Resolution order:
1. explicit deny grant
2. explicit allow grant
3. role permission
4. implicit deny

## Consequences
- Admin can delegate narrowly without changing global role semantics.
- Fine-grained overrides support incident operations.
- Requires strong auditing and reason capture.
