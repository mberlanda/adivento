# Iteration 001 Plan - Rails 8 Monolith Foundations

## Goals
- Ship a minimal but production-oriented backend monolith for prediction markets.
- Implement role-based access with four visibility classes: guest, player, moderator, admin.
- Support fantasy-currency wallet flow (`ADIV`) with moderated/admin faucet grants.
- Keep boundaries clean to enable later extraction for mobile-focused APIs.

## Scope (In)
- JWT authentication (`register`, `login`, `me`).
- Roles: `admin`, `moderator`, `player`.
- Public market read APIs for guests.
- Admin market creation/update; moderator + admin market settlement and leg extension.
- Player faucet request; moderator/admin approval/rejection with audit and ledger entries.
- Dockerized local runtime with `docker compose`.
- Unit + integration tests with target >= 90% line coverage.

## Scope (Out)
- Real-money wallet integration.
- Order matching, staking, exposure engine.
- Dispute workflows and dual-approval governance.
- Frontend UI and mobile client implementation.

## Delivery Slices
1. Runtime baseline: Ruby 3.3.6 + Rails 8.1.x, schema and domain models.
2. Auth + RBAC + API endpoints.
3. Wallet faucet grant workflow + ledger/audit trail.
4. Test hardening and coverage gate.
5. Docker packaging and documentation.

## Fast Follow
- Add versioned mobile-friendly API namespace (`/api/v1`).
- Replace local JWT secret with rotated credentials strategy.
- Introduce explicit permission matrix (policy objects) beyond role checks.
- Add market exposure + settlement payout engine.
