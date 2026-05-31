# Work Log

Chronological audit of implemented features. Each entry: what was built, key files, commit ref.

---

## 2026-05-30 — Wave 2: CLOB correctness (TD-020 / D3, TD-021 / D4, TD-017 / D2)

**D3 — Centralize CLOB trading-state guards (TD-020)**
- Added `validate_market_trading_state!` to `Clob::OrderMatchingService#call` as the first step in the transaction. Raises `Market is not open` or `Market is closed for new bets` before any order row is created.
- Removed duplicate `open?` and `close_at` guards from `Web::OrdersController#create`; admin controller now inherits the same protection via the service.
- Key files: `app/services/clob/order_matching_service.rb`, `app/controllers/web/orders_controller.rb`, `test/services/clob/order_matching_service_test.rb`, `test/integration/clob_orders_test.rb`

**D4 — Shared CLOB order cancellation service (TD-021)**
- Created `Clob::OrderCancellationService` that locks the order row + wallet inside the transaction, releases `reserved_minor`, writes an `order.cancel` AuditEvent, and returns a typed `Result`.
- Refactored `Admin::OrdersController#destroy` and `Web::OrdersController#destroy` to delegate to the service (web previously wrote no audit row).
- Added duplicate-cancel regression test.
- Key files: `app/services/clob/order_cancellation_service.rb`, `app/controllers/admin/orders_controller.rb`, `app/controllers/web/orders_controller.rb`

**D2 — MarketCancellationService + backoffice cancel (TD-017)**
- Created `MarketCancellationService` with atomic cross-mechanism refund: fixed-odds bets voided + refunded, parimutuel stakes refunded + pools reset, LMSR costs refunded from `lmsr_trade.place` audit events + positions zeroed, CLOB open/partial orders cancelled + reservations released + net cash refunded/clawed-back.
- Added `POST /backoffice/markets/:id/cancel` route, `Backoffice::MarketsController#cancel` action, `market.cancel` permission (admin-only), and cancel form on the market show page.
- 329 tests, 0 failures. Coverage 92.63%.

---

## 2026-05-30 — Wave 1 backend quick wins

- TD-016: Admin JSON API now permits `category` and `tags: []` on market create/update; added regression coverage for categorized/tagged API market creation.
- TD-022: RuboCop file-path/style gate is clean; tracked the `Rails/FilePath` item as resolved.
- TD-015: Leaderboard P&L now counts `CLOB_SELL_CREDIT` and `PARIMUTUEL_REFUND` as returns, and `LMSR_FEE`/`CLOB_FEE` as costs.
- TD-014: Player positions page and JSON response now include LMSR holdings from `lmsr_positions`.
- Key files: `app/controllers/admin/markets_controller.rb`, `app/controllers/web/leaderboard_controller.rb`, `app/controllers/web/positions_controller.rb`, `app/views/web/positions/index.html.erb`, `test/integration/admin_permissions_test.rb`, `test/integration/web_leaderboard_test.rb`, `test/integration/web_positions_test.rb`

---

## 2026-05-30 — docs(pm): project-management sync of trackers

- Restructured `.claude/tasks/ATTENTION.md` "Ready for Autonomous Work" into a **dependency-ordered execution plan** (Waves 1–5). Each item is tagged with an **owner** (🔴 Opus 4.8 = financial/concurrency/cross-system; 🟢 Sonnet = feature slices; 🔵 Codex = trivial fixes + docs/planning), a **complexity** (XS–L), and explicit **Depends on**. Merged each `D#` plan with its `TD-###` (same work).
- Added a **Backlog trackers (sources of truth)** table (one concern per file) so status changes land in the owning tracker.
- Added missing `TD-034` to the ATTENTION index.
- Fixed `docs/INDEX.md` staleness: TD-013/018/019 are done; F-004/F-008/F-010 are now planned (D6/D8/D7); added D2/D5/D6 plan rows.
- `tech-debt-backlog.md`: TD-020/TD-021 now reference their D3/D4 plans.
- Key files: `.claude/tasks/ATTENTION.md`, `docs/INDEX.md`, `docs/wiki/tech-debt-backlog.md`, `docs/WORK_LOG.md`

