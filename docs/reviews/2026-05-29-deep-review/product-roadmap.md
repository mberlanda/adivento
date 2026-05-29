# Product / Roadmap Deep Review

**Reviewer role:** Product strategy & competitive analysis  
**Date:** 2026-05-29  
**Worktree:** /private/tmp/adivento-specialist-reviews  

---

## Scope

### Files / docs inspected

| File | Purpose |
|------|---------|
| `docs/INDEX.md` | Implementation status, architecture decisions |
| `docs/WORK_LOG.md` | Chronological delivery record |
| `docs/product/BACKLOG.md` | Feature backlog F-001 through F-012 |
| `docs/wiki/tech-debt-backlog.md` | TD-001 through TD-022, open design decisions |
| `docs/wiki/product-overview.md` | Actor model, wallet, market lifecycle |
| `docs/wiki/market-mechanisms.md` | Mechanism comparison table |
| `docs/wiki/UX_BACKLOG.md` | UX-001 through UX-035 |
| `docs/wiki/architecture.md` | (listed; not re-read — covered by INDEX) |
| `docs/specs/PREDICTION_MARKET_BUSINESS_MODEL_SPEC.md` | Legacy fixed-odds spec |
| `docs/design/00-design-brief.md` | Design principles, theme directions |
| `docs/design/02-flows-and-use-cases.md` | Wireframe acceptance criteria |
| `docs/design/04-public-and-community-markets.md` | Community/group visibility model |
| `docs/superpowers/plans/2026-05-29-backend-next-steps.md` | TD-013 through TD-017 plan |
| `docs/superpowers/plans/2026-05-29-ux-market-browse-detail.md` | UX PR A plan |
| `docs/superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md` | UX PR B plan |
| `docs/plans/ITERATION_005_MASTER_TODO_TREE.md` | Iteration 005 status |
| `app/controllers/web/` (full directory) | Feature completeness check |
| `app/controllers/backoffice/markets_controller.rb` | Settlement, cancel, operator actions |
| `app/services/settlement/clob_settlement_handler.rb` | CLOB settlement logic |
| `app/controllers/web/positions_controller.rb` | LMSR position gap verification |
| `app/controllers/web/leaderboard_controller.rb` | Leaderboard RETURN_TYPES / STAKE_TYPES |
| `app/views/web/markets/show.html.erb` | Resolution panel, settlement display |
| `app/views/web/sessions/new.html.erb` | Registration UI check |
| `app/views/backoffice/markets/show.html.erb` | Settlement form, resolution note |
| `config/routes.rb` | Full route inventory |
| `db/structure.sql` | Table inventory, schema shape |
| `docs/PRIVATE_PREDICTION_MARKETS.md` | Original architectural spec |

### Explicitly out of scope

- Test quality and coverage adequacy (covered by the technical debt specialist review)
- Infrastructure, CI/CD, Docker configuration
- Security review (separate reviewer)
- Code style and RuboCop compliance (TD-022)
- ADR review (architecture specialist)

