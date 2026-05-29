# Adivento Docs Index

**Load this file first in any new session.** Follow links only for details you need.

## Project in one paragraph
Prediction markets POC: Rails 8 monolith, PostgreSQL, Redis. Two HTML surfaces — `backoffice/` (session auth, moderator+) for operators, `web/` (no auth) for customers. `admin/` namespace is a JSON API (JWT). Four pluggable market mechanisms: fixed-odds, CLOB, LMSR, parimutuel. Fantasy wallet denominated in ADIV (minor units = cents).

**Product wiki (start here for context):** `docs/wiki/` — product overview, mechanisms, architecture, tech-debt backlog.
**Open design decisions + tech debt:** `docs/wiki/tech-debt-backlog.md`
**Pending autonomous work:** `.claude/tasks/ATTENTION.md`

## Tech stack
| Layer | Choice |
|-------|--------|
| Framework | Rails 8 |
| DB | PostgreSQL (Docker) |
| Cache/stream | Redis (hot snapshots + SSE) |
| Auth | Session cookie (backoffice/web) · JWT Bearer (admin API) |
| Tests | Minitest · SimpleCov 90% threshold |
| E2E | Playwright under `e2e/playwright/` |

---

## Docs folder guide

Use this to decide where to put — and where to look for — each type of document.

| Folder | Contains | When to create | Format |
|--------|----------|----------------|--------|
| `docs/wiki/` | **Product wiki** (what + why, product perspective) | When you need to explain a feature or document tech debt/decisions | Plain markdown |
| `docs/adr/` | Architecture decisions | When a decision affects multiple systems, is irreversible, or changes a cross-cutting constraint | `docs/templates/adr.md` |
| `docs/specs/` | Functional specs (WHAT, not HOW) | After an ADR is accepted; before writing a plan | `docs/templates/spec.md` |
| `docs/superpowers/plans/` | **Implementation plans** (HOW, step-by-step, executable) | After a spec is approved; this is the low-level design an agent executes | `docs/templates/plan.md` + `plan-review.md` |
| `docs/plans/` | Legacy iteration plans (ITERATION_00N_*) | **Do not add new files here.** Read-only audit archive. | — |
| `docs/templates/` | Blank templates | — | — |
| `docs/WORK_LOG.md` | Chronological audit of completed work | Append after every implementation | — |
| `.claude/tasks/<id>/` | Per-task artifacts for multi-session/agent work | When handing off to an agent loop or resuming across sessions | CLAUDE.md task-artifact section |

### Sequencing
```
Need to decide something structural?
  → ADR  (docs/adr/)

ADR accepted or decision already clear?
  → Spec  (docs/specs/)

Spec approved?
  → Plan  (docs/superpowers/plans/)

Plan written?
  → Plan review  (docs/superpowers/plans/*-review.md)

Plan approved?
  → Implement (one commit per task)
  → Verify (bin/rails test)
  → Update WORK_LOG.md + this INDEX.md
```

**Low-level design = superpowers/plans.** These are the files an agent reads to implement. They contain exact file paths, real code, exact commands with expected output, and a checkbox per step. If a plan file doesn't have all of that, it's not ready to execute.

---

## Architecture Decisions (ADRs)

