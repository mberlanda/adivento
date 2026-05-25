# ADR-0006: Market Templates as First-Class Objects

## Status
Accepted

## Context
Recurring market structures should be reusable and consistent.

## Decision
Introduce `market_templates` with default legs and duration metadata, and instantiate markets through a dedicated service.

## Consequences
- Faster market operations with reduced operator error.
- Consistent market modeling across categories.
- Template subsystem can become an independent service later.