---

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|
| P0 | **No player self-registration UI.** `POST /auth/register` exists as a JWT API endpoint but there is no web form. The only sign-in form (`GET /signin`) has a note "Use one of the seeded users" — guests cannot create an account without direct API access. This breaks the core acquisition loop and disqualifies the product as a demo for any audience that is not already technical. | `app/views/web/sessions/new.html.erb:2`, `config/routes.rb:6-8` — no `GET /register` route exists in the web namespace; `POST /auth/register` is JWT-only. | Add `GET /web/register` → a simple HTML form that POSTs to `POST /auth/register` (or a new session-cookie register action). First-run faucet nudge on success. Already partially planned as UX-023 in `docs/wiki/UX_BACKLOG.md` but sequenced as PR B — must be pulled forward to P0. |
| P0 | **CLOB settlement double-pays sold contracts.** `ClobSettlementHandler` (Pass 2) iterates all orders on the winning side with `filled_quantity > 0` regardless of `direction`. A player who bought YES and then sold all YES contracts via a sell limit order (DD-006, shipped PR #36) still receives a `SETTLEMENT_WIN` payout at settlement, as does whoever filled that sell order — creating a double payout for the same contracts. This directly corrupts the ledger. | `app/services/settlement/clob_settlement_handler.rb:29-38` — query is `where(side: @winning_side).where.not(filled_quantity: 0)` with no `direction` filter. TD-018 in `docs/wiki/tech-debt-backlog.md:160`. | Fix `ClobSettlementHandler` to settle net long positions (use `Clob::NetPositionService` or subtract filled sell quantity from filled buy quantity per user before issuing credits). This is a data-integrity issue, not a UX gap — it must precede any CLOB market that goes live. |
| P1 | **No price-history endpoint or chart.** `PriceSnapshot` model and `RecordPriceSnapshotJob` write snapshots on every trade, yet there is no `GET /web/markets/:id/price_history` endpoint and no chart on the market detail page. Price-history is described as the central trading-decision signal by both the backlog (`docs/product/BACKLOG.md:F-004`) and the design brief (`docs/design/02-flows-and-use-cases.md:16`). The data is being silently collected but never surfaced — this is the single most visible gap between Adivento and Polymarket/Kalshi at the market-detail level. The UX-004 plan placeholder in PR A adds a "stub" (`@price_history = []`) rather than a real chart. | `app/services/price_snapshot_recorder.rb:1-27` (recorder exists), `docs/wiki/UX_BACKLOG.md:4` (UX-004 — open), `docs/superpowers/plans/2026-05-29-ux-market-browse-detail.md:20` — `@price_history` stub only. `docs/product/BACKLOG.md:119` — rated High/L. | Spec and implement a `GET /web/markets/:id/price_history` JSON endpoint, then add a minimal SVG line chart (inline, no npm deps) to the market detail view. The snapshot data is already there — this is a display and routing problem, not a data model problem. |
| P1 | **No player registration flow is the prerequisite for all engagement loops.** The onboarding sequence (register → faucet → first bet → position → leaderboard) is entirely broken at step 0. Until self-registration exists in the web UI, the leaderboard (F-007, done), profile (F-005, done), and positions page (F-012, done) are only accessible to pre-seeded users. The product cannot be demo'd to a non-technical audience or tested by a real user. | `config/routes.rb:6-8` — only `GET /signin` exists; no `GET /web/register`. `auth/sessions_controller.rb:69` — `POST /auth/register` is JWT only. UX-023 in `docs/wiki/UX_BACKLOG.md:38`. | Same as P0 registration finding — the scope of impact elevates this. |
| P1 | **Resolution transparency (F-010) partially missing.** Settlement records `settled_outcome` but there is no mandatory `resolution_note`. The backoffice settle form has a "Reason" text field (`app/views/backoffice/markets/show.html.erb:86`) but that field is not persisted anywhere — there is no `resolution_note` column in `db/structure.sql` and no settlement service code that saves it. Players who lose bets see the outcome badge but cannot verify why. This is the trust-gap Kalshi and Polymarket explicitly close with resolution notes and source citations. | `db/structure.sql:368-398` — no `resolution_note` column. `app/services/settlement_service.rb` — no `resolution_note` param. `app/views/backoffice/markets/show.html.erb:86` — `text_field_tag :reason` collected but silently discarded. `docs/product/BACKLOG.md:F-010:320`. | Add `resolution_note` and `settled_at` columns to `markets`; make `reason` a required field in the settle forms (backoffice + admin API); display in the market's Resolution Details panel. Small migration + service change. |
| P1 | **Profile P&L is fixed-odds only; CLOB/LMSR/parimutuel activity is invisible.** `Web::ProfileController` queries only the `bets` table, so a player who has only traded on CLOB, LMSR, or parimutuel markets sees P&L = 0 and Bets = 0. This is a trust gap — the profile is the primary retention surface and it lies about multi-mechanism activity. The leaderboard has been fixed for cross-mechanism P&L (F-015) but the profile page was not included. | `app/controllers/web/profile_controller.rb` (referenced in `docs/WORK_LOG.md:225`) — F-005 spec notes bet history from `bets` table. `docs/wiki/tech-debt-backlog.md:131` — profile P&L gap noted under TD-015. | Extend `ProfileController` to aggregate `LedgerEntry` (using the same `STAKE_TYPES`/`RETURN_TYPES` constants now corrected in TD-015 / leaderboard controller) and display cross-mechanism P&L on the profile page. Can piggyback on the same PR that fixes TD-015. |
| P2 | **Faucet UX creates a friction cliff for new players.** Players start with 0 ADIV balance and must (a) find the faucet request, (b) wait for moderator approval, then (c) return to bet. There is no in-app state during the wait, no email notification, no estimated approval time. Competitors bypass this by giving instant demo credits on registration. For a POC where the goal is demo credibility, a pending-faucet status banner (UX-019) and a first-run nudge (UX-024) are disproportionately high-value relative to their implementation effort. These are planned in PR B (`docs/superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md`) but currently unscheduled. | `app/views/web/profile/show.html.erb` — no pending-faucet banner. `docs/wiki/UX_BACKLOG.md:34-38` — UX-018, UX-019, UX-024 all open. No `FaucetRequest` status check in profile controller evident in docs. | Pull UX-019 (pending-faucet banner) and UX-024 (post-register faucet nudge) forward from PR B. Consider auto-granting a small initial balance on registration (100 ADIV) to remove the blocking wait entirely for demo purposes. |
| P2 | **Community/private markets are heavily designed but not in the schema.** `docs/design/04-public-and-community-markets.md` specifies `Group`, `Membership`, and `Invite` tables; `docs/design/01-information-architecture.md` shows a community hub. The DB has no `groups`, `memberships`, or `visibility` column on `markets` (`db/structure.sql` — 19 tables listed, none community-related). This is a significant design investment aimed at a roadmap horizon that is years away from the current state — it risks distracting sequencing decisions. | `db/structure.sql` — no group/membership/visibility columns. `docs/design/04-public-and-community-markets.md:1-40` — full model specified. `docs/wiki/UX_BACKLOG.md:48` — UX-033 "deferred — future ADR + spec required". | Label community features explicitly as Phase 2 / post-MVP in the backlog. Remove community wireframes from the "planned UX slices" framing so sprint planning does not treat them as near-term. Prioritise completing the single-player engagement loop first. |
| P2 | **CLOB cashout sell-order UX is invisible.** `Clob::ClobCashoutService` exists (PR #36) and posts a sell limit order, but there is no UI to view open CLOB orders or cancel them (UX-010, UX-035 — blocked). Players who post a sell order have no visible record of the order on the positions page, no cancellation control, and no price-visibility of the pending exit. This makes CLOB effectively illiquid from a player perspective despite the technical implementation being complete. | `app/views/web/positions/index.html.erb` — CLOB section shows net contract count but no open-order list. `docs/wiki/UX_BACKLOG.md:25` — UX-010 "blocked (needs design decision on cancel endpoint)". `app/controllers/web/orders_controller.rb` — `DELETE /web/orders/:id` exists as a route. | The cancel endpoint already exists. Unblock UX-010 and UX-035 by building the open-orders list with a per-row cancel button on the market detail page or positions page. This is a view-only addition with one existing destroy action. |
| P2 | **Leaderboard computation is per-request and un-cached.** The leaderboard spec (F-007, `docs/product/BACKLOG.md:FR-7`) called for a cached/pre-computed leaderboard refreshed on a schedule. The current implementation runs a full `LedgerEntry` GROUP BY on every page load. As the ledger grows (every trade writes ledger entries), this will become expensive. | `app/controllers/web/leaderboard_controller.rb:30-42` — live SQL aggregation, no cache. `docs/product/BACKLOG.md:232` — FR-7 calls for 15-minute background recalculation. | Add a `Rails.cache.fetch('leaderboard', expires_in: 15.minutes)` wrapper around the query, or use a materialized view / denormalized `leaderboard_snapshots` table. This is a P2 performance concern that should be addressed before scaling beyond a few hundred users. |
| P3 | **Four market mechanisms reduce demo clarity.** For a POC, presenting four distinct mechanisms (fixed-odds, CLOB, LMSR, parimutuel) simultaneously without a clear recommended path creates cognitive overload for first-time demo audiences and internal stakeholders. Polymarket runs CLOB-only; Kalshi runs fixed-price/CLOB depending on the product. The strategy question — which mechanism is Adivento's primary bet? — is unanswered in any product document. | `docs/product/BACKLOG.md:1-6` — backlog says "fixed-odds model intentionally preserved" but ADR-0014 made CLOB the default. `docs/wiki/market-mechanisms.md:85` — mechanism comparison table has no "recommended" designation. | Write a product positioning note (not an ADR — this is a strategic choice, not an architecture decision) that picks a primary mechanism for the demo narrative. Suggested: CLOB for the sophisticated audience (Polymarket parity), fixed-odds as the "casual" entry point. The other two mechanisms can be documented as available but not featured in the demo flow. |
| P3 | **Native mobile app is in design scope but not in any implementation plan.** `docs/design/00-design-brief.md:11` lists "Native mobile app" as an audience surface. `docs/design/02-flows-and-use-cases.md:43-45` includes full mobile wireframes (bottom tabs, persistent bet sheet). No Rails mobile adapter, React Native project, or API changes for mobile token refresh appear anywhere in the codebase or plans. | `docs/design/02-flows-and-use-cases.md:43` — "10–13. Native mobile app" section. `db/structure.sql` — no device token or push notification tables. `docs/wiki/UX_BACKLOG.md` — UX-034 "deferred — blocked by community features". | Explicitly defer native mobile to Phase 3 in the roadmap and remove it from current sprint planning scope. Ensure the web `/web/` responsive CSS is treated as the mobile delivery vehicle for Phase 1. |

---

## Detailed Notes

### On competitive positioning vs Polymarket / Kalshi

Polymarket and Kalshi converge on a set of must-have features for credibility:
1. **Probability-forward display** — Adivento has this (price panels per mechanism).
2. **Price history chart** — Kalshi and Polymarket both feature this prominently. Adivento collects the data (`PriceSnapshot`) but surfaces none of it. This is the single highest-gap feature visible to a first-time demo viewer.
3. **Resolution criteria + source on every market** — partially done (fields exist and display) but resolution notes are not persisted from the settle form.
4. **Self-service registration** — Kalshi/Polymarket both have it. Adivento does not have a web UI register form. The current sign-in page explicitly says "use one of the seeded users," which is not acceptable for a demo to any non-technical audience.
5. **Leaderboard** — done (F-007/F-015), competitive parity achieved.
6. **Market taxonomy and search** — done (F-001/F-002), competitive parity achieved.

Manifold-style platforms (play-money, AMM-first) add social features (market creation by any user, comments, community signals) that Adivento does not address and should not try to match in the current phase.

### On backlog priority ordering

The existing backlog (`docs/product/BACKLOG.md`) was written before the CLOB mechanism was implemented (the document states "fixed-odds house underwriting model is intentionally preserved; these features assume no architectural shift to CLOB"). It is now stale as a priority reference. The relevant priorities for the current state are:

1. **Data integrity first (P0):** CLOB double-pay at settlement (TD-018) must be fixed before any CLOB market is used in a demo. This is not in the upcoming UX sprint sequence.
2. **Onboarding/registration (P0/P1):** Without a web register form, no demo can be self-service.
3. **Price history chart (P1):** The data exists — deliver the endpoint and a minimal SVG chart to close the most visible competitor gap.
4. **Profile cross-mechanism P&L (P1):** The profile page is the primary retention surface — it currently lies for CLOB/LMSR/parimutuel players.
5. **Resolution note persistence (P1):** Low-effort schema + service change that closes a significant trust gap.
6. **UX polish PRs A-D (P2):** Correct sequencing — do these after the P0/P1 data and onboarding fixes.
7. **Community/private markets (P3):** Correctly deferred. Do not let this distract near-term sequencing.

### On sequencing errors

**Wrong order found:**

The four planned UX PRs (A: market browse, B: leaderboard/profile/auth, C: settlement explainer, D: backoffice dashboard) are sequenced to run _after_ the backend next-steps plan (TD-013 through TD-017). This is largely correct. However:

- **UX-023 (registration form) is in PR B**, which is not the first UX sprint. It should be extracted and executed immediately — it is a prerequisite for any user-facing demo, not a polish item.
- **TD-018/TD-019 (CLOB settlement double-pay and sell-order contract reservation)** are not in the current backend next-steps plan (`2026-05-29-backend-next-steps.md`) — they are listed as TD-018/TD-019 in `docs/wiki/tech-debt-backlog.md` but with no plan file. These are data-correctness bugs that should precede any public CLOB market, and they are absent from the near-term execution queue.
- The UX PR A plan (`2026-05-29-ux-market-browse-detail.md`) adds `@price_history = []` as a stub rather than connecting to the existing `PriceSnapshot` data. This is an intentional deferral that should be flagged: F-004 (price history) has a Higher priority in the original backlog than most UX polish items, yet the plan explicitly defers it.

### On over-building relative to value

**Four market mechanisms for a POC is ambitious but defensible** — the architecture seams are clean (ADR-0013) and the pluggable model is a genuine differentiator versus single-mechanism competitors. However, the completeness parity across mechanisms is uneven: fixed-odds and parimutuel have cashout; CLOB has partial cashout (sell orders, no UI for open orders); LMSR has no cashout at all. Before adding more mechanisms or features, completing cashout parity across all four mechanisms would reduce user confusion and improve demo coherence.

**Hot/cold Redis storage** (ADR-0012) is architecturally correct but adds operational complexity that is unlikely to matter until the platform has real load. The SSE stream is a genuine product differentiator (live price updates), but Redis-backed snapshot projection is engineering infrastructure that could have been deferred to Phase 2 without user impact. This is noted as a historical observation — the seams are clean enough that it does not create rework.

**`MarketTemplate` catalog** is implemented but the customer-facing "Create market" flow does not exist yet — only moderators can create markets. If the product vision remains operator-created markets (not community-created), the template catalog is purely operational tooling and correctly scoped. If the vision evolves toward community market creation (as suggested by `docs/design/04-public-and-community-markets.md`), the template catalog will be the right foundation.

---

## Open Questions

1. **Primary mechanism for the demo narrative.** Which of the four mechanisms does the team want to feature as the flagship? The answer should drive which UX flows get polish first. (Hypothesis: CLOB for sophisticated audiences, fixed-odds for casual/regulatory audiences.)

2. **Auto-grant initial ADIV on registration vs. faucet-only.** Should new players receive a small starting balance automatically (e.g., 100 ADIV) to remove the moderator-approval bottleneck during demos? The current faucet flow requires human intervention for every new player.

3. **Is community/private market creation in scope for Phase 1 of the demo?** The design document (`docs/design/04-public-and-community-markets.md`) specifies `Group`/`Membership` tables, but none exist. If the demo audience will include community users, this needs an ADR and a timeline. If not, the community design docs create a misleading scope impression.

4. **Is the backlog document (`docs/product/BACKLOG.md`) the authoritative source?** It was written for a fixed-odds-only product and is now stale. Should it be updated to reflect the four-mechanism reality, or replaced by the tech-debt backlog as the working priority source?

5. **What is the target demo audience?** The product gap priorities look very different for (a) a technical investor demo vs. (b) a regulator/partner demo vs. (c) a real user trial. Registration and trust (resolution notes, price history) matter most for (b) and (c); mechanism depth and CLOB correctness matter most for (a).

---

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|---------------|------|------|--------------|-----------------|
| PROD-001 | Add `GET /web/register` HTML form + POST action using existing `POST /auth/register` flow, with session cookie login on success and a first-run faucet nudge | XS | None | New user can register via browser, receive session cookie, be redirected to faucet request; `GET /signin` shows a "Create account" link |
| PROD-002 | Fix `ClobSettlementHandler` to settle net long position (buy fills minus sell fills) per user — prevents double-payout after sell-order activity | S | TD-018 (already documented) | Test: player buys YES, sells all YES, YES wins — player receives 0 settlement payout; buyer of sell order receives full payout |
| PROD-003 | Spec + implement `GET /web/markets/:id/price_history` JSON endpoint backed by `PriceSnapshot` table; add minimal inline SVG line chart to market show page | M | `PriceSnapshot` model exists | Market detail page shows a price chart with at least 2 data points for any market with recorded snapshots; chart renders for all 4 mechanism types |
| PROD-004 | Add `resolution_note text` and `settled_at datetime` to `markets`; persist `resolution_note` from backoffice and admin API settle forms; display in market Resolution Details panel | S | None (small migration) | Settled market shows resolution note on customer market page; admin API settle requires `resolution_note`; backoffice settle form validates minimum 20 chars |
| PROD-005 | Extend `ProfileController` to compute cross-mechanism P&L from `LedgerEntry` using same `STAKE_TYPES`/`RETURN_TYPES` constants as leaderboard (post TD-015 fix); display on profile stat grid | S | TD-015 fix (CLOB_SELL_CREDIT, LMSR_FEE in constants) | Profile page shows non-zero P&L for a player who has only placed CLOB or LMSR trades; net P&L matches leaderboard value for same player |
| PROD-006 | Add CLOB open orders list to positions page (or market detail page) with per-order cancel button using existing `DELETE /web/orders/:id` route | S | Existing cancel route | Player who posts a sell limit order sees it listed with status + price; "Cancel order" button removes the order and returns reserved funds |
| PROD-007 | Auto-grant 100 ADIV to new registrations via ledger credit (new `REGISTRATION_BONUS` entry type) to remove moderator-approval bottleneck during demo | XS | PROD-001 (registration flow) | Newly registered user has 100 ADIV balance without faucet approval; ledger shows `REGISTRATION_BONUS` credit |
| PROD-008 | Cache leaderboard query result for 15 minutes using `Rails.cache.fetch`; display "Last updated X min ago" timestamp on leaderboard page | XS | None | Leaderboard page renders in < 100ms on repeat loads; timestamp displays elapsed time since last cache fill |
| PROD-009 | Write product positioning note (markdown, not ADR) declaring primary mechanism, demo flow, and which features are Phase 1 vs Phase 2 (community, mobile) — remove ambiguity from roadmap | XS | None | Exists at `docs/wiki/product-positioning.md`; references which UX PRs unblock the demo and what the community/mobile timeline is |
| PROD-010 | Fix CLOB sell-order contract reservation to prevent oversell: check `net_position - open_sell_orders` in `validate_sell_position!`; add sequence test for duplicate sell listings | S | TD-019 (documented) | Test: player with 10 contracts cannot place 2 open sell orders for 10 contracts each; second order rejected with "insufficient contracts" error |
