# Adivento Deep Review — Cross-Cutting Synthesis

Date: 2026-05-29
Source plan: `docs/superpowers/plans/2026-05-29-specialist-review-dispatch.md`
Inputs: all 12 specialist reports in this folder.

## Method

Twelve specialist reviews were dispatched in parallel (read-only), each writing one
report. This synthesis merges their findings by **root cause**, assigns a single
canonical ID per issue, maps each canonical ID to the per-report suggestions and to
existing backlog IDs, and proposes an execution sequence. Per the dispatch plan,
proposed edits to `ATTENTION.md`, `tech-debt-backlog.md`, and `UX_BACKLOG.md` are
listed here as proposals only — no live backlog files were modified.

### Review coverage

| Family | Report | Top severity found |
|--------|--------|--------------------|
| Architecture | `architecture.md` | P0 ×3 |
| Rails/code correctness | `code-correctness.md` | P0 ×4 |
| Market mechanics | `market-mechanics.md` | P0 ×2 |
| Data/Postgres | `data-postgres.md` | P0 ×6 |
| Security/trust/compliance | `security-trust.md` | P0 ×2 |
| Product/roadmap | `product-roadmap.md` | P0 ×2 |
| UX research / IA | `ux-research-ia.md` | P0 ×3 |
| UI visual design | `ui-design.md` | P0 ×4 |
| Mobile app design | `mobile-design.md` | P0 ×2 |
| QA/E2E/release | `qa-release.md` | P0 ×3 |
| DevOps/operability | `devops-operability.md` | P0 ×2 |
| Docs/backlog hygiene | `docs-handoff.md` | P0 ×2 |

## ID namespace

Adopting the `docs-handoff.md` recommendation (DOC-009), canonical IDs are namespaced:
`TD-` backend/data correctness, `SEC-` security/trust, `UX-` frontend/UX, `MOB-` mobile,
`QA-` testing, `OPS-` devops, `DOC-` docs. Existing IDs (TD-013…TD-022, UX-001…UX-035)
are reused where the finding already has one. New backend IDs continue at **TD-023**;
new UX at **UX-036**.

---

## Cross-cutting root-cause clusters

The 100+ raw findings collapse into a small number of root causes that recur across
reports. Fixing the cluster fixes many findings at once.

### Cluster 1 — CLOB settlement pays raw filled orders, not net positions (P0)
`ClobSettlementHandler` Pass 2 credits every winning-side order with `filled_quantity > 0`
regardless of `direction`. A player who buys YES then sells all YES is paid at settlement,
**and** so is the buyer of that sell order — double payout on the same contracts, directly
corrupting fantasy balances.
- Evidence: `app/services/settlement/clob_settlement_handler.rb:29`.
- Reported by: architecture (ARCH-001), code-correctness (CC-003/P0), data-postgres (DB-002),
  market-mechanics (TD-018), security-trust (SEC-002), product (PROD-002), qa (QA-003).
- **Canonical: TD-018.** Settle from `Clob::NetPositionService` output; add buy→sell→settle regression.

### Cluster 2 — Open CLOB sell orders do not reserve contracts (P0)
`validate_sell_position!` checks net holdings once at order creation; unfilled sells reserve
nothing, so a holder of 10 contracts can post multiple 10-contract sell orders and oversell.
- Evidence: `app/services/clob/order_matching_service.rb:72-75`; `app/models/order.rb:20-21`.
- Reported by: architecture (ARCH-002), market-mechanics (TD-019), product (PROD-010), qa (QA-004).
- **Canonical: TD-019.** Subtract unfilled sells in `NetPositionService`; re-validate under row lock at fill time.

### Cluster 3 — Inconsistent wallet row locking → double-spend / double-credit (P0)
Multiple services read `user.wallet` (or credit it) **without `lock!`** inside their
transaction, or read balance before the transaction. The correct pattern already exists in
`OrderMatchingService` / `LmsrTradeService`. Affected: `BetPlacementService:18` (TD-013),
`BetVoidService:11`, `CashoutExecutionService:12`, `SettlementService#settle_fixed_odds!:59`,
`ClobSettlementHandler` Pass 1 `:18`, `ParimutuelSettlementService#refund_all!:74`,
`WalletGrantService#approve!:6`, and `Admin::OrdersController#destroy` (no order/wallet lock).
- Reported by: code-correctness (CC-001/P0), data-postgres (DB-001/P0), security-trust (SEC-001),
  architecture (P0), qa (QA-012). TD-013 today covers only `BetPlacementService`.
