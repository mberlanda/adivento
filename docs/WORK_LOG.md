# Work Log

Chronological audit of implemented features. Each entry: what was built, key files, commit ref.

---

## 2026-05-27 — Pluggable Market Mechanisms (CLOB, LMSR, Parimutuel, Fixed-odds)

**Commits:** `90728bd`–`b26bf56`

### Architecture
- `markets.mechanism_type` (existing string column) is the single branch point across all mechanism logic
- Per-mechanism fee columns added (`taker_fee_bps`, `liquidity_subsidy_minor`, `spread_fee_bps`, `takeout_bps`)
- LMSR state columns on markets row (`lmsr_b_parameter`, `lmsr_q_yes`, `lmsr_q_no`)
- Parimutuel pool state on markets row (`parimutuel_pool_yes_minor`, `parimutuel_pool_no_minor`)
- `Market#pricing_engine` factory returns mechanism-specific engine (value object)
- No `ParimutuelBet` model in v1 — stakes tracked via `LedgerEntry(entry_type: "PARIMUTUEL_STAKE", metadata: {market_id:, side:})`

### Key files
- `app/models/market.rb` — MECHANISM_TYPES constant, mechanism validations, predicates (`clob?` etc.), inner engine classes, `lmsr_b_parameter` computed on draft→open
- `app/models/order.rb` + migration — CLOB order book with status/TIF enums
- `app/services/clob/order_matching_service.rb` — price-time priority, partial fills, FOK/IOC, taker fee
- `app/services/lmsr/lmsr_pricing_service.rb` — LMSR cost function, `b_from_subsidy`
- `app/services/lmsr/lmsr_trade_service.rb` — place LMSR trade, debit wallet, write ledger + audit
- `app/services/parimutuel/parimutuel_pool_service.rb` — stake, pool update, implied odds
- `app/services/parimutuel/parimutuel_settlement_service.rb` — takeout deduction, pro-rata payout via ledger entries
- `app/services/settlement_service.rb` — routes to mechanism handlers; `settle_fixed_odds!` private for existing code
- `app/services/settlement/clob_settlement_handler.rb` — cancel open orders, credit winning contracts
- `app/services/settlement/lmsr_settlement_handler.rb` — v1 stub; individual payouts deferred (v2 needs position tracking)
- `app/services/hot_storage/market_snapshot_projector.rb` — extended with CLOB/LMSR/parimutuel snapshot fields
- `app/services/price_snapshot_recorder.rb` + job — periodic mechanism-appropriate snapshots
- `app/controllers/admin/orders_controller.rb` — admin order placement/cancellation
- `app/controllers/web/orders_controller.rb`, `order_books_controller.rb`, `lmsr_trades_controller.rb`, `parimutuel_bets_controller.rb`
- Backoffice form: mechanism picker with conditional fee fields
- Web market show: mechanism-appropriate price display

### Test coverage
- 216 tests, 0 failures, 91.87% line coverage
- New test files: `test/services/clob/`, `test/services/lmsr/`, `test/services/parimutuel/`, `test/integration/clob_orders_test.rb`, `test/integration/lmsr_trades_test.rb`, `test/integration/parimutuel_bets_test.rb`, `test/integration/web_orders_test.rb`

### Known v2 gaps (see FINDINGS.md)
- LMSR subsidy exhaustion check (`lmsr_realized_loss_minor` column)
- `ParimutuelBet` model for per-bettor history
- LMSR individual settlement payouts (needs position tracking model)
- Cross-mechanism leaderboard aggregation

---

## 2026-05-26 — Betslip + Cashout, Binary Invariants, Faucet UI, Hot/Cold Storage, CI/CD

**Commits:** `fb448ad`–`c686641`

### Betslip + Cashout (PLAN-B)
- `BetslipQuote` model + migration — status enum, idempotency_key (unique), expires_at, items (json), total_stake_minor
- `BetslipExecution` model + migration — belongs_to betslip_quote, bet_ids (json), status
- `BetslipQuoteService.call(user:, items:, idempotency_key:)` — validates open market, computes payouts, idempotency replay, conflict detection
- `BetslipExecutionService.execute!(quote:, actor:)` — expired/already-executed guards, row-level lock, all-or-nothing via BetPlacementService
- `CashoutQuoteService.quote(bet:)` → Struct with gross/fee/net payout
- `CashoutExecutionService.execute!(bet:, actor:)` — voids bet, credits wallet, writes ledger + audit
- `Web::BetslipsController`, `Web::BetslipExecutionsController`, `Web::PositionsController` + routes
- 167 tests, 0 failures, 95.77% line coverage

### Binary Line DB Invariants
- `MarketLeg` model: `validate :market_leg_count_within_limit, on: :create` (max 2)
- `Market` model: `validate :requires_two_legs_to_open` (exactly 2 legs required to open)
- `Admin::MarketLegsController`: early 422 if market already has 2 legs
- PostgreSQL BEFORE INSERT trigger `enforce_max_two_market_legs`

### Faucet Request Backoffice UI
- `Backoffice::FaucetRequestsController` — index/approve/reject, delegates to `WalletGrantService`
- `app/views/backoffice/faucet_requests/index.html.erb` — pending + processed tables

### Hot/Cold Storage Finalisation (PLAN-C)
- `MarketSnapshotProjector` — hardened with per-store error isolation
- `MarketSnapshotReader` — cold fallback on Redis error
- `ReconcileMarketHotStateJob` — per-market error isolation, open+settled scope
- SSE controller — snapshot-first emission with cold fallback

### CI/CD
- `.github/workflows/ci.yml` — push/PR trigger, bundler cache, schema load, scripts/validate.sh, coverage artifact
- `scripts/validate.sh` — rubocop + db:schema:load + test suite (reusable locally)
- `scripts/install-hooks.sh` — installs validate.sh as git pre-commit hook
- `Gemfile.lock` — added x86_64-linux platform for GitHub Actions runners

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
