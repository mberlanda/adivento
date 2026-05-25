# ADR-0001: Rails 8 Modular Monolith

## Status
Accepted

## Context
The product needs a fast first release with strong correctness and future adaptability for mobile apps and possible service extraction.

## Decision
Use a Rails 8 API-first modular monolith with explicit domain boundaries in controllers/models/services and a single relational database.

## Consequences
- Faster delivery and easier local operations for early iterations.
- Single deployment artifact with straightforward Docker Compose runtime.
- Future extraction paths remain open by preserving clear module boundaries.
