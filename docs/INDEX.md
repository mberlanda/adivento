# Adivento Docs Index

**Load this file first in any new session.** Read only the sections you need — follow links for details.

---

## Project in one paragraph
Prediction markets POC: Rails 8 monolith, PostgreSQL, Redis. Two HTML surfaces — `backoffice/` (session auth, moderator+) for operators and `web/` (public) for customers. `admin/` is a JSON API (JWT). Fixed-odds house underwriting with per-market liability caps. Fantasy wallet denominated in ADIV (minor units = cents).

## Tech stack quick-ref
| Layer | Choice |
|-------|--------|
| Framework | Rails 8 |
| DB | PostgreSQL (Docker) |
| Cache/stream | Redis (hot snapshots + SSE) |
| Auth | Session cookie (backoffice/web) · JWT Bearer (admin API) |
| Tests | Minitest, SimpleCov ≥90% line coverage |
| E2E | Playwright under `e2e/playwright/` |

---

## Doc folder guide — what goes where and when

Use this table to decide which doc type to create and in what order. The lifecycle runs top to bottom.

| Folder | Doc type | When to create | Template |
|--------|----------|----------------|----------|
| `docs/adr/` | Architecture Decision Record | Before building anything architectural — new surface, new data model, new external dependency | [templates/adr.md](templates/adr.md) |
| `docs/specs/` | Functional spec | After ADR (if needed), before the plan — defines WHAT (contracts, invariants, accounting) | [templates/spec.md](templates/spec.md) |
| `docs/superpowers/plans/` | Implementation plan | After spec is approved — defines HOW step by step, one task per commit | [templates/plan.md](templates/plan.md) |
| `docs/superpowers/plans/` | Plan review | After plan is written — quick sanity check before execution | [templates/plan-review.md](templates/plan-review.md) |
| `docs/WORK_LOG.md` | Audit entry | After implementation — append one entry per feature with commit refs | — |
| `.claude/tasks/<id>/` | Task artifacts | For multi-session or blocked tasks — TASK.md + PLAN.md + Q&A.md | See CLAUDE.md §4 |

### Sequencing rule
```
ADR (if architectural) → Spec → Plan → Plan-review → Implement → Update WORK_LOG + INDEX
```
Skip ADR for pure feature work (no new architectural choice). Skip spec for trivial changes (<1 day).
**Never skip the plan.** Plans are the primary guardrail for sub-agent execution.

### Naming conventions
- ADR: `ADR-NNNN-kebab-title.md` — sequential, never renumbered
- Specs: `YYYY-MM-DD-feature-name.md` (new) or `ITERATION_00N_FEATURE_SPEC.md` (legacy)
- Plans: `YYYY-MM-DD-feature-name.md` in `docs/superpowers/plans/`
- Plan reviews: `YYYY-MM-DD-feature-name-review.md` (same folder)

---

## Architecture Decisions (ADRs)

| # | Decision | Status |
|---|----------|--------|
| [01](adr/ADR-0001-rails8-modular-monolith.md) | Rails 8 modular monolith, single DB | ✅ accepted |
| [02](adr/ADR-0002-jwt-and-role-rbac.md) | JWT auth + role RBAC (admin/moderator/player) | ✅ accepted |
| [03](adr/ADR-0003-fantasy-wallet-ledger-first.md) | Fantasy wallet, ledger-first accounting | ✅ accepted |
| [04](adr/ADR-0004-dual-web-surfaces.md) | Dual web surfaces (backoffice + customer web) | ✅ accepted |
| [05](adr/ADR-0005-rbac-with-ad-hoc-grants.md) | RBAC with ad-hoc grants (deny overrides role) | ✅ accepted |
| [06](adr/ADR-0006-market-templates.md) | Market templates as first-class objects | ✅ accepted |
| [07](adr/ADR-0007-sse-for-live-market-updates.md) | SSE for live market updates | ✅ accepted |
| [08](adr/ADR-0008-modular-seams-for-microservices.md) | Modular seams for future microservices | ✅ accepted |
| [09](adr/ADR-0009-fixed-odds-house-liability-model.md) | Fixed-odds bounded house liability | ✅ accepted |
| [10](adr/ADR-0010-binary-market-line-model.md) | Binary market line model (YES/NO, UP/DOWN) | ✅ accepted |
| [11](adr/ADR-0011-betslip-and-cashout-contract.md) | Betslip + cashout quote-execute contract | 🔵 proposed |
| [12](adr/ADR-0012-hot-cold-storage-with-redis-projections.md) | Hot/cold storage: PG + Redis + SSE | 🔵 proposed |

---

## Implementation status

### ✅ Done
- Auth: JWT + session, register/login/me
- RBAC: roles + permissions + ad-hoc grants
- Wallet + ledger + audit events
- Market CRUD (admin JSON API + backoffice HTML)
- Market legs
- Bet placement (`BetPlacementService`) with house risk check
- Bet void (`BetVoidService`)
- **Settlement engine** (`SettlementService` — bets → WON/LOST, payouts credited)
- Market templates: full CRUD (create, edit, update, deactivate)
- **Backoffice markets section**: list, show, create, open (draft→open), settle
- Hot storage: Redis snapshots, `MarketSnapshotProjector`
- SSE market stream
- Faucet request flow