- **Canonical: TD-013 (expand scope to all listed services + add concurrency test).**

### Cluster 4 — No DB-level guards on financial invariants (P1)
Wallet non-negativity, order price range, quantity, and `mechanism_type` enum are enforced
only by Active Record validations — bypassable by `update_column`/raw SQL. `metadata`/`tags`
are `json` not `jsonb` (no GIN index; parimutuel settlement does a full-table JSON scan), and
`index_orders_book` was never updated when `direction` was added.
- Reported by: data-postgres (DB-003/DB-004/DB-005/DB-006).
- **Canonical: TD-023 (CHECK constraints), TD-024 (json→jsonb + GIN), TD-025 (order-book + ledger indexes).**

### Cluster 5 — P&L / positions incomplete for non-fixed-odds mechanisms (P1/P2)
LMSR positions never render on the Positions page (TD-014); profile P&L queries only `bets`;
`LeaderboardController` constants omit `CLOB_SELL_CREDIT`, `PARIMUTUEL_REFUND`, `LMSR_FEE`,
`CLOB_FEE` (TD-015). No single source of P&L truth shared by leaderboard and profile.
- Reported by: architecture (ARCH-008), code-correctness (CC-006), product (PROD-005),
  ux-research (UX P0 LMSR positions), market-mechanics.
- **Canonical: TD-014 (LMSR positions), TD-015 (leaderboard constants), TD-026 (`UserPnlService` shared aggregator).**

### Cluster 6 — Operator/settlement trust controls are single-step and coarse (P1)
Moderators can settle in one POST with no proposal/approval/evidence step; `market.settle`
granted to moderator by default; audit events lack before/after, actor role, request context;
`MarketCancellationService` (TD-017) still absent; settle UI is a `data-confirm` dialog with no
payout preview.
- Reported by: security-trust (SEC-003/SEC-004/SEC-005/SEC-006/SEC-010), ux-research (settle P1),
  ui-design (DS-012), architecture (settlement router P1), docs-handoff.
- **Canonical: SEC-003 (resolution workflow), SEC-004 (permission split), SEC-005 (audit schema),
  TD-017 (cancellation), UX-030 (two-step settle preview).**

### Cluster 7 — New-player funnel is broken end to end (P0 for demo)
No web registration form (`POST /auth/register` is JSON-only; sign-in says "use seeded users");
faucet requires moderator approval with no in-app pending state; no first-run nudge. Nothing
downstream (leaderboard/profile/positions) is reachable by a real new user.
- Reported by: product (PROD-001/PROD-007), ux-research (UX P0 register, UX-NEW-02/07/09).
- **Canonical: UX-036 (web register form + session login), UX-037 (registration faucet bonus/nudge),
  UX-038 (pending-faucet banner).**

### Cluster 8 — Price history collected but never surfaced (P1)
`PriceSnapshot` is written on every trade by `RecordPriceSnapshotJob` but no endpoint or chart
reads it — the single most visible gap vs Polymarket/Kalshi. Table also grows unbounded.
- Reported by: product (PROD-003), architecture (ARCH-010/P3), ux-research (P3), qa (no job test).
- **Canonical: UX-039 (price-history endpoint + inline SVG chart), TD-027 (snapshot retention/prune).**

### Cluster 9 — Pluggable-mechanism seam leaks; pricing/settlement not uniform (P1/P2)
Settlement router is a raw `case` string switch; fixed-odds settlement is an inline private
method while CLOB/LMSR use handler objects and parimutuel is called differently; pricing engines
are nested inner classes on `Market` and `order_book_summary` ignores `direction` (corrupting
buyback mid-price and SSE depth).
- Reported by: architecture (ARCH-003/ARCH-004/ARCH-006), code-correctness (CC-002).
- **Canonical: TD-028 (unify settlement handler interface), TD-029 (fix `order_book_summary` direction),
  TD-030 (extract pricing engines), TD-021 (shared order-cancellation service), TD-020 (admin order guards).**

