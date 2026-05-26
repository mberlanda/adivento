# Task: Binary Line DB Invariants

Enforce at the model and DB level that each market has at most 2 legs and cannot transition to `open` with fewer than 2. The `MarketLeg` model gets a count guard validation (on: :create). The `Market` model gets an open-transition guard. A PostgreSQL trigger migration enforces the 2-leg limit even when ActiveRecord validations are bypassed. `Admin::MarketLegsController` gets an early 422 return when a market already has 2 legs.

Spec: `docs/specs/2026-05-26-binary-line-invariants.md`
Plan: `docs/superpowers/plans/2026-05-26-binary-line-invariants.md`