### 🔄 In progress
- PLAN-D: E2E Playwright tests (scaffolded; blocked on Docker overlay2 issue)

### ⏳ Todo — in priority order
1. **PLAN-B: Betslip + cashout** → [spec](specs/ITERATION_005_BETSLIP_CASHOUT_SPEC.md) · [plan](plans/ITERATION_005_BETSLIP_CASHOUT_ARCHITECTURE_PLAN_V1.md) · needs new superpowers plan
2. **PLAN-C: Hot/cold storage SSE fanout + reconciliation** → [spec](specs/ITERATION_005_HOT_COLD_STORAGE_SPEC.md) · [plan](plans/ITERATION_005_HOT_COLD_STORAGE_ARCHITECTURE_V1.md)
3. **Binary line invariants** — enforce exactly-2-legs at DB level → [spec](specs/ITERATION_005_BINARY_MARKET_LINES_SPEC.md)
4. Faucet request backoffice HTML UI

**Master TODO:** [plans/ITERATION_005_MASTER_TODO_TREE.md](plans/ITERATION_005_MASTER_TODO_TREE.md)

---

## Active implementation plans (superpowers format)

These are the **low-level design** docs — step-by-step task lists ready for agent execution. Load these when implementing, not the legacy plans.

| Plan | Status | Description |
|------|--------|-------------|
| [2026-05-26-backoffice-ui-gaps.md](superpowers/plans/2026-05-26-backoffice-ui-gaps.md) | ✅ done | Template CRUD + backoffice markets section |
| [2026-05-26-settlement-engine.md](superpowers/plans/2026-05-26-settlement-engine.md) | ✅ done | SettlementService + admin/backoffice wiring |

Create new plans with `docs/templates/plan.md`. Save to `docs/superpowers/plans/YYYY-MM-DD-feature.md`.

---

## Key file map
```
app/
  controllers/
    admin/               # JSON API (JWT Bearer)
      markets_controller.rb     # create, update, settle (→ SettlementService), risk
      bets_controller.rb        # void
      market_legs_controller.rb
      faucet_requests_controller.rb
    backoffice/          # HTML (session, moderator+)
      markets_controller.rb     # list, show, create, open, settle
      templates_controller.rb   # full CRUD + create_market
      permissions_controller.rb
      grants_controller.rb
    web/                 # HTML (public)
      markets_controller.rb     # index, show
  services/
    settlement_service.rb       # bet transitions + payouts on settle
    bet_placement_service.rb    # risk check + stake ledger
    bet_void_service.rb         # refund + ledger
    house_risk_service.rb       # worst-case liability formula
    market_from_template_service.rb
    hot_storage/                # Redis snapshot projection
  models/
    market.rb  market_leg.rb  market_template.rb
    bet.rb  user.rb  wallet.rb  ledger_entry.rb  audit_event.rb
  domain/
    catalogs/            # action_catalog, permission_catalog, template_catalog
docs/
  INDEX.md               ← THIS FILE — load first
  WORK_LOG.md            ← append after every feature implementation
  templates/             ← adr.md, spec.md, plan.md, plan-review.md
  adr/                   ← ADR-NNNN-*.md (architectural decisions)
  specs/                 ← functional specs (WHAT)
  plans/                 ← legacy iteration plans (ITERATION_00N_*)
  superpowers/plans/     ← implementation plans (HOW, agent-executable)
.claude/
  tasks/                 ← per-task artifacts for multi-session/blocked work
    <task-id>/
      TASK.md            ← task description
      PLAN.md            ← checklist with status markers
      Q&A.md             ← blocking questions + answers (append-only)
```

---

## Fixtures cheat-sheet (for tests)
| Fixture | Role | Password | Wallet (minor) |
|---------|------|----------|----------------|
| `users(:admin)` | admin | password123 | 100_000 |
| `users(:moderator)` | moderator | password123 | 50_000 |
| `users(:player)` | player | password123 | 1_000 |
| `markets(:open_market)` | status: open | — | legs: YES, NO |
| `markets(:draft_market)` | status: draft | — | no legs |
| `market_legs(:yes_leg)` | YES, 5000 odds | — | on open_market |
| `market_legs(:no_leg)` | NO, 5000 odds | — | on open_market |

**Gotcha:** `open_market` has fixture bets. Call `@market.bets.delete_all` in setup when testing settlement to avoid fixture interference.

Auth in tests:
- **Admin API:** `headers: auth_headers_for(users(:admin)), as: :json`
- **Backoffice:** `post "/signin", params: { email: users(:admin).email, password: "password123" }`

---

## Running things
```bash
docker compose up -d db          # REQUIRED before running tests
bin/rails db:prepare             # create + migrate + seed test db
bin/rails test                   # full suite (90% coverage threshold)
bin/rails test test/path/file.rb -v  # single file, verbose
docker compose up -d             # start full app (web + db + redis)
```

**Note:** Tests hang silently if Docker DB is not running. Always `docker compose up -d db` first.