### Cluster 10 — Operability gaps: Redis & job worker not actually running (P0 for deploy)
Redis is documented as a live dependency but the gem is commented out, no `REDIS_URL` is set, and
Compose/CI never start it — hot storage silently degrades to `NullRedis`. Recurring jobs
(`CloseExpiredMarketsJob`) have no worker/scheduler process; SSE renders a single event despite
docs promising streaming/resume; E2E seeds a "production" DB on server start.
- Reported by: devops (OPS-001…OPS-005), code-correctness (CC-009 Redis-in-transaction).
- **Canonical: OPS-001…OPS-005 (kept as-is).**

### Cluster 11 — Accessibility & design-system baseline (P0/P1 a11y, P2 system)
Missing `<html lang>`, no `:focus-visible` on buttons/links, backoffice labels not associated,
backoffice dark-theme colors leaking into two web views below 4.5:1 contrast; ~60 hardcoded hex
values bypass the 6 design tokens; zero responsive breakpoints; raw SSE dev link exposed publicly.
- Reported by: ui-design (DS-001…DS-018), ux-research (denomination/SSE link), mobile (no breakpoints).
- **Canonical: UX-040 (a11y baseline: lang/focus/labels/contrast), UX-041 (design tokens + responsive),
  UX-042 (remove public SSE link), UX-043 (denomination label consistency).**

### Cluster 12 — Mobile strategy undecided but low-cost path is clear (P1→P3)
No responsive CSS, no PWA manifest, no mobile E2E, no Turbo/Hotwire in the Gemfile. Recommended
path is **responsive web → PWA manifest → Turbo Native thin shell**, explicitly rejecting
React Native/Flutter/native for the POC stage.
- Reported by: mobile (MOB-001…MOB-009), product (P3 defer native).
- **Canonical: MOB-001…MOB-009 (kept); ADR-0015 to formalize the recommendation.**