| # | Decision | Status |
|---|----------|--------|
| [01](adr/ADR-0001-rails8-modular-monolith.md) | Rails 8 modular monolith, single DB | ✅ accepted |
| [02](adr/ADR-0002-jwt-and-role-rbac.md) | JWT auth + role RBAC (admin/moderator/player) | ✅ accepted |
| [03](adr/ADR-0003-fantasy-wallet-ledger-first.md) | Fantasy wallet, ledger-first | ✅ accepted |
| [04](adr/ADR-0004-dual-web-surfaces.md) | Dual web surfaces (backoffice + customer web) | ✅ accepted |
| [05](adr/ADR-0005-rbac-with-ad-hoc-grants.md) | RBAC with ad-hoc grants (deny overrides role) | ✅ accepted |
| [06](adr/ADR-0006-market-templates.md) | Market templates as first-class objects | ✅ accepted |
| [07](adr/ADR-0007-sse-for-live-market-updates.md) | SSE for live market updates | ✅ accepted |
| [08](adr/ADR-0008-modular-seams-for-microservices.md) | Modular seams for future microservices | ✅ accepted |
| [09](adr/ADR-0009-fixed-odds-house-liability-model.md) | Fixed-odds house liability model | ✅ accepted |
| [10](adr/ADR-0010-binary-market-line-model.md) | Binary market line model (YES/NO, UP/DOWN) | ✅ accepted |
| [11](adr/ADR-0011-betslip-and-cashout-contract.md) | Betslip + cashout quote-execute contract | ✅ accepted |
| [12](adr/ADR-0012-hot-cold-storage-with-redis-projections.md) | Hot/cold storage: PG + Redis + SSE | ✅ accepted |
| [13](adr/ADR-0013-pluggable-market-mechanisms.md) | Pluggable market mechanisms (CLOB, LMSR, Parimutuel, Fixed-odds) | ✅ accepted |
| [14](adr/ADR-0014-clob-order-book-migration.md) | CLOB order book migration (replace fixed-odds with CLOB as default) | ✅ accepted |

---

## Implementation Status

### ✅ Done
- Auth: JWT + session, register/login/me, roles
- RBAC: permissions, role_permissions, ad-hoc user_grants (deny overrides)
- Wallet + ledger (ADIV minor units)
- Market CRUD (admin JSON API: create, update, settle, risk)
- Market legs (admin JSON API)
- Bet placement — BetPlacementService (house risk check, fee, ledger debit)
- Bet void — BetVoidService (refund, ledger credit)
- **Settlement engine** — SettlementService (WON/LOST transitions, payout credits, audit) `3a1789a`
- Market templates — full CRUD (create, edit, update, deactivate) `5cb0ef3`
- **Backoffice markets section** — list, show, create, open, settle `5cb0ef3`
- Hot storage — Redis snapshot projection, MarketSnapshotProjector, ReconcileMarketHotStateJob, cold fallback
- SSE market stream — snapshot-first with cold fallback
- Faucet request flow (admin approve/reject + backoffice UI)
- **Binary line DB invariants** — exactly-2-legs enforced at model + DB trigger level
- **Betslip + cashout** — BetslipQuote/Execution models, services, web controllers+routes `c686641`
- **CI/CD** — GitHub Actions + scripts/validate.sh pre-commit hook + E2E job (Playwright/Chromium)
- **Pluggable market mechanisms** (ADR-0013) — CLOB order book, LMSR AMM, Parimutuel pool, Fixed-odds `b26bf56`
  - [x] DB: `taker_fee_bps`, `liquidity_subsidy_minor`, `spread_fee_bps`, `takeout_bps`, LMSR/parimutuel state columns, `Order` model + migration, `PriceSnapshot` model + migration
  - [x] Market model: MECHANISM_TYPES validation, `pricing_engine` factory, `clob?`/`lmsr?`/`parimutuel?`/`fixed_odds?` predicates, `lmsr_b_parameter` computed on open
  - [x] `Clob::OrderMatchingService` — price-time priority, partial fills, FOK/IOC/GTC, taker fee
  - [x] Admin + web CLOB order endpoints + `Web::OrderBooksController`
  - [x] `Lmsr::LmsrPricingService` (cost function, `b_from_subsidy`) + `Lmsr::LmsrTradeService`
  - [x] `Parimutuel::ParimutuelPoolService` + `Parimutuel::ParimutuelSettlementService`
  - [x] Settlement router — `SettlementService.settle!` branches on `mechanism_type`; `ClobSettlementHandler`, `LmsrSettlementHandler`
  - [x] `PriceSnapshotRecorder` + `RecordPriceSnapshotJob`
  - [x] Hot storage: `MarketSnapshotProjector` extended with CLOB/LMSR/parimutuel fields
  - [x] SSE: projector called after CLOB, LMSR, and parimutuel trades
  - [x] Backoffice UI: mechanism picker + conditional fee fields
  - [x] Web UI: mechanism-appropriate price display
  - 220 tests, 0 failures, 91.46% line coverage
