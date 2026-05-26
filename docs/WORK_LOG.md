# Work Log

Chronological audit of implemented features. Each entry: what was built, key files, commit ref.

---

## 2026-05-26 — Doc system + SDL lifecycle + legacy cleanup

**Commits:** `199bfb4`, `ce2abe6`

- `CLAUDE.md` rewritten: full SDL lifecycle (ADR→spec→plan→review→implement→verify→docs), task artifact protocol (`.claude/tasks/<id>/`), Q&A blocking convention, commit discipline, docs maintenance obligation.
- `docs/INDEX.md` expanded: folder guide table, sequencing flowchart, `superpowers/plans/` labelled as low-level design, fixture gotchas, auth patterns.
- `docs/templates/` created: `adr.md`, `spec.md`, `plan.md`, `plan-review.md` — blank canonical templates for all future docs.
- `.claude/tasks/README.md`: task artifact resume protocol.
- All `docs/specs/ITERATION_*` and `docs/plans/ITERATION_*` stamped with LEGACY header — do not imitate their format.

---

## 2026-05-26 — Settlement Engine + Backoffice Markets

**Commits:** `3a1789a`, `5cb0ef3`

### Settlement Engine
- `SettlementService.settle!` — single transaction: settles market, transitions all open bets to WON/LOST, credits payout to winner wallets, writes ledger + audit entries, projects hot storage.
- `Admin::MarketsController#settle` now delegates to `SettlementService` (was inline, bets were never settled).
- Tests: 8 unit + 3 integration (wallet balance check, invalid outcome, non-open guard).
- Files: `app/services/settlement_service.rb`, `test/services/settlement_service_test.rb`, `test/integration/admin_market_settle_test.rb`

### Backoffice Markets Section (was completely absent)
- `Backoffice::MarketsController`: index, show, create, open (draft→open), settle.
- Create form: question, description, legs (comma-separated), fee_bps, liability_cap_minor.
- Settle form on show page: dropdown of valid leg labels, delegates to SettlementService.
- Views: `app/views/backoffice/markets/index.html.erb`, `show.html.erb`
- Sidebar updated with "Markets" link.
- Files: `app/controllers/backoffice/markets_controller.rb`, views, `config/routes.rb`

### Backoffice Template CRUD (edit + deactivate were missing)
- `TemplatesController`: added `edit`, `update`, `destroy` (soft-delete: sets active=false).
- Shared `_form.html.erb` partial for create and edit.
- `create_market` now redirects to `backoffice_market_path` instead of web surface.
- 10 integration tests added.
- Files: `app/controllers/backoffice/templates_controller.rb`, `app/views/backoffice/templates/`

---

## 2026-05-25 — Iteration 005: Bets, Hot Storage, E2E scaffold

**Commits:** `322498a`, `834a77d`, `3d6dd15`

- BetPlacementService with house risk check (HouseRiskService)
- BetVoidService with refund ledger
- Hot storage Redis projection (MarketSnapshotProjector, MarketSnapshotReader, Store)
- SSE market stream
- Playwright E2E scaffold under `e2e/playwright/` (blocked on Docker overlay2)
- Action catalog (available actions per user/market state)
- Integration test coverage expanded

---

## 2026-05-23 — Iteration 002: Dual web surfaces, RBAC, templates

**Commits:** `834a77d`, `3d6dd15`, `827354a`

- Dual surfaces: `web/` (customer) + `backoffice/` (operator)
- RBAC: role_permissions + user_grants (deny overrides)
- Market templates model + MarketFromTemplateService
- Backoffice: dashboard, permissions matrix, ad-hoc grants, templates (create only at the time)
- SSE settlements endpoint
- Integration test suite (>90% coverage)

---

## 2026-05-20 — Iteration 001: Rails 8 monolith baseline

**Commit:** `ecdb287`, `74ebedd`

- Rails 8 project init
- Auth: JWT + session, User model (admin/moderator/player roles)
- Market + MarketLeg models
- Wallet + LedgerEntry + AuditEvent
- FaucetRequest flow
- Admin API (JSON): markets CRUD, legs, faucet approve/reject
- Docker Compose runtime (db + web + redis)
