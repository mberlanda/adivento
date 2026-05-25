# Adivento Backend (Iteration 001)

Rails 8 monolithic backend for a private prediction market platform.

This iteration ships:
- role-based auth (`admin`, `moderator`, `player`) plus guest visibility
- prediction market CRUD subset with moderator settlement and leg management
- fantasy wallet (`ADIV`) faucet request + approval/rejection workflow
- append-only ledger + audit records for wallet grants
- test coverage gate above 90%
- Docker + Docker Compose local runtime

## Runtime
- Ruby: 3.3.6
- Rails: 8.1.3
- DB (dev/prod): PostgreSQL
- DB (test): SQLite for fast local CI-like runs

## Local Setup (without Docker)
1. Install dependencies:
```bash
bundle install
```
2. Prepare database (PostgreSQL running locally):
```bash
bin/rails db:prepare
bin/rails db:seed
```
3. Run server:
```bash
bin/rails server
```

## Docker Compose
Start services:
```bash
docker compose up --build
```

This brings up:
- `db` on PostgreSQL 16
- `web` on port `3000`

Entrypoint automatically runs `rails db:prepare`.

## Test and Coverage
Run full suite:
```bash
RAILS_ENV=test bin/rails test
```

Current suite status:
- 32 tests passing
- 96.33% line coverage (SimpleCov)

## Seed Users
`db/seeds.rb` creates:
- `admin@adivento.local` / `password123`
- `moderator@adivento.local` / `password123`
- `player@adivento.local` / `password123`

## API Overview

### Auth
- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`

### Public and Player
- `GET /markets`
- `GET /markets/:id`
- `GET /wallet` (auth)
- `POST /faucet_requests` (auth)

### Admin/Moderator
- `GET /admin/faucet_requests`
- `POST /admin/faucet_requests/:id/approve`
- `POST /admin/faucet_requests/:id/reject`

### Admin Only
- `POST /admin/markets`
- `PATCH /admin/markets/:id`

### Admin or Moderator
- `POST /admin/markets/:id/legs`
- `POST /admin/markets/:id/settle`

## Architecture Notes
- Controller boundaries enforce role checks.
- Service object `WalletGrantService` encapsulates wallet approval side effects.
- `ledger_entries` and `audit_events` keep privileged actions traceable.
- Chosen boundaries are intentionally mobile-friendly for a future `/api/v1` evolution.

## Supporting Documents
- Plan: `docs/plans/ITERATION_001_PLAN.md`
- Spec: `docs/specs/MVP_BACKEND_SPEC.md`
- ADRs:
	- `docs/adr/ADR-0001-rails8-modular-monolith.md`
	- `docs/adr/ADR-0002-jwt-and-role-rbac.md`
	- `docs/adr/ADR-0003-fantasy-wallet-ledger-first.md`
