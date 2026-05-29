# UX Research / IA Deep Review

**Reviewer:** UX Research / Information Architecture specialist  
**Date:** 2026-05-29  
**Worktree:** `/private/tmp/adivento-specialist-reviews`  
**Scope date:** Codebase as of commit `8a67f3c` (PR #36 — CLOB sell orders + operator buyback)

---

## Scope

### Files/docs inspected

| Category | Files |
|----------|-------|
| Design docs | `docs/design/00-design-brief.md`, `01-information-architecture.md`, `02-flows-and-use-cases.md`, `03-settlement-and-resolution.md`, `04-public-and-community-markets.md` |
| UX Backlog | `docs/wiki/UX_BACKLOG.md` |
| Specs | `docs/specs/ITERATION_005_UI_E2E_SPEC.md` |
| Plans | `docs/superpowers/plans/2026-05-29-ux-market-browse-detail.md`, `…-ux-settlement-explainer-page.md`, `…-ux-leaderboard-profile-auth.md`, `…-ux-backoffice-dashboard-settle.md` |
| Routes | `config/routes.rb` |
| Layouts | `app/views/layouts/application.html.erb`, `app/views/layouts/backoffice.html.erb` |
| Customer web views | `app/views/web/markets/index.html.erb`, `show.html.erb`; `profile/show.html.erb`; `leaderboard/index.html.erb`; `positions/index.html.erb`; `sessions/new.html.erb`; `betslip_executions/show.html.erb` |
| Backoffice views | `app/views/backoffice/dashboard/index.html.erb`; `markets/index.html.erb`, `show.html.erb`; `faucet_requests/index.html.erb` |
| Controllers | `app/controllers/web/markets_controller.rb`, `profile_controller.rb`, `sessions_controller.rb`, `positions_controller.rb`, `leaderboard_controller.rb`, `bets_controller.rb`, `orders_controller.rb`, `lmsr_trades_controller.rb`, `faucet_requests_controller.rb` |
| Backoffice controllers | `backoffice/markets_controller.rb`, `dashboard_controller.rb` |
| Auth | `app/controllers/concerns/authentication.rb` |
| Models | `app/models/market_leg.rb`, `wallet.rb`, `faucet_request.rb`, `lmsr_position.rb` |
| Docs | `docs/WALLET_LEDGER_DESING.md` (denomination), `docs/INDEX.md` |

### Explicitly out of scope

- Visual styling and colour palette (separate UI design report)
- Native mobile app (not yet implemented)
- Community/Groups feature (UX-033 — deferred)
- Backend service correctness, test coverage, performance
- Admin JSON API (`/admin` namespace) — operator-internal

---

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|
| **P0** | LMSR positions are invisible on the Positions page — players who trade LMSR shares see no record of their open exposure after navigating away from the market | `app/controllers/web/positions_controller.rb:4` queries only `Bet` table; `LmsrPosition` model exists (`app/models/lmsr_position.rb`) but is never read by this controller or view | Extend `PositionsController#index` to query `LmsrPosition` and render a third section in `positions/index.html.erb` |
| **P0** | No web registration form exists — the only sign-in page (`/signin`) has no "Create account" link and the `POST /auth/register` endpoint is a JSON-only API call; a new player cannot self-serve register via the browser | `config/routes.rb:69` (`/auth/register` JSON-only); `app/views/web/sessions/new.html.erb:2` contains "Use one of the seeded users" guidance text — an internal development cue leaked to end users; no `GET /register` route exists | Implement `GET /register` + `POST /register` (session-cookie form), link from sign-in page, and add first-run faucet nudge (UX-023/024) |
| **P0** | Settlement explainer page (`/web/settlement`) does not exist but is referenced nowhere — resolved markets show a "Settled outcome" badge and a closed-market banner with no explanation of how payouts were calculated or how to dispute | `config/routes.rb` — no `/web/settlement` route; `app/views/web/markets/show.html.erb:246` shows settled outcome in a plain `<div>` with no link; design spec `docs/design/03-settlement-and-resolution.md` requires this page and the acceptance criteria are unmet | Execute plan `docs/superpowers/plans/2026-05-29-ux-settlement-explainer-page.md` (UX-025/026) |
| **P1** | Fixed-odds market cards and price panels display `odds_minor / 100` labelled simultaneously as both `%` (probability) and `¢` (price in cents) — for example, `5000 / 100 = 50` becomes "50% / 50¢" on the same card — eroding numerical trust for new users who cannot tell which unit system is in play | `app/views/web/markets/show.html.erb:46–47`: `<div>50%</div>` immediately followed by `<div class="muted">50¢</div>` for the same `leg.odds_minor` value; `docs/WALLET_LEDGER_DESING.md:73` defines "1 point = 100 minor units" confirming the duality | Add a tooltip or label distinguishing "50% implied probability" from "50¢ contract price"; remove the redundant ¢ sub-label or clarify its meaning |
| **P1** | Cashout is exposed only as a JSON API — there is no HTML form or button for a player to initiate cashout from the Positions page; the `POST /web/positions/cashout_quotes` and `cashout_execute` actions return JSON only and are not linked from any view | `app/views/web/positions/index.html.erb` — no cashout button or form; `app/controllers/web/positions_controller.rb:15–38` — both cashout actions render JSON responses only | Add an HTML cashout flow to `positions/index.html.erb` for fixed-odds/parimutuel bets: quote step (show net payout) → confirm button → execute |
| **P1** | The backoffice "Settle market" action is guarded only by a `data-confirm` browser dialog, not a two-step form with payout preview — operators can accidentally trigger an irreversible settlement with one mis-click | `app/views/backoffice/markets/show.html.erb:87–89`: `data: { confirm: "This will settle all bets. Proceed?" }` on the submit button; design spec `docs/design/02-flows-and-use-cases.md:§17` requires a "read-only bets ledger + two-step confirm destructive guard" | Implement the two-step confirmation UI described in plan `2026-05-29-ux-backoffice-dashboard-settle.md` (UX-030) |
| **P1** | The market browse page has no mechanism filter, no status filter, and no sort control — players must paginate through all markets to find a CLOB or LMSR market; mechanism type is only a text badge at the bottom of a card | `app/views/web/markets/index.html.erb:17–25` shows only category pills; `app/controllers/web/markets_controller.rb` ignores `mechanism`, `status`, and `sort` query params; design spec `docs/design/02-flows-and-use-cases.md:§1` lists these as required | Execute `docs/superpowers/plans/2026-05-29-ux-market-browse-detail.md` Task 1 (UX-001) |
| **P1** | The "About this market" panel on every market detail page exposes a raw SSE developer endpoint (`/sse/markets/:id`) as a clickable link visible to end users — this erodes trust by surfacing internal infrastructure | `app/views/web/markets/show.html.erb:293`: `Live SSE stream: <a href="/sse/markets/<%= @market.id %>">…</a>` is rendered unconditionally in the public trust panel | Remove this link from the customer-facing panel; move it to a dev toolbar or behind an admin flag |
| **P2** | The faucet request form on the profile page uses the label "Amount (ADIV)" but the field name is `amount_minor` and the default value is `10000` — which at 100 minor = 1 ADIV means the user appears to be requesting 10,000 ADIV but is actually requesting 100 ADIV; the mismatch will cause confusion when the approved amount appears in the wallet | `app/views/web/profile/show.html.erb:22–23`: `<label>Amount (ADIV)` with `value="10000"`; `docs/WALLET_LEDGER_DESING.md:73` confirms "1 point = 100 minor units"; the backoffice table correctly labels the column "Amount (minor)" (`backoffice/faucet_requests/index.html.erb:11`) | Either show the amount in ADIV-points (divide by 100) or relabel the form field to "Amount (minor units)" with a help note explaining the conversion |
| **P2** | Profile page does not show an open-positions summary card or a link to Positions — users have to know the "Positions" nav item exists; there is also no pending-faucet-request status banner, so users do not know whether their token request was received | `app/views/web/profile/show.html.erb` — no link to `web_positions_path`; no pending status check; UX-019/021 in backlog | Add a "Your open positions (N)" card linking to `/web/positions` and a "Pending faucet request" banner when a pending request exists (UX-019/021) |
| **P2** | Leaderboard does not highlight the current user's own row — a signed-in player cannot find themselves in the table at a glance, which undermines the social ranking purpose | `app/views/web/leaderboard/index.html.erb:26`: `<tr>` has no conditional style; `current_user` is available via `attach_current_user` (`leaderboard_controller.rb:4–10`) | Add `style="background:#ecf7f3;"` (or a `.row-self` class) when `entry.user_id == current_user&.id` (UX-015) |
| **P2** | Positions page shows only "Fixed-Odds & Parimutuel Bets" and "CLOB Positions" — LMSR positions are silently absent despite the `lmsr_positions` table being populated by every LMSR trade | `app/controllers/web/positions_controller.rb:4` — only queries `Bet`; `app/models/lmsr_position.rb` exists and `Market#lmsr_positions` association is defined; `app/views/web/positions/index.html.erb` has no LMSR section | Add a third table "LMSR Share Positions" that queries `LmsrPosition.where(user_id: current_user.id)` and displays market, YES/NO shares, and estimated value |
| **P2** | The Backoffice dashboard is three lines of plain text with no visual hierarchy, no stat boxes, no attention queue, and no inline faucet-request card — operators cannot tell at a glance what needs action | `app/views/backoffice/dashboard/index.html.erb:1–6`: raw `<p>` tags; UX-027/028/029 in backlog; design spec `docs/design/02-flows-and-use-cases.md:§14` describes "mission control" with house liability, pending faucets, markets needing attention | Execute plan `docs/superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md` |
| **P3** | The faucet request form on the profile page is hidden inside a `<details>` element ("Request more tokens") with no indication of a pending request — users who already submitted cannot tell whether their request was received or is awaiting review | `app/views/web/profile/show.html.erb:18–32`: `<details>` with no pending state check; UX-017/019 in backlog | Replace the collapsible with a standalone card; add a "Pending request" banner when a pending faucet request exists |
| **P3** | Market cards show no closing countdown pulse dot (for live markets) and no sparkline — the browse page reads as a static catalogue rather than a live market feed | `app/views/web/markets/index.html.erb:44–73` — no SSE-driven live dot, no sparkline SVG; design spec `docs/design/02-flows-and-use-cases.md:§1 ①` | Implement per plan UX-001/002 in `2026-05-29-ux-market-browse-detail.md` |
| **P3** | Market detail page is single-column — the bet form scrolls below all context panels instead of sitting in a sticky side rail — users on desktop must scroll to bet after reading resolution criteria | `app/views/web/markets/show.html.erb` — all panels stack vertically; design spec `docs/design/02-flows-and-use-cases.md:§2` specifies a sticky bet rail in right column | Implement two-column layout per UX-003 in `2026-05-29-ux-market-browse-detail.md` |

---

## Detailed Notes

### 1. Information Architecture — overall structure is sound, gaps are execution gaps

The two-surface IA (customer web vs backoffice) is well-designed in `docs/design/01-information-architecture.md` and the routes file faithfully represents it. Navigation on the customer side is complete: Markets, Leaderboard, Positions, Profile, Sign in/out are all present and correctly permission-gated. The backoffice sidebar correctly lists all operator tools.

The principal IA gap is the **missing `/web/settlement` page**: it is the only planned top-level page that has no route, no controller, and no view, yet it is referenced by the market lifecycle design and is the primary trust-building tool for users who receive a payout they did not fully understand. Evidence: `config/routes.rb` (no settlement route), `docs/design/03-settlement-and-resolution.md:38-42` (acceptance criteria all unchecked).

### 2. Registration / Onboarding flow is broken

The sign-in page (`app/views/web/sessions/new.html.erb`) contains dev-guidance text ("Use one of the seeded users or any registered account") that is visible to real users. There is no "Create account" link. The only registration path (`POST /auth/register`) is a JSON API endpoint under the auth namespace — it requires a `Content-Type: application/json` request with a Bearer token flow. A new player arriving at `/signin` from a market detail prompt has no path forward.

This is a P0 because it blocks the core funnel: player discovers market → player needs to sign in to bet → sign-in page has no registration → player is stuck.

The design spec `docs/design/02-flows-and-use-cases.md:§5` explicitly calls for session-cookie register + first-run faucet nudge. The backlog item is UX-023/024, with a plan written at `docs/superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md`.

### 3. LMSR positions invisible — functional trust gap

Players who buy LMSR shares have no HTML view of their open positions. The `LmsrPosition` table is populated on every trade (confirmed in `app/services/lmsr/lmsr_trade_service.rb:75`) but `PositionsController#index` only reads the `Bet` table (`app/controllers/web/positions_controller.rb:4`). The positions view (`app/views/web/positions/index.html.erb`) has no LMSR section. This is a silent data loss from the user's perspective — they traded, their balance changed, and they see nothing under "My Positions".

Hypothesis (not confirmed): parimutuel bets _do_ appear (they go through the `Bet` table) but LMSR trades do not. Fixed-odds bets also appear correctly.

### 4. Odds unit confusion on fixed-odds markets

On the market detail page, the fixed-odds price panel shows both the percentage and the cent denomination of the same computed value (`odds_minor / 100.0`):

```
50%     ← primary display (large, bold)
50¢     ← secondary label (small, muted)
```

These are numerically identical because for a 50/50 market, the implied probability in percent equals the cost per contract in cents. However, users who study prediction markets know that "50¢" means "you pay 50 cents per contract" (a price), while "50%" means "the market says this is 50% likely" (a probability). For less sophisticated users, seeing both with the same number on different lines is confusing rather than clarifying. The problem sharpens when probability deviates significantly from market price (e.g., in a thin CLOB market). Reference: `app/views/web/markets/show.html.erb:46–47`.

### 5. Bet submission — no pre-submission payout preview

For all four mechanism types, the bet form has no payout preview before submission. Users enter a stake and click "Place Bet" to discover the expected payout. The payout only appears in the flash notice after redirect (e.g., `bets_controller.rb:14–16`: "Potential payout: 150 ADIV"). This means users must already know what odds they're getting and mentally compute the payout. The design spec (§2, Bet rail) requires a "payout/fee preview" adjacent to the stake input. This gap is tracked as UX-007 and covered by the browse-detail plan.

### 6. Cashout is API-only — no web UI

The cashout flow (`POST /web/positions/cashout_quotes`, `POST /web/positions/cashout_execute`) is backed by correct services but has no HTML entrypoints. The positions page lists open bets but has no "Cash out" button. Users have to discover and use the API directly to exercise this right. For a POC demo this blocks a complete user journey: place bet → hold position → cashout. The CLOB cashout (`clob_cashout` action) does have an HTML redirect at `positions_controller.rb:51` but requires knowing the `market_id`, `side`, `contracts`, and `price_cents` parameters that are not surfaced in the UI.

### 7. Backoffice settle action — no payout preview, single-click risk

Settlement is irreversible (confirmed in `SettlementService` — it calls `bet.update!(status: ...)` and credits wallets). The current settle UI is a form with a single submit button guarded by a JavaScript `window.confirm()` dialog. The operator sees no count of winning bets, no total ADIV to be credited, no breakdown by mechanism. A mis-selected outcome (e.g., YES instead of NO) goes through with a single confirmation click. Design spec `docs/design/02-flows-and-use-cases.md:§17` explicitly requires a two-step confirm with #winning-bets and total-credit shown before committing. Evidence: `app/views/backoffice/markets/show.html.erb:87–89`.

### 8. Raw SSE endpoint leaked to users

The "About this market" section at the bottom of every market detail page links to `/sse/markets/:id` — the raw Server-Sent Events endpoint that streams JSON bytes. This endpoint is designed for browser-side JavaScript consumption. Clicking it in a browser shows a stream of JSON lines. This is a developer debugging artifact that should not be shown to end users. It appears in `app/views/web/markets/show.html.erb:293` unconditionally, inside the trust panel. Its presence actually erodes trust by making the platform look unfinished.

### 9. Faucet form: unit label mismatch

The profile faucet form uses `name="amount_minor"` (minor units, where 100 minor = 1 ADIV) but the label reads "Amount (ADIV)" and the default value is `10000`. This means a user entering `10000` reads it as "I am requesting 10,000 ADIV" but the system interprets it as 100 ADIV. The backoffice faucet table correctly labels the column "Amount (minor)" but the approved amount lands in the player wallet in the same minor units and is shown as "100,000 ADIV" in the balance chip — a disconnect. This is documented by: `app/views/web/profile/show.html.erb:22–23`, `docs/WALLET_LEDGER_DESING.md:73` ("1 point = 100 minor units"), and `test/fixtures/wallets.yml` (admin: 100,000 minor = 1,000 ADIV-points).

Note: if the product intentionally treats minor units as the primary user-facing denomination (i.e., 1 minor = 1 ADIV for UX purposes), then this finding does not apply — but the label "minor units" in the backoffice view vs. "ADIV" in the customer view is still inconsistent and should be resolved.

### 10. Draft markets visible to authenticated users

Logged-in users can browse draft markets (the controller query skips the status filter for authenticated users: `app/controllers/web/markets_controller.rb:10–13`). This means a moderator who is also registered as a player will see internal draft markets mixed into the public browse view. Whether this is intentional is unclear — the design brief does not describe a "draft visibility for admins" use case. If unintentional, it's a minor trust issue (users see incomplete/placeholder markets).

---

## Open Questions

1. **ADIV denomination**: Is 1 minor unit = 1 ADIV (the balance chip shows raw minor numbers as ADIV), or is 1 ADIV = 100 minor (per `WALLET_LEDGER_DESING.md`)? If the former, the faucet label bug does not exist; if the latter, the label mismatch is a real user-facing confound. The backoffice and customer surfaces use different labels for the same field, which suggests this has not been decided explicitly for the UI layer.

2. **Draft market visibility to logged-in users**: Intentional (moderators need to preview their work on the customer site) or accidental? If intentional, it should be accompanied by a "Draft — not published" banner.

3. **LMSR positions cashout path**: The design spec notes LMSR cashout payout is not yet implemented (TD-001 "per-position settlement payout still pending"). Should the Positions page show LMSR open exposure even though there is no cashout action for it, or should it remain hidden until the full cashout path exists? Showing it without a cashout action is better than hiding it (users know their money is at stake).

4. **Betslip multi-bet flow**: The betslip quote/execute API is fully implemented (`POST /web/betslips/quotes`, `POST /web/betslips/execute`) and the confirmation page exists (`betslip_executions/show.html.erb`). However, there is no HTML form that posts to `/web/betslips/quotes`. Is the betslip flow intended only for API clients (native mobile app) while the web uses quick-bet forms? If so, the confirmation page at `web/betslips/executions/:id` is unreachable via normal web navigation.

---

## Backlog Candidates

Items below either supplement the existing UX_BACKLOG.md or surface new findings not yet tracked.

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|--------------|------|------|--------------|-----------------|
| UX-NEW-01 | Add LMSR share positions section to Positions page | S | `LmsrPosition` model (exists) | Signed-in user who placed LMSR trade sees their YES/NO shares, market name, and estimated value on `/web/positions` |
| UX-NEW-02 | Add HTML register form at `GET /register` with session-cookie flow | M | Auth concern supports session auth | User can register via browser form; after register, sees faucet nudge; `/signin` page has "Create account" link |
| UX-NEW-03 | Remove raw SSE link from customer-facing "About this market" panel | XS | None | `/web/markets/:id` renders no SSE URL for any user; developer reference moved to admin-only view or removed |
| UX-NEW-04 | Clarify ADIV denomination in UI (pick one: show ADIV-points or minor units, not both) | S | Product decision on denomination | Balance chip, profile stats, faucet form, betslip confirmation, and positions all use the same unit label consistently |
| UX-NEW-05 | Cashout HTML UI on Positions page (fixed-odds / parimutuel) | M | `CashoutQuoteService`, `CashoutExecutionService` (both exist) | Player sees "Cash out" button per open bet; quotes step shows net payout; confirm executes; redirects with success notice |
| UX-NEW-06 | Add payout preview to quick-bet form (all mechanisms) | M | Existing pricing services | Stake input triggers JS calculation showing estimated payout before submit (or calls quote API inline) |
| UX-NEW-07 | Pending faucet request status banner on profile | XS | `FaucetRequest.pending` query | Player with a pending faucet request sees "Request pending (10,000 ADIV) — awaiting admin review" on profile page |
| UX-NEW-08 | Highlight current user row on leaderboard | XS | `current_user` already available in view | Signed-in user's own row has a distinct background; no regression for guests |
| UX-NEW-09 | Remove dev-guidance text from sign-in page | XS | None | `/signin` page does not mention seeded users; contains only "Sign in to your account" heading |
| UX-NEW-10 | Draft market banner for authenticated players browsing draft markets | XS | Product decision on draft visibility | Draft market cards show a "Draft — not published" badge so players do not mistake them for active markets |
