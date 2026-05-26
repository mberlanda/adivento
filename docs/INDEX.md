# Adivento Docs Index

**Load this file first in any new session.** Follow links only for details you need.

## Project in one paragraph
Prediction markets POC: Rails 8 monolith, PostgreSQL, Redis. Two HTML surfaces — `backoffice/` (session auth, moderator+) for operators, `web/` (no auth) for customers. `admin/` namespace is a JSON API (JWT). Fixed-odds house underwriting with per-market liability caps. Fantasy wallet denominated in ADIV (minor units = cents).

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
- **CI/CD** — GitHub Actions + scripts/validate.sh pre-commit hook

### 🔄 In Progress
- PLAN-D: Playwright E2E — blocked on Docker overlay2 filesystem issue

### ⏳ Next
- (all planned features implemented — resume E2E when Docker overlay2 resolved)

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
    web/                        # HTML (no auth for index/show; player auth for betslip/positions)
      markets_controller.rb
      betslips_controller.rb      POST /web/betslips/quotes, /web/betslips/execute
      betslip_executions_controller.rb  GET /web/betslips/executions/:id
      positions_controller.rb     GET /web/positions, POST cashout_quotes/cashout_execute
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
| `markets(:open_market)` | status open (1) | — | legs: YES/NO |
| `markets(:draft_market)` | status draft (0) | — | no legs |

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