---

## 2026-05-30 — docs(planning): detailed plans for D3, D4, D7, D8

- Added executable plans for D3 CLOB trading-state guards and D4 shared CLOB order cancellation service.
- Added a dedicated-table spec and executable plan for D8 watchlists/notifications.
- Refined the existing D7 resolution transparency spec/plan to use the same 20-character mandatory-note rule.
- Updated `.claude/tasks/ATTENTION.md`, the decision dispatch tracker, and `docs/INDEX.md` with the new artifact links.
- Key files: `docs/superpowers/plans/2026-05-30-d3-clob-trading-state-guards.md`, `docs/superpowers/plans/2026-05-30-d4-clob-order-cancellation-service.md`, `docs/specs/2026-05-30-watchlists-notifications.md`, `docs/superpowers/plans/2026-05-30-d8-watchlists-notifications.md`

---

## 2026-05-30 — docs(planning): decision planning dispatch todos

- Recorded approved recommended options for Decisions 2-11 as dispatchable planning todos.
- Added a resume checkpoint and agent dispatch batches so planning work can be resumed after quota/context limits.
- Linked the tracker from `.claude/tasks/ATTENTION.md` and `docs/INDEX.md`.
- Decision 1 backend correctness remains intentionally separate because Claude is already progressing it.
- Key files: `docs/superpowers/plans/2026-05-30-decision-planning-dispatch.md`, `.claude/tasks/ATTENTION.md`, `docs/INDEX.md`

---

## 2026-05-30 — UX-036 / UX-023: web registration form

- New `GET /register` + `POST /register` (`Web::RegistrationsController`, subclasses `ActionController::Base` like the sessions controller) create a `player` account, sign the user in via the session cookie, and redirect to the home page with a faucet nudge. Invalid input (e.g. duplicate email) re-renders the form with errors and `422`.
- Added a "Create an account" link to the sign-in page.
- Closes the new-player funnel that was previously only reachable through the JWT `POST /auth/register` API.
- Tier 0 item #4 of 4 from the deep-review synthesis.
- Key files: `config/routes.rb`, `app/controllers/web/registrations_controller.rb`, `app/views/web/registrations/new.html.erb`, `app/views/web/sessions/new.html.erb`, `test/integration/web_registration_test.rb`

---

## 2026-05-29 — TD-013: lock wallet rows across all mutation paths

- `BetPlacementService` now acquires `user.wallet.lock!` inside the transaction and re-checks the balance authoritatively before debiting (the pre-transaction check is kept only as a cheap fast-fail). Fixes the TOCTOU double-spend where two concurrent placements both passed a stale balance check.
- Added the same `wallet.lock!` to every other unlocked wallet mutation: `BetVoidService`, `CashoutExecutionService`, `SettlementService#settle_fixed_odds!`, `Settlement::ClobSettlementHandler` Pass 1, `WalletGrantService#approve!`, `Parimutuel::ParimutuelSettlementService#refund_all!`.
- `Admin::OrdersController#destroy` re-loads and locks the order row inside the transaction and recomputes the released amount under lock (partial TD-021), matching `Web::OrdersController#destroy`.
- New concurrency test `test/services/bet_placement_concurrency_test.rb` (real threads, `use_transactional_tests = false`): two simultaneous placements on a one-bet balance produce exactly one bet.
- Tier 0 item #3 of 4 from the deep-review synthesis.

---

## 2026-05-29 — TD-019: reserve contracts for open CLOB sell orders

- `Clob::OrderMatchingService#validate_sell_position!` now subtracts the unfilled quantity of the user's other resting (open/partial) sell orders on the same side before allowing a new sell. Prevents overlapping open sell orders from collectively overselling the held position (e.g. two 10-contract sells against a 10-contract holding).
- Remaining follow-up: concurrent fill-time revalidation under a per-position lock (tracked with TD-013 locking work).
- Tier 0 item #2 of 4 from the deep-review synthesis.
- Key files: `app/services/clob/order_matching_service.rb`, `test/services/clob/order_matching_service_test.rb`

