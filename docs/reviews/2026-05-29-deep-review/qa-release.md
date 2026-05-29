# QA / E2E / Release Deep Review

## Scope

### Files and docs inspected

- `CLAUDE.md` — project coding rules and SDL lifecycle
- `docs/INDEX.md` — project map, implementation status, fixture cheat-sheet
- `docs/wiki/tech-debt-backlog.md` — all TD-001 through TD-027 entries
- `docs/reviews/2026-05-29-deep-review/market-mechanics.md` — prior financial-invariant review (cross-referenced, not duplicated)
- `.github/workflows/ci.yml` — CI pipeline definition
- `scripts/validate.sh` and `scripts/e2e.sh` — CI gate scripts
- `e2e/playwright/playwright.config.js` — browser matrix and retry config
- `e2e/playwright/TEST_MATRIX.md` — porting guide and scenario inventory
- `e2e/playwright/tests/global-setup.js` — app-readiness wait logic
- All 11 E2E spec files under `e2e/playwright/tests/`
- `test/test_helper.rb` — SimpleCov config and coverage threshold
- All files under `test/services/`, `test/integration/`, `test/models/`, `test/jobs/`
- Selected service implementations: `app/services/settlement_service.rb`, `app/services/settlement/clob_settlement_handler.rb`, `app/services/clob/order_matching_service.rb`, `app/services/clob/operator_buyback_service.rb`, `app/services/bet_placement_service.rb`, `app/services/betslip_execution_service.rb`, `app/services/cashout_execution_service.rb`, `app/services/cashout_quote_service.rb`, `app/services/lmsr/lmsr_trade_service.rb`, `app/services/parimutuel/parimutuel_settlement_service.rb`
- `app/controllers/web/positions_controller.rb` (clob_cashout action)
- `config/routes.rb` (cashout and clob_cashout routes)

### Explicitly out of scope

- Execution of any tests or test suite (DB is not running)
- Duplication of financial-invariant findings already documented in `market-mechanics.md` (TD-018, TD-019, TD-023–TD-027)
- Visual or UX review
- Infrastructure/deployment concerns (covered in devops review)

