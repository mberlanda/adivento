# Tech Debt & Backlog

This file tracks known gaps, deferred implementation decisions, and open design questions. It is the single source of truth for "things we know we need but haven't built yet."

Update this file when a gap is closed or a decision is made.

---

## Upcoming features (prioritised)

| ID | Feature | Status | Depends on |
|----|---------|--------|-----------|
| F-009 | Automated market close (`CloseExpiredMarketsJob` + `closed` status) | ✅ done (PR #28) | — |
| F-010 | Market close UX (player-facing "Betting closed" state on market page) | ✅ done (shipped in F-009/PR #28) | F-009 |
| F-011 | LMSR individual settlement payouts | ⏳ backlog | DD-002 decision |
| F-012 | Player positions HTML view (currently JSON-only) | ✅ done (PR #29) | — |
| F-013 | Betslip execution confirmation HTML view (currently JSON-only) | ✅ done (PR #29) | — |
| F-014 | Market edit form in backoffice | ✅ done (PR #31) | — |
| F-015 | Cross-mechanism leaderboard P&L aggregation | ✅ done (PR #29) | — |
| F-016 | LMSR subsidy exhaustion guard | ✅ done (PR #30) | — |
| F-017 | Market list pagination (web + backoffice) | ✅ done (PR #29) | — |
| F-018 | Switch test DB to PostgreSQL | ⏳ backlog | DD-004 decision |

---

## Active tech debt (implementation gaps)

### TD-001 · LMSR individual settlement payouts

**Status:** Deferred from v1.
**Problem:** When an LMSR market settles, the handler marks the market closed but does not credit individual position holders. Players who held YES/NO positions at settlement do not receive payouts.
**Root cause:** No per-player position tracking for LMSR. LedgerEntry records the trade cost but not the resulting contract inventory.
**Required:** A `lmsr_realized_loss_minor` column (or equivalent position model) to track each player's LMSR contract holdings so the settlement handler can iterate and credit.
**Impact:** LMSR settlement currently unusable for real payouts. E2E tests assert only the "Settled outcome:" UI label.

---

### TD-002 · Parimutuel per-bettor history model

**Status:** Deferred from v1.
**Problem:** Parimutuel stakes are recorded in `LedgerEntry` (entry_type `PARIMUTUEL_STAKE`, metadata contains market_id and side) but there is no dedicated `ParimutuelBet` model. Querying bet history or reconstructing pool positions requires scanning ledger entries.
**Impact:** Low for now (settlement works via pool totals, not per-bettor records). Becomes a problem if you need to show individual bet history, void individual parimutuel bets, or support partial pools.

---

### TD-003 · LMSR subsidy exhaustion guard

**Status:** Deferred from v1.
**Problem:** `Lmsr::LmsrTradeService` does not check whether the cumulative realized loss on the market has exceeded `liquidity_subsidy_minor`. An operator can lose more than they committed.
**Required:** Add `lmsr_realized_loss_minor` column to `markets`. Reject trades that would push realized loss past the subsidy.

---

### TD-004 · CLOB cashout (sell contracts before settlement)

**Status:** Not yet designed.
**Problem:** Players with open CLOB positions (contract holdings) cannot exit before settlement. `CashoutQuoteService` handles fixed-odds voids but has no CLOB path.
**Options:**
- A: Post a sell limit order on the CLOB book (pure market mechanics, but requires buyer).
- B: Operator buyback at current mid-price (guaranteed exit, operator takes mark-to-market risk).
- C: No cashout for CLOB (positions held to settlement — simplest, least player-friendly).

**Trade-offs:**
- A preserves market integrity but leaves player stranded if no buyer.
- B adds operator risk but gives players a predictable exit.
- C is the current state; acceptable if CLOB markets are short-lived.

---

### TD-005 · Cross-mechanism leaderboard P&L

**Status:** Deferred.
**Problem:** The leaderboard (`GET /web/leaderboard`) calculates P&L from settled `bets` only. CLOB fill credits (`ORDER_FILL_CREDIT` ledger entries) and LMSR/parimutuel payouts are not aggregated. Rankings are incomplete for players using non-fixed-odds mechanisms.
**Required:** Aggregate all payout ledger entries (not just settled bets) for accurate P&L.

---

### TD-006 · Browser matrix in E2E (Firefox / WebKit)

**Status:** Deferred.
**Problem:** The E2E spec originally called for Chromium + Firefox + WebKit. CI only runs Chromium.
**Options:**
- A: Add Firefox and WebKit to `playwright.config.js` projects array (slow, ~3× CI time).
- B: Run Firefox/WebKit on a nightly schedule, Chromium on every PR.
- C: Keep Chromium-only (fast CI, coverage gap on Safari/Firefox rendering).
**Trade-offs:** A/B add confidence on cross-browser rendering; C is pragmatic for a POC.

---

### TD-007 · Backoffice open-market UI test (E2E GAP-7)

**Status:** ✅ Done (PR #31). `e2e/playwright/tests/backoffice-open-market.spec.js` added.
**Problem:** The backoffice open-market form (`POST /backoffice/markets/:id/open`) is not covered by any E2E test. The test that creates a market via admin API opens it immediately, so the UI open path is never exercised.
**Effort:** Low. Needs a test that creates a draft market via admin API (without opening), then opens it via the backoffice UI.

---

### TD-008 · Player positions and execution HTML views (E2E GAP-9, GAP-10)

**Status:** Not implemented (JSON-only endpoints).
**Problem:** `GET /web/positions` and `GET /web/betslips/executions/:id` return JSON only. No HTML views exist. Players cannot see their positions or execution confirmations in a browser.
**Impact:** Meaningful UX gap. The E2E suite tests these as API endpoints only.
**Task:** `.claude/tasks/td008-positions-views/`

---

### TD-009 · SQLite ILIKE + jsonb test fidelity gap

**Status:** Structural gap (not a bug yet, but hidden risk).
**Problem:** Full-text search uses Arel `.matches` which generates `ILIKE` on PostgreSQL but `LIKE` on SQLite (case-sensitive on some platforms). The `tags` column is `jsonb` in PostgreSQL; in SQLite it is stored as text. Tests pass locally under SQLite but may not catch ILIKE case-sensitivity edge cases or jsonb operator errors.
**Blocked by:** DD-004 (test DB decision).
**Impact:** Low for current tests; would surface immediately if tags search logic gets more sophisticated.

---

### TD-010 · Binary line trigger not exercised in SQLite tests

**Status:** Structural gap.
**Problem:** The `enforce_max_two_market_legs` PostgreSQL BEFORE INSERT trigger is defined in a migration but SQLite ignores it. The Minitest suite tests the Rails-level validation (`MarketLeg` model guard + `Market#requires_two_legs_to_open`), but the DB-level trigger is only exercised in CI where PostgreSQL is used. A future Rails-level validation bypass would not be caught locally.
**Blocked by:** DD-004.

---

### TD-011 · Market edit form (backoffice)

**Status:** ✅ Done (PR #31). DD-007 resolved as Option B. Edit Details panel in `show.html.erb` supports `description`, `close_at`, `resolution_criteria`, `resolution_source`, `category`, `tags`. Financial fields locked once open.
**Problem:** Operators cannot update a market's `description`, `close_at`, `resolution_criteria`, or `resolution_source` through the backoffice UI after creation. The admin JSON API (`PATCH /admin/markets/:id`) supports updates, but backoffice has no edit form.
**Effort:** Low. Standard Rails edit/update pattern identical to the existing create form.
**Impact:** Operators must use the API directly for any correction after creation.

---

### TD-012 · Market list pagination

**Status:** Not implemented.
**Problem:** `Web::MarketsController#index` and `Backoffice::MarketsController#index` load all markets without pagination. Seeds already generate 17 markets; in production this will grow.
**Effort:** Low. Add `page`/`per_page` params and standard Rails pagination (kaminari or `limit`/`offset`).
**Impact:** Performance and UX degrade with market volume; not urgent for POC.

---

## Open design decisions

For each: short options with trade-offs. These are inputs for the next product/architecture discussion — no code should be written until one option is chosen.

---

### DD-001 · F-009 Automated market close

**Question:** What happens when a market's `close_at` datetime passes?
**Context:** `close_at` field exists on markets (added in F-003). No automated action fires when it passes.

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: `CloseExpiredMarketsJob` (cron) | Background job runs every minute, finds markets where `close_at < now` and `status = open`, transitions to a new `closed` status. Betting blocked on closed markets. | + Simple, auditable. − New enum value needed. Requires operator to then settle manually. |
| B: Gate at bet placement | `BetPlacementService` checks `close_at` at bet time. No new status; market stays `open` until operator settles. | + No job needed. − No signal to players that betting is over. Market appears open. |
| C: Auto-settle on close_at | Job fires and immediately settles the market (requires a resolution source). | + Fully automated. − Needs trusted oracle / resolution source integration. Not viable without external data. |

**Recommendation:** Option A. A `closed` status is semantically correct and clearly communicates state to players. Operator retains control over settlement. Plan already written: `docs/superpowers/plans/2026-05-28-f009-automated-market-close.md`.

---

### DD-002 · LMSR v2 settlement payout model

**Question:** How should individual LMSR positions be tracked for payout at settlement?

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Position model (new table) | Add `lmsr_positions` table: `(user_id, market_id, side, contracts)`. Update on every trade. Settle by iterating positions. | + Clean model, easy to query. − Extra write on every trade; migration needed. |
| B: Replay ledger entries | Derive positions from `ledger_entries` with `entry_type = LMSR_TRADE`. Settlement replays history. | + No new table. − Slow on large markets; logic in settlement handler. |
| C: `lmsr_contracts_minor` on bets | Re-use the `bets` table with a `contracts` field for LMSR. | + Leverages existing settlement machinery. − `bets` model semantics don't map cleanly to AMM trades. |

**Recommendation:** Option A. Cleanest model. LMSR trades are frequent enough that a dedicated position table is justified. B is acceptable only for low-volume markets.

---

### DD-003 · Parimutuel v2 — migrate to ParimutuelBet model

**Question:** Should parimutuel bets get a dedicated model or stay on LedgerEntry?

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Add `ParimutuelBet` model | Table with `(user_id, market_id, side, stake_minor, status)`. Settlement iterates this table. | + Queryable history, voidable, consistent with other mechanisms. − Migration + backfill. |
| B: Keep LedgerEntry-only | Current approach. Pool totals derived by summing `PARIMUTUEL_STAKE` entries. | + No change needed. − Hard to void individual bets; awkward to display bet history. |

**Recommendation:** Option A when parimutuel markets gain traction. Not urgent for POC.

---

### DD-004 · Test DB adapter (SQLite vs PostgreSQL)

**Question:** Should the test suite use SQLite (current) or PostgreSQL?

**Context:** Tests run against SQLite3 (`storage/test.sqlite3`). Production uses PostgreSQL. Schema includes PostgreSQL-specific triggers (binary line invariant), `jsonb` columns, and `ILIKE`. SQLite silently ignores FK constraints and doesn't support these.

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Keep SQLite for tests | Current state. `validate.sh` uses `db:reset` to avoid FK issues. | + Fast, no Docker needed for unit tests. − PostgreSQL-specific features (triggers, jsonb ops, ILIKE) not tested. |
| B: Switch tests to PostgreSQL | All tests run against Docker PostgreSQL. | + Matches production. Catches trigger/constraint issues. − Docker required for all test runs; slower startup. |
| C: Dual adapter (SQLite for unit, PG for integration) | Minitest categories: unit (SQLite), integration (PG). | + Speed for unit tests. − Complex setup; easy to mis-categorize tests. |

**Recommendation:** Option B for correctness (the binary line trigger already tests against PG in the current integration test — but only because the test suite happens to target PG in CI). Option A is acceptable for POC velocity. This is the most consequential pending decision.

---

### DD-005 · ADR-0013 duplicate / numbering conflict

**Status:** ✅ Resolved (2026-05-28). Duplicate `ADR-0013-clob-order-book-migration.md` deleted; ADR-0013 and ADR-0011/ADR-0012 all marked Accepted.

---

### DD-006 · CLOB cashout mechanism

**Question:** How should players exit CLOB positions before settlement?
**Context:** `CashoutQuoteService`/`CashoutExecutionService` handle fixed-odds voids only. CLOB players hold contracts (YES/NO) that are only redeemable at settlement.

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Sell limit order on book | Player posts a sell order; matched against buyers on the CLOB. | + Pure market mechanics; price reflects true demand. − Player may be stranded with no buyer; not a guaranteed exit. |
| B: Operator buyback at mid-price | Platform creates a standing buyback offer at `(best_bid + best_ask) / 2`. | + Guaranteed exit at any time. − Operator takes mark-to-market risk; requires a funded buyback wallet. |
| C: No cashout — hold to settlement | Current state. CLOB positions are illiquid until settlement. | + Zero implementation cost. − Player-unfriendly, especially for long-duration markets. |

**Recommendation:** Option A for correctness (exchange semantics). Option C acceptable for short-lived POC markets.

---

### DD-007 · Market edit scope (what fields are updatable after open?)

**Question:** Which market fields should the backoffice be able to edit, and at which lifecycle stages?
**Context:** TD-011 proposes adding an edit form. The question is what can change after the market opens.

| Option | Description | Trade-offs |
|--------|-------------|-----------|
| A: Edit any field while draft | Only pre-open edits. Once open, market is locked. | + Simplest invariant. − Operators can't fix typos in live market descriptions. |
| B: Allow `description`, `close_at`, `resolution_criteria`, `resolution_source` while open | Metadata-only updates on live markets. Mechanism, legs, and fee fields locked once open. | + Practical for real operations. − Need to differentiate which fields are locked. |
| C: Full edit at any status | All fields editable at any time. | + Maximum flexibility. − Risk of changing mechanism/odds on live markets mid-bet. |

**Recommendation:** Option B. Financial fields (`mechanism_type`, `fee_bps`, `liability_cap_minor`, legs) should be immutable once a market is open; metadata is safe to update.
