# ADR-0003: Fantasy Wallet with Ledger-First Tracking

## Status
Accepted

## Context
Iteration 1 needs a fantasy coin (`ADIV`) with admin/moderator grants while preserving auditability and future migration paths.

## Decision
Use wallet balances for fast reads and append-only `ledger_entries` + `audit_events` for grant/review operations.

## Consequences
- Clear traceability for privileged wallet changes.
- Compatible with future real-wallet integration phases.
- Keeps current implementation simple while enforcing operational accountability.