---

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|
| P0 | `POST /web/positions/clob_cashout` endpoint has zero Minitest coverage and zero E2E coverage. This is the primary user-facing path for CLOB position exit and exercises `ClobCashoutService` with market auth, params validation, and redirect logic that is untested in any automated gate. | Route exists: `config/routes.rb:36`. Controller action: `app/controllers/web/positions_controller.rb:41-57`. Service tests exist (`test/services/clob/clob_cashout_service_test.rb`) but test only the service in isolation with no market-side auth or params parsing. `grep -rn "clob_cashout" test/` returns zero results. No E2E spec exercises this flow. | Add `WebPositionsTest` cases for happy-path clob_cashout (sell limit order placed, order visible), invalid market, and unauthenticated access. Add one E2E smoke test in `quick-bet.spec.js` or a dedicated `clob-cashout.spec.js`. |
| P0 | `BetPlacementService` reads `user.wallet` without `lock!` before the balance check, allowing two concurrent bets to both pass the balance check and produce a negative wallet balance. The same race exists in `BetVoidService`, `CashoutExecutionService`, and `SettlementService#settle_fixed_odds!`. No test exercises concurrent placement, so the coverage threshold counts these as covered despite the race path being untested. | `app/services/bet_placement_service.rb:18` (`user.wallet` without lock). Backlog entry TD-013 at `docs/wiki/tech-debt-backlog.md:113-118`. `LmsrTradeService` and `ParimutuelPoolService` already use `wallet.lock!` correctly as the pattern reference. | Implement TD-013 first (add `lock!` in all four services). Then add a DB-level concurrency integration test using threads or `ActiveRecord::Base.connection_pool` to verify wallet cannot go below zero on concurrent requests. |
| P0 | CLOB settlement (TD-018) and open sell orders without contract reservation (TD-019) are not guarded by any regression tests. Both are P0 financial bugs documented in the market-mechanics review. Since no test covers the sell-then-settle path, a green test suite does not provide any signal that these bugs are absent and will not catch regressions when they are fixed. | `test/services/settlement_service_test.rb:125-135` only asserts CLOB market settles without error on an empty order book — it does not create any filled orders or assert payout amounts. `test/services/clob/order_matching_service_test.rb:125-162` tests sell fills but does not follow with settlement and a balance assertion. TD-018 at `docs/wiki/tech-debt-backlog.md:158-163`, TD-019 at `docs/wiki/tech-debt-backlog.md:167-172`. | Write the regression tests described in TD-018 and TD-019 before or in the same PR as the fixes: "buy 10 YES, sell 10 YES, settle YES, seller receives zero SETTLEMENT_WIN, buyer receives 1000" and "user with 10 YES cannot place two open sell orders each for 10." |
| P1 | The `BetTest` model test (`test/models/bet_test.rb`) is an empty stub containing only a commented-out scaffold assertion. The `Bet` model is the central financial record (status transitions drive settlement and cashout) and has no model-level test coverage for status state-machine edges, validation, or forbidden transitions (e.g., `settled_win → voided`). | `test/models/bet_test.rb` lines 1-5: empty class with commented body. `Bet` is exercised indirectly via service and integration tests, but model-level invariants (direct `update!` to invalid status, validation of `stake_minor > 0` at DB level, etc.) are not asserted. | Replace the stub with tests for: invalid status transition (settled_win → open), stake_minor must be positive, bet belongs to the correct market/leg, and any DB constraints. |
| P1 | Operator buyback (`POST /backoffice/markets/:id/operator_buyback`) has no E2E coverage for the success path. The backoffice integration test covers only the two failure paths (non-CLOB market, empty order book). A successful buyback — operator posts a buy order at mid-price, the order appears in the book — is never verified end-to-end. | `test/integration/backoffice_management_test.rb:236-255`: two tests, both verify failure redirects. No E2E spec exercises `operator_buyback`. Service unit tests (`test/services/clob/operator_buyback_service_test.rb:18-41`) cover the service in isolation. | Add a `backoffice_management_test.rb` case that seeds a live bid and ask on a CLOB market, then calls operator_buyback and asserts the new order exists and the flash shows success. |
| P1 | The E2E browser matrix runs Chromium only in CI. Firefox and WebKit are excluded in Docker mode (`playwright.config.js:38-46`). TD-006 defers this decision explicitly but classifies it as a coverage gap. For a POC targeting a demo, Chromium-only is acceptable, but the gap means Safari/Firefox rendering bugs and CSS layout regressions would not be caught before a stakeholder demo. | `e2e/playwright/playwright.config.js:38-46`: `projects` array adds Firefox and WebKit only when `!isDocker`. `ci.yml` uses `scripts/e2e.sh` which sets `DOCKER=1`. `docs/wiki/tech-debt-backlog.md:63-69`: TD-006, status "Deferred." | Implement TD-006 Option B (Firefox/WebKit on a nightly schedule, Chromium on every PR). A GitHub Actions schedule trigger adds negligible maintenance overhead and provides cross-browser confidence before stakeholder demos. |
| P1 | SimpleCov filters out `app/jobs/` from coverage tracking (`test/test_helper.rb:8`), meaning `CloseExpiredMarketsJob` and `RecordPriceSnapshotJob` do not contribute to the 90% threshold. `CloseExpiredMarketsJob` has solid unit tests (`test/jobs/close_expired_markets_job_test.rb`), but `RecordPriceSnapshotJob` has no test file at all. If jobs were tracked, the threshold could be gamed by a failing job; if untracked, job regressions are invisible to coverage reports. | `test/test_helper.rb:8`: `add_filter '/app/jobs/'`. `app/jobs/record_price_snapshot_job.rb` exists with logic that short-circuits on non-open markets — a meaningful path. No file at `test/jobs/record_price_snapshot_job_test.rb`. | Add a minimal `RecordPriceSnapshotJobTest` (calls on open market, calls on non-open market, no error on missing market). Consider including jobs in SimpleCov `track_files` or at least verify `minimum_coverage` is not trivially satisfied by excluding significant code. |
| P2 | The parimutuel settlement test (`test/services/parimutuel/parimutuel_settlement_service_test.rb`) contains only two tests: a hand-rolled arithmetic formula check (not calling the service) and a zero-winning-pool refund check. The full settlement path — computing takeout, iterating `PARIMUTUEL_STAKE` ledger entries, crediting wallets — has no unit test asserting wallet delta, ledger entry count, or takeout correctness via actual service call. | `test/services/parimutuel/parimutuel_settlement_service_test.rb:18-39`. Line 18-26 is a pure arithmetic assertion that never calls `ParimutuelSettlementService.call`. Only line 29-39 calls the service, and only for the refund path. The main settlement path is exercised only via E2E multi-player tests. | Add unit tests for the full settlement path: multiple stakers on winning and losing sides, assert each winner receives floor-rounded share, assert total SETTLEMENT_WIN credits + takeout (when ledgered, per TD-025) + dust equals total pool. |
| P2 | E2E tests create markets via `createMarketViaAdminApi` which always defaults to `mechanism_type: 'fixed_odds'` when not overridden, and all E2E markets are created with `category` field absent (defaulting to `'other'`). TD-016 documents that the admin API's `market_params` does not permit `:category`, so the E2E category filter bar is exercised only with `other`-category markets and never verifies that search, filtering, or pagination operates correctly across distinct categories. | `e2e/playwright/tests/helpers/api.js`: `createMarketViaAdminApi` posts to `/admin/markets` without `category`. `docs/wiki/tech-debt-backlog.md:140-146`: TD-016. `e2e/playwright/tests/workflow.spec.js` and `quick-bet.spec.js` do not set category or assert filter behavior. | Fix TD-016 first (add `:category` to admin API params). Then add E2E assertions that category pill filters show only matching markets and that the market browse page correctly scopes results. |
| P2 | LMSR position settlement payout is only asserted in unit tests (`test/services/settlement/lmsr_settlement_handler_test.rb`) and the LMSR E2E multi-player suite only checks that the settled outcome text is visible — it explicitly comments "LMSR v1: individual payouts deferred." Since `LmsrSettlementHandler` now does pay out (per PR #35, DD-002 marked done), the E2E comment and scope are stale and the actual wallet balance after LMSR settlement is never verified end-to-end. | `e2e/playwright/tests/multi-player-settlement.spec.js:381-413`: LMSR section calls `assertSettledOutcomeInUi` not `assertBalancesInUi`. Comment on line 7-8: "LMSR v1: individual payouts deferred." `docs/INDEX.md:144`: "DD-002: LMSR positions — settlement pays 100 minor/contract to winners" — marked done. | Update the LMSR multi-player settlement tests to call `assertBalancesInUi` (same as fixed-odds, parimutuel, CLOB) and remove the stale deferral comment. This also validates the full `LmsrSettlementHandler` path in production-mode E2E. |
| P3 | E2E tests run `fullyParallel: false` globally and share the same seed database with mutable wallet state for the fixed `player@adivento.local` seed user. Tests that place bets as the seed player in `settlement-scenarios.spec.js` use a shared token context and could interfere if ordering changed or retries occurred. `quick-bet.spec.js` tests place bets that deduct from the player wallet and the fixed wallet starts at 10,000 minor (100 ADIV), which is enough for the current test count but has no guard. | `playwright.config.js:15`: `fullyParallel: false`. `e2e/playwright/tests/settlement-scenarios.spec.js:56-63`: uses seed player. `e2e/playwright/TEST_MATRIX.md:233-236`: player starts with 10,000 minor. Multi-player settlement tests call `createTestPlayer` to isolate, but single-player tests reuse the seed player across 4 scenario iterations. | Consider calling `fundPlayer` in `settlement-scenarios.spec.js` for the seed player at the start of each test to ensure a consistent starting balance, or convert fixed-seed-player tests to use freshly registered players. |

---

## Detailed Notes

### Coverage threshold: 91.46% is real, but jobs and selected paths are excluded

The test suite reached 91.46% line coverage on the pluggable-mechanisms PR (`docs/INDEX.md:116`). The 90% minimum is enforced via `SimpleCov.minimum_coverage 90` (`test/test_helper.rb:4`). Coverage tracks `app/{controllers,models,services}/**/*.rb` but explicitly excludes `app/channels/`, `app/jobs/`, and `app/mailers/` (`test/test_helper.rb:6-9`). In practice:

- `RecordPriceSnapshotJob` has no test and is invisible to the threshold.
- `CloseExpiredMarketsJob` has good coverage via `test/jobs/close_expired_markets_job_test.rb` but its lines are excluded from the denominator, so tests do not inflate the reported percentage.
- The CLOB `clob_cashout` controller action (`app/controllers/web/positions_controller.rb:41-57`) is a tracked file but has no corresponding test, meaning its 17 lines are counted as uncovered in the 91.46% figure. This likely means coverage on the controller layer is lower than the aggregate suggests.

Branch coverage is enabled (`enable_coverage :branch`) but the minimum applies only to line coverage. There is no branch-coverage minimum, so partially covered branches in complex conditionals (e.g., the settlement router's `case market.mechanism_type`) may pass the line gate even if not all branches are exercised.

### CI pipeline structure and gaps

The CI pipeline (`.github/workflows/ci.yml`) runs two jobs:

1. **test** — `scripts/validate.sh`: RuboCop (skipped if no `.rubocop.yml`), DB schema load, `bin/rails test`. SimpleCov report is uploaded as an artifact.
2. **e2e** — depends on `test`, runs `scripts/e2e.sh`: Docker Compose with production-mode Rails, Playwright against Chromium only.

No `.rubocop.yml` file was observed in the tree root, so the RuboCop check in `validate.sh` is always skipped (only the TD-022 offense is mentioned in the backlog, not a gate failure). The RuboCop gate is a dead code path in CI.

The CI pipeline has no:
- Separate security scanner (Brakeman, bundle-audit)
- Database migration safety check (strong_migrations or similar)
- Performance/load gate
- Coverage comment on PRs (artifact is uploaded but not surfaced as a PR check)

E2E retries are set to 1 in CI (`playwright.config.js:16`), which is appropriate for flakiness tolerance. Traces and screenshots are always captured, which is good for diagnostics.

### Test file-to-service coverage mapping

| Service / Controller | Unit test | Integration test | E2E coverage |
|---|---|---|---|
| `BetPlacementService` | Partial (3 tests: close_at guard, risk cap; missing wallet lock, concurrency) | `bets_test.rb`, `admin_market_settle_test.rb` | `settlement-scenarios.spec.js`, `multi-player-settlement.spec.js` |
| `BetVoidService` | None found | `admin_bet_void_test.rb` | `error-paths.spec.js` (void then cashout) |
| `BetslipQuoteService` | `betslip_quote_service_test.rb` | `web_betslip_test.rb` | `workflow.spec.js` (4.7) |
| `BetslipExecutionService` | `betslip_execution_service_test.rb` (good: all-or-nothing tested) | `web_betslip_test.rb` | `workflow.spec.js` (4.7) |
| `CashoutQuoteService` | `cashout_quote_service_test.rb` (good) | `web_betslip_test.rb` | `error-paths.spec.js` (17-18) |
| `CashoutExecutionService` | `cashout_execution_service_test.rb` (good; fee-accounting gap documented in market-mechanics) | `web_betslip_test.rb` | `workflow.spec.js` (4.8) |
| `SettlementService` (fixed-odds) | `settlement_service_test.rb` (comprehensive) | `admin_market_settle_test.rb` | `settlement-scenarios.spec.js`, `multi-player-settlement.spec.js` |
| `Settlement::ClobSettlementHandler` | `settlement_service_test.rb:125-135` (empty order book only) | None | `settlement-scenarios.spec.js` (UI text only) |
| `Settlement::LmsrSettlementHandler` | `lmsr_settlement_handler_test.rb` (good) | None | `multi-player-settlement.spec.js` (outcome text only, balance deferred) |
| `Parimutuel::ParimutuelSettlementService` | `parimutuel_settlement_service_test.rb` (2 tests, main path untested via service) | None | `multi-player-settlement.spec.js` (balance verified) |
| `Clob::OrderMatchingService` | `order_matching_service_test.rb` (comprehensive) | `web_orders_test.rb` | `multi-player-settlement.spec.js` |
| `Clob::ClobCashoutService` | `clob_cashout_service_test.rb` (service isolation) | None | None |
| `Clob::OperatorBuybackService` | `operator_buyback_service_test.rb` (good) | `backoffice_management_test.rb` (failure paths only) | None |
| `Clob::NetPositionService` | `net_position_service_test.rb` (comprehensive) | None (indirect) | None |
| `Lmsr::LmsrTradeService` | `lmsr_trade_service_test.rb` (good) | `lmsr_trades_test.rb` | `quick-bet.spec.js`, `multi-player-settlement.spec.js` |
| `Parimutuel::ParimutuelPoolService` | `parimutuel_pool_service_test.rb` (good) | `parimutuel_bets_test.rb` | `quick-bet.spec.js`, `multi-player-settlement.spec.js` |
| `Web::PositionsController#clob_cashout` | None | None | None |
| `HouseRiskService` | `house_risk_service_test.rb` | `admin_market_risk_test.rb` | None |
| `AuthorizationService` | `authorization_service_test.rb` (3 tests) | Multiple integration tests | `permissions.spec.js` |
| `CloseExpiredMarketsJob` | `close_expired_markets_job_test.rb` (good) | None | None |
| `RecordPriceSnapshotJob` | None | None | None |

### Fixture-pollution risk pattern

The `docs/INDEX.md:248` fixture gotcha note states that fixture bets on `open_market` interfere with settlement tests, and the solution is `@market.bets.delete_all` in `setup`. This pattern is used correctly in `settlement_service_test.rb`, `admin_market_settle_test.rb`, and `bet_placement_service_test.rb`. However, the `bets.yml` fixture file may hold bets that affect wallet balance assertions if `delete_all` is omitted in new tests. This is a latent contamination risk for future test authors.

### Missing negative/adversarial tests

The following adversarial paths are exercised in neither Minitest nor E2E:

1. Player attempts to cashout another player's bet (cross-user ownership check — `cashout_execute` only does `Bet.where(user_id: current_user.id)` but the service itself does not check ownership; a crafted request with another user's `bet_id` in the form body may fail only at the `where` scope, but this is not explicitly tested).
2. Player places a CLOB sell order with more contracts than they own when another sell order is already open (TD-019 — duplicate sell listing exceeds holdings).
3. Admin API order placement on a non-open CLOB market (TD-020 — draft/closed/settled market guard absent in admin path).
4. Concurrent order cancellation by web and admin simultaneously releasing the same reservation (TD-021).
5. CLOB settlement after one player buys, then sells all contracts (TD-018 regression).

### E2E global-setup robustness

`tests/global-setup.js` polls `/up` with up to 30 retries × 2-second intervals (60 seconds maximum). This is reasonable for the Docker Compose boot. However, `/up` responds as soon as the Puma process is up; it does not verify DB connectivity or migrations. A race between app readiness and DB schema completeness could produce misleading test failures in CI that self-resolve on retry.

### Settlement E2E: UI-only assertions are not financial proofs

Settlement E2E tests in `settlement-scenarios.spec.js` verify only that `market-trust-panel` contains `"Settled outcome: YES"` (or NO). They do not check wallet balances. The `multi-player-settlement.spec.js` suite does check balances for fixed-odds, parimutuel, and CLOB, but LMSR checks only UI text. A bug that marks the market settled but skips payout credits would pass these UI-text-only assertions.

---

## Open Questions

1. Should branch coverage have a minimum gate? Line coverage at 90% can be satisfied while leaving entire conditional branches uncovered. The CLOB settlement `case` statement is one example where line coverage shows green but branch behavior (sell order direction filter) is untested.

2. Is the intent that `RecordPriceSnapshotJob` be excluded from coverage? If it grows in complexity (e.g., LMSR/parimutuel price calculations), an explicit test file should be added and the filter reconsidered.

3. Should the E2E suite be extended with API-level balance conservation tests (not just UI text) for LMSR multi-player settlement, given that `LmsrSettlementHandler` now pays out? The current comment implies deferral but the feature is implemented.

4. For the `clob_cashout` controller action: should it redirect or return JSON? The current implementation always redirects (`redirect_to web_positions_path`), but `web_orders_test.rb` and `web_positions_test.rb` use `as: :json`. A test would immediately surface whether the action supports `respond_to` or only HTML.

5. Is the 1-retry policy for E2E tests in CI sufficient? `fullyParallel: false` + 1 retry should handle transient flakiness, but the seed-player wallet state across tests is a structural flakiness source that retries will not cure.

---

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|---|---|---|---|---|
| QA-001 | Add `WebPositionsTest` integration tests for `POST /web/positions/clob_cashout` (happy path, invalid market, unauthenticated). | S | None | `grep -rn "clob_cashout" test/` returns at least 3 tests; all pass with PostgreSQL DB. |
| QA-002 | Add CLOB cashout E2E smoke test: player buys CLOB YES via quick-bet, then sells via positions page clob_cashout form, order appears in book. | S | QA-001 (service already tested) | Playwright test passes in Docker Chromium mode; sell order visible in order book. |
| QA-003 | Add TD-018 regression test: player buys 10 YES, sells 10 YES, market settles YES, seller receives no SETTLEMENT_WIN credit, buyer receives 1000 minor. | S | TD-018 fix | Test fails before fix, passes after fix. |
| QA-004 | Add TD-019 duplicate-sell test: player with 10 YES cannot place two open sell orders for 10 each; second is rejected. | S | TD-019 fix | Test fails before fix, passes after fix. |
| QA-005 | Add `BetTest` model tests for status transitions, validation, and ownership constraints. | S | None | `test/models/bet_test.rb` has at least 5 assertions covering invalid transitions and required fields. |
| QA-006 | Expand `ParimutuelSettlementServiceTest` to call the service for the full settlement path with multiple stakers, assert wallet deltas and ledger entry counts. | S | None (can run with existing DB) | Test asserts total SETTLEMENT_WIN credits ≤ after_takeout pool; diff ≤ (number_of_winners) due to floor rounding. |
| QA-007 | Add `RecordPriceSnapshotJobTest`: open market records snapshot, non-open market skips, missing market does not raise. | S | None | `test/jobs/record_price_snapshot_job_test.rb` created with 3 passing tests. |
| QA-008 | Update LMSR E2E multi-player settlement to assert wallet balances (same as fixed-odds/parimutuel/CLOB blocks), removing the stale deferral comment. | S | None (LmsrSettlementHandler pays out since PR #35) | All 4 LMSR scenario tests call `assertBalancesInUi`; CI passes. |
| QA-009 | Add operator buyback success integration test: seed bid+ask orders, call operator_buyback, assert new order created and flash shows success. | S | None | `backoffice_management_test.rb` has a passing success-path test for `POST /backoffice/markets/:id/operator_buyback`. |
| QA-010 | Implement TD-006 Option B: add Firefox/WebKit to a nightly GitHub Actions schedule, keep Chromium on every PR. | M | None | `.github/workflows/` has a `schedule` trigger job running Firefox+WebKit against the Docker stack; Chrome job unchanged on push/PR. |
| QA-011 | Add wallet conservation integration test per mechanism: for each service (BetPlacement, BetVoid, CashoutExecution, CLOB fill, LMSR trade, Parimutuel stake+settle), assert `wallet_delta == ledger_net_delta` for cash-type entries. | L | TD-023 (ledger taxonomy decision) | Per-mechanism tests assert wallet before-after delta equals sum of credit cash ledger entries minus sum of debit cash ledger entries for the transaction. |
| QA-012 | Add concurrency regression test for wallet balance (TD-013): two threads concurrently call `BetPlacementService.place!` with a wallet balance only sufficient for one bet; assert exactly one succeeds and wallet is non-negative. | M | TD-013 fix (add `lock!`) | Test passes deterministically with `lock!` in place; fails (intermittently or consistently) without it. |