---

## 2026-05-29 — TD-018: CLOB settlement pays net positions

- `Settlement::ClobSettlementHandler` Pass 2 now credits each holder's **net** long position on the winning side (filled buys − filled sells, via `Clob::NetPositionService`) instead of every raw filled winning-side order. Fixes double-payout where a player who bought then sold their position was paid at settlement alongside the buyer who absorbed the sell.
- `SETTLEMENT_WIN` ledger entries now carry `market_id` metadata.
- Tier 0 item #1 of 4 from the deep-review synthesis (`docs/reviews/2026-05-29-deep-review/synthesis.md`).
- Key files: `app/services/settlement/clob_settlement_handler.rb`, `test/services/settlement/clob_settlement_handler_test.rb`

---

## 2026-05-29 — docs(backlog): implementation gap review

- Published the backend gap review as an executable next-steps plan: TD-013 wallet locking, TD-014 LMSR positions UI, TD-015 leaderboard ledger types, TD-016 admin API category/tags, TD-017 market cancellation
- Recorded additional follow-up backend findings TD-018 through TD-022 for CLOB settlement/sell-order/cancellation correctness and one RuboCop gate fix
- Updated `.claude/tasks/ATTENTION.md` so future sessions start from the ready autonomous backend tasks and then move to UX/product slices
- Corrected stale TD-008 status: player positions and betslip execution HTML views are done in PR #29
- Added product/UX gap review pointers for planned UX slices and larger features needing specs/plans
- Key files: `.claude/tasks/ATTENTION.md`, `docs/wiki/tech-debt-backlog.md`, `docs/superpowers/plans/2026-05-29-backend-next-steps.md`, `docs/INDEX.md`

---

## 2026-05-29 — DD-006: CLOB sell limit orders and operator buyback (PR #36, `8a67f3c`)

- `direction` column added to `orders` (buy/sell, default 'buy'); DB check constraint; `Order#buy?`/`sell?`/`reserved_minor` helpers
- `Clob::NetPositionService`: net contracts = buy fills − sell fills per user/market/side
- `Clob::OrderMatchingService` extended: sell orders match same-side resting buy orders; `execute_sell_fill!` credits seller at maker price via `CLOB_SELL_CREDIT` ledger entry; `validate_sell_position!` guards overselling
- `Clob::ClobCashoutService`: validates market is open CLOB, contracts > 0, places sell limit order via OrderMatchingService
- `Clob::OperatorBuybackService`: derives mid-price from order book (YES ask = 100 − NO_bid), places admin buy order; graceful nil when book is empty on both sides
- Backoffice: `POST /backoffice/markets/:id/operator_buyback` + form panel on market show (open CLOB only)
- Web: `POST /web/positions/clob_cashout` action; `clob_contract_positions` simplified to two SQL aggregates (net qty + avg buy price)
- Key files: `app/services/clob/`, `app/controllers/web/positions_controller.rb`, `app/controllers/backoffice/markets_controller.rb`
- Tests: 300 runs, 0 failures, 92.2% coverage

---

## 2026-05-29 — DD-002: LMSR positions table, settlement payouts, ledger replay (PR #35, `f0a8b12`)

- Migration `CreateLmsrPositions`: `lmsr_positions` table (user, market, side YES/NO, contracts bigint), unique index per user/market/side
- `LmsrPosition` model: validates side inclusion, contracts non-negative, uniqueness; `for_market` + `holding` scopes
- `Market#has_many :lmsr_positions` added
- `LmsrTradeService` upserts position after each buy trade (Option A — primary path)
- `LmsrSettlementHandler` rewritten: pays 100 minor/winning contract via `find_each` batching; `positions_from_ledger` class method (Option B audit path) aggregates from `AuditEvent` metadata
- `db/schema.rb` removed from tracking; `structure.sql` updated; `db/schema.rb` added to `.gitignore`
- Key files: `app/models/lmsr_position.rb`, `app/services/settlement/lmsr_settlement_handler.rb`, `app/services/lmsr/lmsr_trade_service.rb`
- Tests: 284 runs, 0 failures, 92.18% coverage

