# Adivento Platform (Iterations 001-002)

Rails 8 monolithic backend for a private prediction market platform.

Current implementation ships:
- role-based auth (`admin`, `moderator`, `player`) plus guest visibility
- prediction market CRUD subset with moderator settlement and leg management
- fantasy wallet (`ADIV`) faucet request + approval/rejection workflow
- append-only ledger + audit records for wallet grants
- customer-facing web pages for market exploration
- backoffice web pages with permission matrix and user ad hoc grants
- reusable market templates with create-market-from-template flow
- SSE endpoints for market and settlement updates
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

## UI End-to-End Tests (Playwright)
Install dependencies and browsers:
```bash
cd e2e/playwright
npm install
npm run install:browsers
```

Run headless locally:
```bash
cd e2e/playwright
npm run test
```

Run headed for local debugging:
```bash
cd e2e/playwright
npm run test:headed
```

Run against docker compose app:
```bash
docker compose up --build
cd e2e/playwright
npm run test:docker
```

Run against stage deployment:
```bash
cd e2e/playwright
BASE_URL=https://your-stage-host npm run test:docker
```

Reports:
```bash
cd e2e/playwright
npm run report
```

E2E specs are under:
- `e2e/playwright/tests/workflow.spec.js`

Current suite status:
- 53 tests passing
- 94.59% line coverage (SimpleCov)

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

## Web Overview

### Customer Surface
- `GET /`
- `GET /web/markets`
- `GET /web/markets/:id`
- `GET /signin`

### Backoffice Surface
- `GET /backoffice`
- `GET /backoffice/permissions`
- `PATCH /backoffice/permissions/:id`
- `GET /backoffice/grants`
- `POST /backoffice/grants`
- `GET /backoffice/templates`
- `POST /backoffice/templates`
- `POST /backoffice/templates/:id/create_market`

### SSE
- `GET /sse/markets/:id`
- `GET /sse/settlements/:id`

## Architecture Notes
- Controller boundaries enforce role checks.
- Service object `WalletGrantService` encapsulates wallet approval side effects.
- `ledger_entries` and `audit_events` keep privileged actions traceable.
- Chosen boundaries are intentionally mobile-friendly for a future `/api/v1` evolution.

## Supporting Documents
- Iteration 001 plan: `docs/plans/ITERATION_001_PLAN.md`
- Iteration 001 spec: `docs/specs/MVP_BACKEND_SPEC.md`
- Iteration 002 plans (v1, review, v2):
	- `docs/plans/ITERATION_002_PROGRAM_PLAN_V1.md`
	- `docs/plans/ITERATION_002_PROGRAM_PLAN_REVIEW.md`
	- `docs/plans/ITERATION_002_PROGRAM_PLAN_V2.md`
- Iteration 002 specs:
	- `docs/specs/ITERATION_002_WEB_SURFACES_SPEC.md`
	- `docs/specs/ITERATION_002_ARCHITECTURE_SEAMS_SPEC.md`
- ADRs:
	- `docs/adr/ADR-0001-rails8-modular-monolith.md`
	- `docs/adr/ADR-0002-jwt-and-role-rbac.md`
	- `docs/adr/ADR-0003-fantasy-wallet-ledger-first.md`
	- `docs/adr/ADR-0004-dual-web-surfaces.md`
	- `docs/adr/ADR-0005-rbac-with-ad-hoc-grants.md`
	- `docs/adr/ADR-0006-market-templates.md`
	- `docs/adr/ADR-0007-sse-for-live-market-updates.md`
	- `docs/adr/ADR-0008-modular-seams-for-microservices.md`
