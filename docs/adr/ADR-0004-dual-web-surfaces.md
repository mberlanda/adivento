# ADR-0004: Dual Web Surfaces (Customer + Backoffice)

## Status
Accepted

## Context
API-only delivery is insufficient for current product goals. Distinct customer and operations experiences are needed.

## Decision
Implement two server-rendered web surfaces:
- customer-facing market exploration pages
- backoffice pages for moderator/admin operations

Both run in the monolith with separate namespaces/layouts.

## Consequences
- Faster value delivery without adding SPA complexity.
- Clear separation of audience and risk-sensitive operations.
- Supports future extraction of backoffice and customer frontends into separate deployables.
