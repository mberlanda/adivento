# Adivento Docs Index

**Load this file first in any new session.** Follow links only for details you need.

## Project in one paragraph
Prediction markets POC: Rails 8 monolith, PostgreSQL, Redis. Two surfaces — `backoffice/` (HTML, session auth) for operators, `web/` (HTML, no-auth) for customers. `admin/` namespace is a JSON API (JWT). Fixed-odds house underwriting with per-market liability caps. Fantasy wallet denominated in ADIV (minor units = cents).

## Tech stack quick-ref
| Layer | Choice |
|-------|--------|
| Framework | Rails 8, Ruby |
| DB | PostgreSQL (via Docker) |
| Cache/stream | Redis (hot snapshots + SSE) |
| Auth | Session cookie (backoffice/web) · JWT Bearer (admin API) |
| Tests | Minitest, SimpleCov (90% threshold) |
| E2E | Playwright under `e2e/playwright/` |

## Architecture Decisions (ADRs)
All accepted unless noted. Read only if touching that domain.

| # | Decision | Status | File |
|---|----------|--------|------|
| 01 | Rails 8 modular monolith, single DB | ✅ | [ADR-0001](adr/ADR-0001-rails8-modular-monolith.md) |
| 02 | JWT auth + role RBAC (admin/moderator/player) | ✅ | [ADR-0002](adr/ADR-0002-jwt-and-role-rbac.md) |
| 03 | Fantasy wallet, ledger-first | ✅ | [ADR-0003](adr/ADR-0003-fantasy-wallet-ledger-first.md) |
| 04 | Dual web surfaces (backoffice + customer web) | ✅ | [ADR-0004](adr/ADR-0004-dual-web-surfaces.md) |
| 05 | RBAC with ad-hoc grants (deny overrides role) | ✅ | [ADR-0005](adr/ADR-0005-rbac-with-ad-hoc-grants.md) |
| 06 | Market templates as first-class objects | ✅ | [ADR-0006](adr/ADR-0006-market-templates.md) |
| 07 | SSE for live market updates | ✅ | [ADR-0007](adr/ADR-0007-sse-for-live-market-updates.md) |
| 08 | Modular seams for future microservices | ✅ | [ADR-0008](adr/ADR-0008-modular-seams-for-microservices.md) |
| 09 | Fixed-odds house liability model | ✅ | [ADR-0009](adr/ADR-0009-fixed-odds-house-liability-model.md) |
| 10 | Binary market line model (YES/NO, UP/DOWN) | ✅ | [ADR-0010](adr/ADR-0010-binary-market-line-model.md) |
| 11 | Betslip + cashout quote-execute contract | 🔵 proposed | [ADR-0011](adr/ADR-0011-betslip-and-cashout-contract.md) |
| 12 | Hot/cold storage: PG + Redis projections + SSE | 🔵 proposed | [ADR-0012](adr/ADR-0012-hot-cold-storage-with-redis-projections.md) |

## Implementation Status

### ✅ DONE (all tests passing)
- Auth: JWT + session, register/login/me
- RBAC: roles + permissions + ad-hoc grants
- Wallet + ledger
- Market CRUD (admin JSON API)
- Market legs
- Bet placement (BetPlacementService) + house risk check
- Bet void (BetVoidService)
- **Settlement engine** (SettlementService — bets transition WON/LOST, payouts credited)
- Market templates (create, edit, update, deactivate)
- **Backoffice markets section** (list, show, create, open, settle)
- Hot storage (Redis snapshots, MarketSnapshotProjector)
- SSE market stream
- Faucet request flow

### 🔄 IN PROGRESS
- PLAN-D: E2E Playwright tests (blocked on Docker overlay2 issue)

### ⏳ TODO (prioritised)
1. **PLAN-B: Betslip + cashout** — spec reviewed, plan v1 exists → [spec](specs/ITERATION_005_BETSLIP_CASHOUT_SPEC.md) · [plan](plans/ITERATION_005_BETSLIP_CASHOUT_ARCHITECTURE_PLAN_V1.md)
2. **PLAN-C: Hot/cold storage finalisation** — SSE fanout, reconciliation job → [spec](specs/ITERATION_005_HOT_COLD_STORAGE_SPEC.md) · [plan](plans/ITERATION_005_HOT_COLD_STORAGE_ARCHITECTURE_V1.md)
3. **Binary line invariants** — enforce exactly-2-legs at DB level → [spec](specs/ITERATION_005_BINARY_MARKET_LINES_SPEC.md)
4. Faucet request backoffice UI

## Key file map (for quick navigation)
```
app/
  controllers/
    admin/               # JSON API (JWT auth)
      markets_controller.rb     # create, update, settle, risk
      bets_controller.rb        # void
      market_legs_controller.rb
      faucet_requests_controller.rb
    backoffice/          # HTML (session auth, moderator+)
      markets_controller.rb     # list, show, create, open, settle
      templates_controller.rb   # full CRUD
      permissions_controller.rb
      grants_controller.rb
    web/                 # HTML (no auth required for index/show)
      markets_controller.rb
  services/
    settlement_service.rb       # bet transition + payout on market settle
    bet_placement_service.rb    # house risk check + ledger
    bet_void_service.rb         # refund + ledger
    house_risk_service.rb       # worst-case liability
    market_from_template_service.rb
    hot_storage/                # Redis projection
  models/
    market.rb / market_leg.rb / market_template.rb
    bet.rb / user.rb / wallet.rb / ledger_entry.rb / audit_event.rb
  domain/
    catalogs/            # action_catalog, permission_catalog, template_catalog
test/
  services/              # unit tests for services
  integration/           # integration tests (all endpoints)
  fixtures/              # users, markets, market_legs, bets, wallets, permissions
docs/
  INDEX.md               ← YOU ARE HERE
  WORK_LOG.md            ← chronological audit of what was built
  adr/                   ← architecture decisions
  specs/                 ← functional specs per iteration
  plans/                 ← legacy iteration plans (ITERATION_00N_*)
  superpowers/plans/     ← current-format implementation plans (YYYY-MM-DD-*.md)
```

## Fixtures cheat-sheet (for tests)
| Key | Role | Password | Wallet |
|-----|------|----------|--------|
| `users(:admin)` | admin | password123 | 100_000 |
| `users(:moderator)` | moderator | password123 | 50_000 |
| `users(:player)` | player | password123 | 1_000 |
| `markets(:open_market)` | status:1 open | — | legs: YES/NO |
| `markets(:draft_market)` | status:0 draft | — | no legs |

Admin API auth: `auth_headers_for(users(:admin))` (returns Authorization + Content-Type headers).
Backoffice auth: `post "/signin", params: { email: users(:admin).email, password: "password123" }`.

## Running things
```bash
docker compose up -d db          # start postgres
bin/rails db:prepare             # create + migrate + seed test db
bin/rails test                   # full suite (requires 90% coverage)
bin/rails test test/path/file.rb # single file
docker compose up -d             # start full app (web + db + redis)
```