### Cluster 13 — Docs/backlog hygiene drift (P1/P2)
`market-mechanisms.md` says CLOB cashout / LMSR payouts are unimplemented (contradicts INDEX +
PR #35/#36); `product/BACKLOG.md` still describes fixed-odds-only; F-IDs are overloaded across
docs; some active plans lack reviews; UX-010/UX-035/UX-034 blockers are stale.
- Reported by: docs-handoff (DOC-002…DOC-009), product, mobile.
- **Canonical: DOC-002…DOC-009 (kept).**

---

## Consolidated prioritized backlog

### Tier 0 — Must fix before any credible demo (financial integrity & funnel)

| Canonical ID | Title | Cluster | Existing ID | Source reports |
|---|---|---|---|---|
| TD-018 | Settle CLOB by net positions, not raw filled orders | 1 | TD-018 | arch, code, data, mkt, sec, prod, qa |
| TD-019 | Reserve contracts for open CLOB sell orders | 2 | TD-019 | arch, mkt, prod, qa |
| TD-013 | Lock wallet rows across all mutation paths (expand scope) + concurrency test | 3 | TD-013 | code, data, sec, arch, qa |
| UX-036 | Web registration form + session-cookie login + "Create account" link | 7 | — | prod, ux |

### Tier 1 — Plan next (trust, correctness hardening, headline product gaps)

| Canonical ID | Title | Cluster | Existing ID | Source reports |
|---|---|---|---|---|
| TD-023 | DB CHECK constraints: wallet ≥ 0, price 1–99, quantity > 0, mechanism_type enum | 4 | — | data |
| TD-024 | Migrate metadata/tags `json`→`jsonb` + GIN indexes | 4 | — | data |
| TD-025 | Add `direction` to order-book index + `(user_id, entry_type)` ledger index | 4 | — | data |
| TD-014 | Expose LMSR positions on Positions page | 5 | TD-014 | arch, code, ux |
| TD-015 | Fix leaderboard P&L entry-type constants | 5 | TD-015 | arch, code, prod |
| TD-026 | `UserPnlService` shared by leaderboard + profile (cross-mechanism P&L) | 5 | — | arch, code, prod |
| TD-029 | Fix `ClobPricingEngine#order_book_summary` to filter `direction` | 9 | — | arch |
| TD-020 | Admin CLOB order lifecycle guards (market open/close_at) | 9 | TD-020 | arch, code |
| TD-021 | Shared `Clob::OrderCancellationService` with consistent locking | 9 | TD-021 | arch, code |
| TD-017 | `MarketCancellationService` + backoffice cancel action | 6 | TD-017 | sec, arch |
| SEC-003 | Resolution propose/approve/execute workflow | 6 | — | sec, ux |
| SEC-004 | Split trust-sensitive permissions; moderator cannot settle by default | 6 | — | sec |
| SEC-005 | Strengthen audit schema (before/after, actor role, request context) | 6 | — | sec |
| SEC-007 | Production auth hardening (fail on default JWT secret, login audit, throttle, revocation) | — | — | sec |
| UX-030 | Two-step settle confirmation with payout preview | 6 | UX-030 | sec, ux, ui |
| UX-039 | Price-history endpoint + inline SVG chart on market detail | 8 | UX-004 | prod, arch, ux |
| UX-040 | Accessibility baseline: `lang`, `:focus-visible`, label association, contrast fix | 11 | — | ui |
| OPS-001 | Make Redis a real runtime dependency (gem, URL, Compose, healthcheck) | 10 | — | devops, code |
| OPS-002 | Wire background job worker + recurring scheduler (Solid Queue) | 10 | — | devops |
| QA-003 | TD-018 regression test (buy→sell→settle pays seller zero) | 1 | — | qa |
| QA-004 | TD-019 duplicate-sell rejection test | 2 | — | qa |
| QA-012 | Wallet-balance concurrency regression test | 3 | — | qa |
| QA-001 | `clob_cashout` controller integration tests | — | — | qa |

### Tier 2 — Meaningful quality / adoption

| Canonical ID | Title | Cluster | Source |
|---|---|---|---|
| TD-027 | PriceSnapshot retention/prune policy | 8 | arch, prod |
| TD-028 | Unify settlement handler interface (extract FixedOdds/Parimutuel handlers) | 9 | arch |
| TD-030 | Extract pricing engines from `Market` inner classes to `app/services/pricing/` | 9 | arch |
| TD-031 | Fix `LmsrTradeService#upsert_position` race (atomic upsert) | — | code, data |
| TD-032 | Restrict draft-market visibility to backoffice roles | — | code |
| TD-033 | `CloseExpiredMarketsJob` system-actor fallback + error surfacing | — | code, devops |
| SEC-008 | Audit read surfaces + user-visible market changelog | 6 | sec |
| SEC-010 | (folded into UX-030) | 6 | sec |
| UX-037 | Registration faucet bonus / first-run nudge | 7 | prod, ux |
| UX-038 | Pending-faucet status banner on profile | 7 | prod, ux |
| UX-041 | Design tokens + responsive breakpoints (web + backoffice) | 11 | ui, mobile |
| UX-042 | Remove public SSE dev link from market trust panel | 11 | ux, ui |
| UX-043 | Consistent ADIV/minor-unit denomination labels | 11 | ux |
| UX-006 | CLOB open-orders list + cancel button (unblock UX-010/UX-035) | — | prod, ux |
| UX-044 | Cashout HTML flow on Positions page (fixed-odds/parimutuel) | — | ux |
| UX-045 | Backoffice dashboard mission-control layout (UX-027–029) | — | ux, ui |
| MOB-001 | Mobile responsive CSS (nav collapse, search width, card reflow) | 12 | mobile |
| MOB-004 | PWA manifest + iOS/Android meta tags | 12 | mobile |
| OPS-004 | Readiness checks (DB/Redis/worker) distinct from `/up` liveness | 10 | devops |
| OPS-005 | Split production boot from E2E seed/setup | 10 | devops |
| QA-005 | `BetTest` model state-machine tests | — | qa |
| QA-006 | Full parimutuel settlement-path unit test | — | qa |
| QA-008 | LMSR E2E asserts wallet balances (remove stale deferral) | — | qa |
| QA-010 | Cross-browser E2E on nightly schedule (TD-006) | — | qa |
| QA-011 | Per-mechanism wallet-vs-ledger conservation tests | — | qa, mkt |
| DOC-002 | Refresh `market-mechanisms.md` after PR #35/#36 | 13 | docs |
| DOC-005 | Reconcile `product/BACKLOG.md` with four-mechanism reality | 13 | docs, prod |

### Tier 3 — Polish / long horizon
PriceSnapshot UI sparklines, dark-mode web theme, sticky bet rail (UX-003), CLOB label
semantics, LMSR sell-trade decision (TD per market-mechanics TD-026), responsible-gaming ADR
(SEC-009), mobile bottom tab bar / bet sheet / Turbo Native shells (MOB-002/003/006/008/009),
ADR-0015 mobile strategy, remaining DOC-006…DOC-009 hygiene items.

---

## Recommended execution sequence

The dispatch reports converge on this ordering (it contradicts the current `ATTENTION.md`,
which sequences TD-013→TD-017 before TD-018/TD-019 — see proposed update below).

1. **PR-1 — CLOB safety (Tier 0 financial):** TD-018 + TD-019 together, tests-first
   (QA-003, QA-004). These are P0 balance-corrupting and ship the moment any CLOB market goes live.
2. **PR-2 — Wallet locking (Tier 0 financial):** TD-013 expanded across all services + QA-012
   concurrency test.
3. **PR-3 — DB invariants:** TD-023/TD-024/TD-025 (constraints + jsonb + indexes). Independent; can run parallel to PR-1/2.
4. **PR-4 — Demo funnel:** UX-036 registration (+ UX-037/UX-038), then TD-014 LMSR positions and TD-015/TD-026 P&L.
5. **PR-5 — Trust layer:** SEC-003/004/005 + UX-030 settle preview + TD-017 cancellation. Larger; spec first.
6. **PR-6 — Product headline:** UX-039 price-history chart.
7. **PR-7 — Operability:** OPS-001/002 (Redis + worker) before any real deploy.
8. **Ongoing:** accessibility (UX-040), docs reconciliation (DOC-002/005), mobile Phase 1 (MOB-001/004), QA backfill.

---

## Proposed backlog-file updates (not yet applied)

**`.claude/tasks/ATTENTION.md`** — reorder the "Ready for Autonomous Work" table so TD-018 and
TD-019 sit at the top (P0), ahead of TD-013→TD-017; add the new canonical IDs (TD-023…TD-033,
SEC-003…SEC-007, UX-036…UX-045, OPS-001…OPS-005, QA-001…QA-012) with the plan column pointing at
the new plans below; add a pointer to this synthesis.

**`docs/wiki/tech-debt-backlog.md`** — append TD-023…TD-033 with the evidence and acceptance
checks from the source reports; update TD-013 scope note (now spans 8 call sites + admin
controller); add an ID-namespace legend (DOC-009).

**`docs/wiki/UX_BACKLOG.md`** — add UX-036…UX-045; unblock UX-010/UX-035 (cancel route exists)
and UX-034 (independent of community features) per DOC-007; mark UX-004 as superseded by UX-039.

**`docs/wiki/market-mechanisms.md`** — mark CLOB sell/cashout/buyback and LMSR payouts as shipped
(PR #35/#36); link remaining risks to TD-018/TD-019.

## Proposed new specs/plans (to author, not implement here)

- `docs/superpowers/plans/2026-05-30-clob-sell-settlement-safety.md` — TD-018 + TD-019 (urgent).
- `docs/superpowers/plans/2026-05-30-wallet-locking-hardening.md` — TD-013 expanded.
- `docs/specs/2026-05-30-db-financial-invariants.md` — TD-023/024/025.
- `docs/superpowers/plans/2026-05-30-demo-funnel.md` — UX-036/037/038 + TD-014/015/026.
- `docs/adr/ADR-0015-mobile-native-strategy.md` — Turbo Native recommendation (MOB-006).
- `docs/specs/2026-05-30-resolution-trust-workflow.md` — SEC-003/004/005 + UX-030 + TD-017.

## Open questions for the product owner

1. **Primary demo mechanism?** Four mechanisms create demo overload; reports recommend declaring one (CLOB or fixed-odds) as the headline. (product P3, docs-handoff)
2. **Ledger semantics:** may a `LedgerEntry` represent non-cash position acquisition (e.g. `ORDER_FILL_CREDIT`), or must entries be cash-only? Determines TD-026 P&L correctness. (market-mechanics Q1)
3. **Fixed-odds cashout ledger:** gross payout + fee debit, or net payout with fee in metadata? (market-mechanics Q3)
4. **LMSR v1:** intentionally buy-only, or implement the spec's sell path? (market-mechanics Q4)
5. **Parimutuel rounding:** largest-remainder, operator dust, or carried residual for leftover minor units? (market-mechanics Q5)
6. **Registration credits:** auto-grant a starter balance on registration to bypass the faucet wait for demos? (product PROD-007)
7. **Mobile timeline:** approve Turbo Native (ADR-0015) and decouple from community features? (mobile, docs-handoff)