- **CLOB order book completion** (ADR-0014) — fill ledger entries, last trade price, spread, CLOB positions endpoint `5d48ac1`
  - [x] `ORDER_FILL_STAKE` + `ORDER_FILL_CREDIT` ledger entries per fill with metadata
  - [x] `markets.last_fill_price_cents` updated on every fill
  - [x] Order book response: `last_trade_price`, `spread`
  - [x] `GET /web/positions` returns `clob_positions[]` with contract counts and unrealised value
  - [x] Fixed `order_book_summary` best-ask sort and spread sign
- **F-001: Market taxonomy** — `category` enum + `tags` jsonb; backoffice create form; customer filter bar + badges; full-text search (PRs #13–15, commits `286cf78`–`8496a72`)
- **F-002: Full-text search** — Arel ILIKE across question/description/tags (PR #16, `c400e5f`)
- **F-005: User profile page** — wallet stat-grid, P&L summary, bet history, faucet request form, nav balance chip (PR #17, `07d79ce`)
- **F-003: Market detail enrichment** — `close_at`, `resolution_criteria`, `resolution_source`; backoffice + customer display; admin API extended (PR #18, `b088d44`)
- **F-007: Public leaderboard** — ranked by net P&L, public page, nav link (PR #18)
- **Betting forms on market show** — quick-bet panel for all 4 mechanism types (fixed_odds/CLOB/LMSR/parimutuel); signed-in users get form, guests get sign-in prompt (PR #18)
- **UX improvements** — CSS design system (pill filters, stat-cards, balance chip); market show price panels per mechanism; 17-market rich seeds (PR #18)
- **F-006: Backoffice market create UX** — fieldset grouping, live preview, improved help text (PR #21, `528e7ba`)
- **E2E quick-bet coverage** — CLOB/LMSR/parimutuel form tests; fixed `side` upcase bug in LMSR+parimutuel controllers (PR #23, `6a61122`)
- **E2E settlement coverage** — CLOB/LMSR/parimutuel settlement-scenario tests (settle YES + NO per mechanism, 10 tests total in `settlement-scenarios.spec.js`)
- **E2E multi-player settlement** — 16 table-driven tests (4 scenarios × 4 mechanisms); isolated browser contexts per player; API-driven wallet setup; balance assertions after settlement (PR #25)
- **E2E + Docker Compose production mode** — `docker-compose.e2e.yml` overlay runs Playwright against `RAILS_ENV=production`; Zeitwerk eager-load crash fixed (removed `module Domain` wrapper from catalog files); `package-lock.json` committed; stale E2E Docker files removed (PR #26, `490f215`)
- **F-009: Automated market close** — `closed: 4` enum, DB check constraint, `CloseExpiredMarketsJob` (solid-queue every 5 min), `BetPlacementService` close_at guard, settlement accepts closed, backoffice/customer closed banners
- **F-012 + F-013: Player positions + execution confirmation HTML views** — `GET /web/positions` and `GET /web/betslips/executions/:id` now render HTML alongside JSON; Positions nav link added
- **F-015: Cross-mechanism leaderboard** — aggregates all ledger entry types (fixed-odds, CLOB, LMSR, parimutuel); removed fixed-odds-only bet count columns
- **F-017: Market list pagination** — web (12/page) and backoffice (20/page) with Previous/Next controls
- **F-016 / TD-003: LMSR subsidy exhaustion guard** — `lmsr_realized_loss_minor` column; market locked before pricing; outflow guard raises when net payout would exceed `liquidity_subsidy_minor`; side/quantity input validation (PR #30, `284928b`)
- **TD-007: Backoffice open-market E2E** — Playwright spec: moderator creates draft → opens market; asserts form transitions (PR #31, `256932d`)
- **TD-011: Backoffice market edit — description field** — `description` added to update params and Edit Details form (PR #31, `256932d`)
- **DD-004: PostgreSQL test DB** — `schema_format = :sql`; `db/structure.sql`; Rake hook strips pg_dump incompatibilities; CI postgres:17 service; trigger condition fixed `>= 2` (PR #33, `889d951`)
- **DD-002 wireframes docs** — UX wireframes v1 under `docs/design/` (5 design docs + pan/zoom canvas HTML + 6 JSX component files) (PR #34, `f784b9b`)
- **DD-002: LMSR positions** — `lmsr_positions` table + model; trade service upserts positions; settlement pays 100 minor/contract to winners; `positions_from_ledger` audit path; `schema.rb` removed in favour of `structure.sql` (PR #35, `f0a8b12`)

### ⏳ Next
- See `docs/wiki/tech-debt-backlog.md` for prioritised backlog (F-010 through F-018, TD-001 through TD-012)

### Plans + Reviews

| Feature | Plan | Review | Status |
|---------|------|--------|--------|
| Pluggable market mechanisms | [plan](superpowers/plans/2026-05-27-pluggable-market-mechanisms.md) | [review](superpowers/plans/2026-05-27-pluggable-market-mechanisms-review.md) | ✅ implemented |
| Betslip + cashout | [plan](superpowers/plans/2026-05-26-betslip-cashout.md) | [review](superpowers/plans/2026-05-26-betslip-cashout-review.md) | ✅ implemented |
| Hot/cold storage | [plan](superpowers/plans/2026-05-26-hot-cold-storage.md) | [review](superpowers/plans/2026-05-26-hot-cold-storage-review.md) | ✅ implemented |
| Binary line invariants | [plan](superpowers/plans/2026-05-26-binary-line-invariants.md) | [review](superpowers/plans/2026-05-26-binary-line-invariants-review.md) | ✅ implemented |
| Faucet backoffice UI | [plan](superpowers/plans/2026-05-26-faucet-backoffice-ui.md) | [review](superpowers/plans/2026-05-26-faucet-backoffice-ui-review.md) | ✅ implemented |
| Market taxonomy (F-001) | [plan](superpowers/plans/2026-05-27-market-taxonomy.md) | — | ✅ implemented |
| Backoffice UI gaps | [plan](superpowers/plans/2026-05-26-backoffice-ui-gaps.md) | — | ✅ implemented |
| Settlement engine | [plan](superpowers/plans/2026-05-26-settlement-engine.md) | — | ✅ implemented |
| CLOB order book completion | [plan](superpowers/plans/2026-05-27-clob-order-book.md) | — | ✅ implemented |
| F-006: Backoffice market create UX | [plan](superpowers/plans/2026-05-28-f006-backoffice-market-create-ux.md) | — | ✅ implemented |
| Dockerise E2E suite | [plan](superpowers/plans/2026-05-28-dockerise-e2e-suite.md) | — | ✅ implemented |
| F-009: Automated market close | [plan](superpowers/plans/2026-05-28-f009-automated-market-close.md) | — | ✅ implemented |

---

## Key file map

```
app/
  controllers/
    admin/                      # JSON API (JWT auth)
      markets_controller.rb       create, update, settle→SettlementService, risk
      bets_controller.rb          void
      market_legs_controller.rb
      faucet_requests_controller.rb
    backoffice/                 # HTML (session auth, moderator+)
      markets_controller.rb       list, show, create, open, settle
      templates_controller.rb     full CRUD + create_market
      permissions_controller.rb
      grants_controller.rb
      dashboard_controller.rb
    web/                        # HTML (no auth for index/show; player auth for betslip/positions/profile)
      markets_controller.rb       index (search+filter), show (stats, price panels, resolution)
      betslips_controller.rb      POST /web/betslips/quotes, /web/betslips/execute
      betslip_executions_controller.rb  GET /web/betslips/executions/:id
      positions_controller.rb     GET /web/positions, POST cashout_quotes/cashout_execute
      profile_controller.rb       GET /web/profile (wallet, P&L, bet history)
      faucet_requests_controller.rb  POST /web/faucet_requests
    auth/sessions_controller.rb # register, login, me (JWT)
  services/
    settlement_service.rb         bet WON/LOST + payout on market settle
    bet_placement_service.rb      place bet, risk check, ledger debit
    bet_void_service.rb           void bet, refund, ledger credit
    betslip_quote_service.rb      multi-bet quote with idempotency
    betslip_execution_service.rb  quote→bets all-or-nothing transaction
    cashout_quote_service.rb      cashout payout quote
    cashout_execution_service.rb  void bet + credit wallet
    house_risk_service.rb         worst-case liability formula
    market_from_template_service.rb
    hot_storage/                  Redis projection (projector, reader, store)
  models/
    market.rb / market_leg.rb / market_template.rb
    bet.rb (status: open/settled_win/settled_loss/voided)
    user.rb / wallet.rb / ledger_entry.rb / audit_event.rb
  domain/catalogs/              action_catalog, permission_catalog, template_catalog
test/
  services/                     unit tests
  integration/                  endpoint + flow tests
  fixtures/                     users, markets, legs, bets, wallets, permissions
  support/hot_storage/fake_redis.rb
docs/
  INDEX.md                      ← YOU ARE HERE
  WORK_LOG.md                   chronological audit (read for history)
  templates/                    adr.md · spec.md · plan.md · plan-review.md
  adr/                          ADR-0001 to ADR-0012
  specs/                        LEGACY — functional specs per iteration
  plans/                        LEGACY — iteration plans + MASTER_TODO_TREE
  superpowers/plans/            CURRENT — executable implementation plans
.claude/tasks/                  per-task artifacts for multi-session work
```

---

## Fixtures cheat-sheet

| Fixture | Role | Password | Wallet |
|---------|------|----------|--------|
| `users(:admin)` | admin | password123 | 100_000 |
| `users(:moderator)` | moderator | password123 | 50_000 |
| `users(:player)` | player | password123 | 1_000 |
| `markets(:open_market)` | status open (1), `fixed_odds` | — | legs: YES/NO |
| `markets(:draft_market)` | status draft (0), `fixed_odds` | — | no legs |
| `markets(:clob_market)` | status open (1), `clob`, `taker_fee_bps: 70` | — | legs: YES/NO |
| `markets(:lmsr_market)` | status open (1), `lmsr`, `b=1443.07`, `subsidy=100k` | — | legs: YES/NO |
| `markets(:parimutuel_market)` | status open (1), `parimutuel`, `takeout_bps: 1500` | — | legs: YES/NO |

**Admin API auth in tests:** `auth_headers_for(users(:admin))` → returns `Authorization` + `Content-Type: application/json`. Always add `as: :json` to POST calls.

**Backoffice auth in tests:** `post "/signin", params: { email: users(:admin).email, password: "password123" }` (session cookie auto-applied to subsequent requests in the same session).

**Settlement test gotcha:** fixture bets on `open_market` interfere with settlement tests. Call `@market.bets.delete_all` in setup before creating test-controlled bets.

---

## Running the project

```bash
docker compose up -d db       # start postgres (required before tests)
bin/rails db:prepare          # create + migrate + seed
bin/rails test                # full suite (90% coverage threshold enforced)
bin/rails test path/file.rb   # single file
docker compose up -d          # full stack (web + db + redis)
```