---

## 2026-05-29 — DD-004: PostgreSQL test DB + structure.sql + trigger fix (PR #33, `889d951`)

- Switched test environment from SQLite to PostgreSQL (`config/database.yml`, `config/application.rb`)
- `schema_format = :sql` → `db/structure.sql` generated; Rake hook strips `SET transaction_timeout` for pg_dump version compatibility
- CI: added `postgres:17` service + env vars in `.github/workflows/ci.yml`; docker-compose upgraded to `postgres:17`
- Fixed trigger condition: `> 2` → `>= 2` in `AddLegCountTriggerToMarkets` migration (BEFORE INSERT sees pre-insert count)
- Key files: `config/application.rb`, `config/database.yml`, `db/structure.sql`, `lib/tasks/db_structure.rake`, `.github/workflows/ci.yml`

---

## 2026-05-29 — docs(design): UX wireframes v1 (PR #34, `f784b9b`)

- Added `docs/design/` with 5 markdown docs (brief, IA, flows, settlement, public/community markets)
- Added `docs/design/wireframes/v1/` — interactive pan/zoom canvas (Wireframes.html + 6 JSX files)
- Key files: `docs/design/wireframes/v1/Wireframes.html`, `wireframes-web.jsx`, `wireframes-mobile.jsx`, `wireframes-backoffice.jsx`, `wireframes-mechanisms.jsx`, `wireframes-additions.jsx`

---

## 2026-05-28 — TD-007 + TD-011: Backoffice open-market E2E + market edit description field

- **TD-007:** Added `e2e/playwright/tests/backoffice-open-market.spec.js` — moderator creates draft market via UI form, opens it, verifies settle form appears and open form disappears
- **TD-011:** Added `description` to `market_update_params` in `Backoffice::MarketsController`; description textarea added to Edit Details panel in `show.html.erb`; integration test confirms description update via PATCH
- Key files: `e2e/playwright/tests/backoffice-open-market.spec.js`, `app/controllers/backoffice/markets_controller.rb`, `app/views/backoffice/markets/show.html.erb`
- Tests: 271 runs, 0 failures, 90.82% coverage — PR #31 `256932d`

---

## 2026-05-28 — F-016 / TD-003: LMSR subsidy exhaustion guard

- Added `lmsr_realized_loss_minor` (bigint, default 0) to `markets` via migration
- `Lmsr::LmsrTradeService`: market locked before pricing; input validation for side/quantity; outflow guard raises if `lmsr_realized_loss_minor + outflow > liquidity_subsidy_minor`; outflow uses `total_cost.abs` (net payout including fees) not `raw_cost_minor.abs`
- Guard is buy-only invariant-safe: all LMSR buy trades produce non-negative cost, so outflow is always 0 today; guard activates if sell trades are added later
- Key files: `app/services/lmsr/lmsr_trade_service.rb`, `db/migrate/20260528170128_add_lmsr_realized_loss_to_markets.rb`
- Tests: 270 runs, 0 failures, 90.82% coverage — PR #30 `284928b`

---

## 2026-05-28 — F-015 + F-017: Leaderboard P&L rewrite + market pagination

- **F-015:** `LeaderboardController` now aggregates `LedgerEntry` rows (BET_STAKE/WIN_PAYOUT, LMSR_TRADE_STAKE, PARIMUTUEL_STAKE/SETTLEMENT_WIN, ORDER_FILL_STAKE/CREDIT) — all mechanisms included; fixed-odds-only "Bets/Won/Lost" columns removed from view
- **F-017:** `Web::MarketsController#index` (12/page) and `Backoffice::MarketsController#index` (20/page) now paginate with `limit`/`offset`; Previous/Next controls preserve category + search params

