# Adivento

Private prediction market platform — Rails 8 monolith, PostgreSQL, Redis.

Players bet ADIV fantasy tokens on binary markets (YES/NO, UP/DOWN). The house underwrites at fixed odds with per-market liability caps. Operators manage everything through a session-authenticated backoffice; players interact via a public customer surface; integrations hit a JWT-secured JSON API.

## Features

- **Fixed-odds markets** — draft → open → settled lifecycle, binary leg model (exactly 2 legs per market)
- **Bet placement & settlement** — house risk check before accept; settlement transitions all open bets WON/LOST and credits winner wallets in a single transaction
- **Fantasy wallet (ADIV)** — ledger-first accounting, faucet request + admin approve/reject flow
- **RBAC** — `admin`, `moderator`, `player` roles with ad-hoc per-user permission grants (deny overrides role)
- **Backoffice** (`/backoffice`) — market lifecycle management (create, open, settle), market templates full CRUD, permissions matrix, ad-hoc grants
- **Customer web** (`/`) — public market index and detail pages, live updates via SSE
- **Admin JSON API** (`/admin`) — JWT-secured CRUD for markets, legs, bets, faucet requests
- **Hot storage** — Redis snapshots via `MarketSnapshotProjector`; SSE stream for real-time market events
- **Audit trail** — append-only `ledger_entries` + `audit_events` for every privileged action
- **90%+ test coverage** enforced by SimpleCov gate

## Tech stack

| Layer | Choice |
|-------|--------|
| Framework | Rails 8.1 |
| DB | PostgreSQL 16 |
| Cache / stream | Redis |
| Auth | Session cookie (backoffice/web) · JWT Bearer (admin API) |
| Tests | Minitest · SimpleCov (≥ 90%) |
| E2E | Playwright under `e2e/playwright/` |

## Local setup

**With Docker (recommended):**

```bash
docker compose up --build
```

Starts `db` (PostgreSQL 16) and `web` (port 3000). Entrypoint runs `rails db:prepare` automatically.

**Without Docker:**

```bash
bundle install
bin/rails db:prepare   # PostgreSQL must be running locally
bin/rails db:seed
bin/rails server
```

## Running tests

```bash
docker compose up -d db   # required — tests need PostgreSQL
bin/rails test            # full suite, 90% coverage threshold enforced
bin/rails test path/to/file.rb   # single file
```

## Seed accounts

| Email | Password | Role |
|-------|----------|------|
| `admin@adivento.local` | `password123` | admin |
| `moderator@adivento.local` | `password123` | moderator |
| `player@adivento.local` | `password123` | player |

## Surfaces

### Customer web (no auth required for browsing)
- `GET /` — market index
- `GET /web/markets/:id` — market detail
- `GET /signin` — player login

### Backoffice (session auth, moderator+)
- `GET /backoffice` — dashboard
- `GET /backoffice/markets` — market list + create form
- `GET /backoffice/markets/:id` — market detail, open, settle
- `GET /backoffice/templates` — template list + create form
- `GET /backoffice/templates/:id/edit` — edit template
- `GET /backoffice/permissions` — RBAC matrix
- `GET /backoffice/grants` — ad-hoc user grants

### Admin JSON API (JWT Bearer)
- `POST /auth/register` · `POST /auth/login` · `GET /auth/me`
- `GET/POST /admin/markets` · `PATCH /admin/markets/:id` · `POST /admin/markets/:id/settle`
- `POST /admin/markets/:id/legs`
- `POST /admin/bets/:id/void`
- `GET /admin/faucet_requests` · `POST /admin/faucet_requests/:id/approve` · `.../reject`
- `GET /wallet` · `POST /faucet_requests` (player, auth required)

### SSE
- `GET /sse/markets/:id` — live market event stream

## Architecture

- **Service objects** handle all business logic: `BetPlacementService`, `BetVoidService`, `SettlementService`, `HouseRiskService`, `MarketFromTemplateService`
- **Ledger-first wallet** — every balance change writes a `LedgerEntry`; wallet balance is always derivable from the ledger
- **Settlement is transactional** — `SettlementService.settle!` transitions all open bets, credits payouts, and writes audit records in one DB transaction
- **Hot storage** — `HotStorage::MarketSnapshotProjector` writes denormalized market state to Redis after every mutation; SSE controllers stream from Redis, not the DB
- **RBAC** — `permissions` define allowed actions per role; `user_grants` can override (allow or deny) per user; deny always wins

## Documentation

See [`docs/INDEX.md`](docs/INDEX.md) — project map, architecture decisions, implementation status, fixtures reference, and run commands. All ADRs, specs, and implementation plans are linked from there.