---

## 2026-05-28 — F-012 + F-013: Player positions and execution confirmation HTML views

- **F-012:** `GET /web/positions` now renders HTML; view shows fixed-odds/parimutuel bets table + CLOB contract positions table; "Positions" nav link added for authenticated users
- **F-013:** `GET /web/betslips/executions/:id` now renders HTML; view shows confirmation banner + bet summary table + total stake; 404 redirects to markets page
- Key files: `app/controllers/web/positions_controller.rb`, `app/controllers/web/betslip_executions_controller.rb`, `app/views/web/positions/index.html.erb`, `app/views/web/betslip_executions/show.html.erb`
- Tests: 268 runs, 0 failures, 90.91% coverage

---

## 2026-05-28 — F-009: Post-review fixes (PR #28 merged)

- Extended `close_at` guard to all four trade write paths: LMSR, parimutuel, CLOB (previously only fixed-odds `BetPlacementService`)
- `CloseExpiredMarketsJob`: made status transition atomic with `update_all(where: status=open)`; AuditEvent skipped if row already settled
- `Web::MarketsController`: included `closed` in anonymous index query and `#show` visibility guard — closed markets now publicly visible

---

## 2026-05-28 — F-009: Automated Market Close Enforcement

- Migration: DB check constraint `markets_closed_requires_close_at` (status 4 requires non-null close_at)
- Market enum: `closed: 4` added alongside draft/open/settled/cancelled
- `BetPlacementService`: rejects bets when `close_at <= Time.current` (fires while market still `open`, before job runs)
- `CloseExpiredMarketsJob`: queries `Market.open.where("close_at <= ?", now)`, transitions to `closed`, writes one `AuditEvent` per market
- `config/recurring.yml`: job scheduled every 5 minutes via solid-queue built-in scheduler
- `SettlementService` + backoffice controller: accept `open? || closed?` for settlement
- Backoffice market show: "Closed — awaiting settlement" amber banner + settle form for closed markets
- Customer market show: "This market is closed for new bets" amber notice
- Key files: `app/jobs/close_expired_markets_job.rb`, `app/services/bet_placement_service.rb`, `app/services/settlement_service.rb`, `config/recurring.yml`
- Tests: 261 runs, 0 failures, 91.02% line coverage

---

## 2026-05-28 — Wiki consolidation + task cleanup (PR #27)

- Created `docs/wiki/` with 4 product-facing pages: product overview, market mechanisms, architecture, tech-debt-backlog (8 TD items + 5 design decisions with options)
- Deleted 10 completed `.claude/tasks/` folders; updated `ATTENTION.md` to reference wiki backlog
- Fixed stale ADR statuses: ADR-0011, ADR-0012, ADR-0013 all marked Accepted; duplicate `ADR-0013-clob-order-book-migration.md` deleted
- `docs/plans/ITERATION_005_MASTER_TODO_TREE.md` updated: all 4 plans marked DONE
- Added `.gitignore` entry for `e2e/playwright/test-results/` (had been committed accidentally)
- Key files: `docs/wiki/`, `.claude/tasks/ATTENTION.md`, `docs/INDEX.md`, `.gitignore`

---

## 2026-05-28 — E2E production mode + Zeitwerk fix (PR #26, `490f215`)

**PR:** #26 — squash-merged to main as `490f215`

### Problem
Rails eager-loading (`RAILS_ENV=production`) crashed on boot with `NameError: uninitialized constant Domain::Catalogs`. Zeitwerk autoloads `app/domain/` as a root; files must define `Catalogs::X`, not `Domain::Catalogs::X`. Development lazy-loading hid this for the entire project lifetime.

### Changes
- Removed `module Domain` wrapper from all 3 catalog files (`action_catalog.rb`, `permission_catalog.rb`, `market_template_catalog.rb`)
- Updated 7 call sites: `available_actions_service.rb` + 3 seeds sync services dropped `Domain::` prefix and removed `require_dependency` calls
- `docker-compose.e2e.yml` created: Compose overlay running Playwright against `RAILS_ENV=production`
- `scripts/e2e.sh` rewritten: builds stack, waits for healthcheck, runs `docker compose run --rm playwright`, tears down with logs on failure
- `.github/workflows/ci.yml` `e2e` job updated to call `scripts/e2e.sh`
- `e2e/playwright/package-lock.json` committed (required by `npm ci`)
- Stale `e2e/playwright/Dockerfile` and `e2e/playwright/docker-compose.e2e.yml` deleted
- Key files: `app/domain/catalogs/`, `app/services/available_actions_service.rb`, `app/services/seeds/`, `docker-compose.e2e.yml`, `scripts/e2e.sh`

---

## 2026-05-28 — Multi-player settlement E2E (table-driven, all 4 mechanisms)

Added `multi-player-settlement.spec.js` with 16 tests (4 scenarios × 4 mechanisms).

### Design
- **Scenario table** (shared): larger-winner/smaller-winner/loser, single-winner/two-losers, only-winners, only-losers. Outcome always YES so YES-side = winner, NO-side = loser.
- **Setup fully API-driven**: `createTestPlayer` (register API), `fundPlayer` (faucet create + approve), `walletBalance` (JWT `/wallet`). New helpers added to `helpers/api.js`.
- **Assertions**: winners → `balanceUi > balancesAfterBets` (payout received); losers → `balanceUi < balancesBefore` (stake lost). Relative, not exact.
- **UI verification**: each player gets an isolated `browser.newContext()`, signs in, navigates to `/web/profile`, and the `wallet-available` testid is checked for direction.
- **Parimutuel edge cases**: "only winners" / "only losers" inject a fresh market-maker player for the opposite pool (prevents zero-winning-pool refund).
- **CLOB**: NO orders placed first (resting makers), YES second (takers → immediate fill). Admin wallet topped up per test via `fundAdmin`. Liquidity balanced with admin orders.
- **LMSR v1**: no individual payouts; asserts settled-outcome visibility on market page instead of balance direction.
- **`webPost` context**: response fields (ok/status/text) buffered inside a try/finally; context disposed in finally before returning a plain object. This avoids resource leaks while still allowing callers to read failure bodies.
- 16/16 pass (51 s on Chromium).
- Key files: `e2e/playwright/tests/multi-player-settlement.spec.js`, `e2e/playwright/tests/helpers/api.js`

---

## 2026-05-28 — Settlement E2E for CLOB/LMSR/parimutuel

- Extended `settlement-scenarios.spec.js` with 6 new tests (2 per mechanism: settle YES + settle NO)
- CLOB: places a GTC limit order via admin API (`/admin/markets/:id/orders` with `user_id`), then settles and verifies UI
- LMSR/Parimutuel: signs in as player via UI, submits quick-bet form, then settles via admin API and verifies `market-trust-panel`
- 10/10 tests pass on Chromium; existing fixed-odds suite untouched
- Key files: `e2e/playwright/tests/settlement-scenarios.spec.js`

---

## 2026-05-28 — CLOB/LMSR/parimutuel quick-bet E2E + side param fix (PR #23 merged)

**PR:** #23 (`feat/e2e-mechanism-quickbet`) — squash-merged to main as `6a61122`

### E2E: mechanism quick-bet forms
- Added E2E tests for CLOB (limit order), LMSR (share buy), parimutuel (pool stake) via the market show quick-bet panel
- Fixed `side` param upcase bug: LMSR and parimutuel controllers now upcase `params[:side]` before passing to services (services require uppercase YES/NO)
- Key files: `app/controllers/web/lmsr_trades_controller.rb`, `app/controllers/web/parimutuel_bets_controller.rb`, `e2e/playwright/tests/quick-bet.spec.js`

---

## 2026-05-28 — F-006 backoffice market create form UX (PR #21 merged)

**PR:** #21 (`feat/f006-market-create-ux`) — squash-merged to main as `528e7ba`

### F-006: Backoffice market creation UX
- Grouped 14-field form into 3 fieldsets: Basic Information, Metadata & Resolution, Trading Mechanism
- Added live question preview box (JS `input` event listener)
- Improved help text on mechanism-specific fields (liability cap, taker fee, subsidy, takeout)
- Required field indicators on question, description, mechanism
- Added `backoffice-faucet.spec.js` E2E tests (PR #19 `d9aa8b8`)
- Fixed duplicate flash rendering in backoffice faucet view (PR #19)
- Plan: `docs/superpowers/plans/2026-05-28-f006-backoffice-market-create-ux.md`

---

## 2026-05-28 — UX polish, rich seeds, F-003, F-007, quick-bet, leaderboard ORDER BY fix (PR #18 merged)

**PR:** #18 (`feat/ux-improvements`) — squash-merged to main as `3dd6be1`
**Fixes in this session:** leaderboard ORDER BY PostgreSQL alias bug (`1899cc4`), profile E2E faucet selector (`102624e`)

### F-001: Market taxonomy (PRs #13–15)
- Migration: `category` string enum + `tags` jsonb on `markets`
- `Market::CATEGORIES` constant, validation, custom `tags=` setter
- Backoffice: category select + tags input on create form
- Customer UI: category filter bar (pill tabs), category badge on cards and show page, tags badge row
- Full-text search picks up tag content via `CAST(tags AS TEXT) ILIKE ?`
- Commits on main: `286cf78`, `9eaebf1`, `8496a72`

### F-002: Full-text market search (PR #16)
- `Web::MarketsController#index`: Arel-based ILIKE across `question`, `description`, tags cast
- Search form in index header; clear-search link preserves active category filter
- Integration test: `search_q_matches_market_tags`
- Commit: `c400e5f`, `6326f32` (tags fix)

### F-005: User profile page (PR #17)
- `Web::ProfileController#show`: wallet stat-grid, P&L summary, bet history with status-tab filter
- `Web::FaucetRequestsController#create`: submit faucet request from profile
- `navigation.profile` action catalog entry for signed-in users
- Nav header: "My Profile" link + ADIV balance chip
- Commits on main: `07d79ce`, `3181b44`

### F-003: Market detail enrichment (PR #18)
- Migration: `close_at` (datetime), `resolution_criteria` (text), `resolution_source` (string)
- Backoffice create form: datetime picker, resolution criteria textarea, source field
- Backoffice show page: close countdown, resolution criteria, source display
- Customer market show: Resolution Details panel (conditional), countdown text, criteria & source
- Admin API: `close_at`/`resolution_criteria`/`resolution_source` added to permitted params

### UX improvements (PR #18)
- Full CSS design system overhaul in `application.html.erb`: `.pill`, `.pill-active`, `.pill-outline`, `.stat-card`, `.stat-grid`, `.balance-chip`, `.header-nav` components
- Market show: mechanism-appropriate price panels (fixed-odds, CLOB, LMSR, parimutuel), stat grid
- Seeds: 17 markets across 5 categories, 5 users, 8 demo bets; idempotent via `find_or_initialize_by`

### F-007: Public leaderboard page (PR #18)
- `GET /web/leaderboard` — ranked list of players by net P&L from settled bets
- `Web::LeaderboardController` — SQL aggregation via Arel, grouped by user, top 50
- Nav link (always visible, public); medal icons for top 3
- Unit tests: `test/integration/web_leaderboard_test.rb` (5 tests)
- E2E tests: `e2e/playwright/tests/leaderboard.spec.js`

### Betting forms on customer market pages (PR #18)
- Quick-bet panel on market show page for signed-in players:
  - **Fixed-odds**: leg radio + stake form → `POST /web/markets/:id/bets` (new `Web::BetsController`)
  - **CLOB**: price + quantity limit order form → `POST /web/markets/:id/orders`
  - **LMSR**: side + shares form → `POST /web/markets/:id/lmsr_trades`
  - **Parimutuel**: side + stake form → `POST /web/markets/:id/parimutuel_bets`
- Unauthenticated users see a "Sign in to participate" prompt
- `LmsrTradesController` and `ParimutuelBetsController` updated to `respond_to` HTML+JSON
- `OrdersController` updated to `respond_to` HTML+JSON with side `.upcase` normalization
- Unit tests: `test/integration/web_bets_test.rb` (4 tests)
- E2E tests: `e2e/playwright/tests/quick-bet.spec.js`

### Admin API extension (PR #18)
- `admin/markets_controller.rb` `market_params` now permits `close_at`, `resolution_criteria`, `resolution_source`

### Tests added (PR #18)
- `test/integration/web_faucet_requests_test.rb` — 5 integration tests (auth gate, create, defaults)
- `test/integration/web_leaderboard_test.rb` — 5 integration tests
- `test/integration/web_bets_test.rb` — 4 integration tests
- `e2e/playwright/tests/profile.spec.js` — profile page, nav balance chip, faucet form, F-003 resolution panel, market stats
- `e2e/playwright/tests/leaderboard.spec.js` — public access, settled player, nav link
- `e2e/playwright/tests/quick-bet.spec.js` — quick-bet panel visibility, form submission, auth prompt

### Key files
- `app/views/layouts/application.html.erb` — CSS system + nav
- `app/views/web/markets/index.html.erb` — filter bar, search form, market cards
- `app/views/web/markets/show.html.erb` — price panels, stats, resolution panel
- `app/views/web/profile/show.html.erb` — wallet, P&L, bet history
- `app/controllers/web/faucet_requests_controller.rb` (new)
- `app/controllers/web/profile_controller.rb`
- `app/domain/catalogs/action_catalog.rb` — `navigation.profile` entry
- `db/migrate/20260527221019_add_market_detail_fields.rb`
- `db/seeds.rb` — full rewrite with 17 markets + demo bets

---

## 2026-05-27 — CLOB Order Book Completion

**PRs:** #10 (fill ledger entries + settlement lock), #11 (last_fill_price + spread + ADR-0014), #12 (CLOB positions endpoint)
**Commits on main:** `3989e82`, `1d53312`, `5d48ac1`

### Changes
- `OrderMatchingService`: writes `ORDER_FILL_STAKE` (taker debit) and `ORDER_FILL_CREDIT` (maker credit) per fill; sets `market.last_fill_price_cents` after each fill
- `ClobSettlementHandler`: `wallet.lock!` on settlement payout pass for concurrency safety
- `ClobPricingEngine#order_book_summary`: fixed NO sort to `:asc` (lowest = best ask)
- `OrderBooksController`: returns `last_trade_price` and `spread` (`(100 - best_ask) - best_bid`; negative = crossing available)
- `PositionsController`: `GET /web/positions` returns `clob_positions[]` with `yes_contracts`, `no_contracts`, `avg_yes_price_cents`, `unrealised_value_minor`; preloads markets to avoid N+1
- Migration: `markets.last_fill_price_cents` (nullable int)
- ADR-0014 (CLOB order book migration) accepted and committed

### Key files
- `app/services/clob/order_matching_service.rb`
- `app/services/settlement/clob_settlement_handler.rb`
- `app/models/market.rb` — `ClobPricingEngine#order_book_summary`
- `app/controllers/web/order_books_controller.rb`
- `app/controllers/web/positions_controller.rb`
- `db/migrate/20260527100006_add_last_fill_price_cents_to_markets.rb`
- 220 tests, 0 failures, 91.46% line coverage

---

## 2026-05-27 — Pluggable Market Mechanisms (CLOB, LMSR, Parimutuel, Fixed-odds)

**PRs:** #5 (db+market), #9 (clob), #7 (lmsr+parimutuel), #10 (settlement+ui+docs)
**Commits on main:** `74857ed`, `ba7d2dc`, `ca3f626`, `4a7555d`

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
