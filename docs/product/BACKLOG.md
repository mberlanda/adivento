# Adivento — Product Feature Backlog

**Last updated:** 2026-05-27
**Status:** Draft — ready for prioritisation
**Reference:** [Kalshi](https://kalshi.com) · [Polymarket](https://polymarket.com) · [docs/prediction-markets-mechanics.md](../prediction-markets-mechanics.md)

---

## Overview

This backlog identifies the functional gaps between Adivento's current fixed-odds POC and the feature set of production prediction market platforms (Kalshi, Polymarket). Features are grouped from highest to lowest impact on platform credibility and user retention.

The fixed-odds house underwriting model is intentionally preserved; these features assume no architectural shift to CLOB. A separate ADR would be required before tackling order-book mechanics.

---

## F-001: Market Taxonomy and Category Browsing

**Priority:** High
**Effort:** M
**Depends on:** none

### Problem

Every market currently appears in a single undifferentiated list. As the number of markets grows beyond a few dozen, customers have no way to navigate to topics they care about — sports, economics, technology, politics — and the homepage becomes unusable. Kalshi and Polymarket organise their 3,500+ markets into top-level topic categories with sub-category drill-down; without equivalent structure, Adivento cannot scale content without degrading discovery.

### Functional requirements

- FR-1: Each market belongs to exactly one category (e.g. Sports, Economics, Politics, Technology, Entertainment, Other).
- FR-2: Moderators can assign a category when creating or editing a market in the backoffice.
- FR-3: The customer market list page shows a horizontal category filter bar. Selecting a category filters the visible market list; selecting "All" resets the filter.
- FR-4: Each market card on the list page displays the category as a badge.
- FR-5: The active category filter is preserved in the URL query string so links are shareable and navigable via browser back-button.
- FR-6: Markets can optionally carry multiple free-text tags (e.g. "NBA", "Fed", "AI"). Tags are separate from the single required category.
- FR-7: Moderators can add or remove tags in the backoffice market form.
- FR-8: Tags are surfaced on the market detail page but are not used as primary browse filters (they feed search, F-002).

### Out of scope (for this spec)

- Hierarchical sub-categories.
- User-defined or community-suggested tags.
- Tag-based recommendation engine.

### Open questions

- Should category be hard-coded as an enum in the DB or driven by a `categories` table? (Enum is simpler; table is more flexible if operators want to add categories without a deploy.)

---

## F-002: Full-Text Market Search

**Priority:** High
**Effort:** S
**Depends on:** F-001 (tags enrich search results)

### Problem

Users who arrive with a specific question in mind — "Will the Fed cut rates?" — have no way to type that and find the relevant market. They must scroll an undifferentiated list. Both Kalshi and Polymarket surface a prominent search bar as the primary discovery mechanism. This is the single highest-friction gap for new users on Adivento.

### Functional requirements

- FR-1: A search input is visible on the customer market list page above the category filter bar.
- FR-2: Search matches against market title, description, category name, and tags. Matching is case-insensitive and tolerates partial word matches.
- FR-3: Search results update without a full page reload (either via Turbo Frame or a lightweight debounced form submission).
- FR-4: When a search query is active, the category filter still applies as an additional constraint (AND logic, not OR).
- FR-5: If no markets match, a "No markets found for X" message is shown with a suggestion to browse all markets.
- FR-6: The search query is reflected in the URL query string for shareability.
- FR-7: Backoffice moderators can also search the market list by title.

### Out of scope (for this spec)

- Fuzzy/semantic search or ranking by relevance score.
- Search autocomplete / type-ahead suggestions.
- Indexing into an external search engine (Elasticsearch, etc.).

### Open questions

- PostgreSQL `ILIKE` with `pg_trgm` index is sufficient for a POC. Should this explicitly use `to_tsvector` full-text from day one for better ranking later?

---

## F-003: Market Detail Page Enrichment

**Priority:** High
**Effort:** M
**Depends on:** F-001 (category/tags displayed), F-004 (price history chart)

### Problem

The current market detail page shows the question title, YES/NO legs, and a bet form. It omits critical information that users need to trade with confidence: what is the authoritative source for resolution? What exact criteria trigger a YES outcome? When does the market close? How much money is at stake? Kalshi and Polymarket publish all of this on the market page; platforms that don't are perceived as opaque or unreliable.

### Functional requirements

- FR-1: The market detail page displays a **resolution criteria** section — a plain-language description of what constitutes a YES outcome, written by the moderator at creation time.
- FR-2: The page displays a **resolution source** field — the authoritative third-party source (e.g. "AP News", "Bureau of Labor Statistics") the moderator will use to determine the outcome.
- FR-3: The page displays the market **close date/time** — the deadline after which no new bets are accepted — formatted in the viewer's local timezone.
- FR-4: The page displays the **total volume** placed on this market (sum of all open bet stakes in ADIV cents), formatted as a human-readable currency amount.
- FR-5: The page displays **open interest** — the count of currently open (unsettled) bets.
- FR-6: If the market status is `settled` or `cancelled`, a banner shows the outcome and settlement date.
- FR-7: The page displays the market **category** and **tags**.
- FR-8: Moderators can fill in resolution criteria, resolution source, and close date fields in the backoffice market creation and edit forms.
- FR-9: The close date, once set, is surfaced on the market list page card as "Closes in X days / hours".

### Out of scope (for this spec)

- Automated enforcement of close date (stopping bet placement when close date passes — that is a separate operations feature).
- Dispute / challenge resolution workflow.

### Open questions

- Should close date be a hard enforcement in `BetPlacementService` or only a display indicator for now?
- Resolution criteria and source: `text` columns on `markets` or a separate `market_metadata` table?

---

## F-004: Price History Tracking and Chart

**Priority:** High
**Effort:** L
**Depends on:** none

### Problem

Adivento shows only the current odds for each leg. Users cannot see how the market has moved over time: was YES at 30¢ yesterday and now at 60¢? Did volume spike? This historical context is the primary signal traders use to gauge momentum, identify overreactions, and time entries. Kalshi and Polymarket both display price history charts prominently on the market detail page. Without it, Adivento looks like a static price sheet, not a market.

### Functional requirements

- FR-1: Every time the odds on a market leg change (via the admin API `PATCH /admin/market_legs/:id`), a `leg_price_snapshot` record is written with `(leg_id, price_cents, volume_at_snapshot, recorded_at)`.
- FR-2: The first snapshot is also written when a leg is created (initial odds baseline).
- FR-3: The market detail page renders a line chart showing each leg's price (as implied probability 0–100%) over time. The x-axis is calendar time; the y-axis is probability.
- FR-4: The chart covers the full lifetime of the market (from creation to now, or to settlement).
- FR-5: On the market list page, each card shows a **sparkline** — a minimal 7-day price chart for the YES leg with no axes or labels — to communicate trend at a glance.
- FR-6: The chart data is served from a dedicated endpoint (e.g. `GET /web/markets/:id/price_history`) returning a JSON array of `{timestamp, yes_price, no_price}` objects.
- FR-7: A **24-hour price change** indicator (absolute and percentage) is displayed on both the market card and the detail page.
- FR-8: The admin API exposes a `GET /admin/markets/:id/price_history` endpoint returning the same snapshot data for operator tooling.

### Out of scope (for this spec)

- Volume-weighted average price (VWAP) calculation — this requires per-bet price tracking at a finer granularity; defer to a follow-on spec.
- Candlestick / OHLC charts.
- Real-time chart updates via SSE/WebSocket (the existing SSE stream can be extended later).

### Open questions

- Snapshot frequency: write one snapshot on every odds change vs. also writing periodic time-series snapshots even when odds are unchanged? (Periodic snapshots give smoother charts but add write overhead.)

---

## F-005: User Profile and Bet History

**Priority:** High
**Effort:** M
**Depends on:** none (bets already exist in the DB)

### Problem

A customer who has placed bets has no way to review their activity: which bets are open, which settled, what they won or lost, what their current P&L is. This absence breaks the core retention loop — users who cannot see their performance have no reason to return and engage. Kalshi and Polymarket both provide a personal portfolio and trade history view as a logged-in-user baseline.

### Functional requirements

- FR-1: A `/web/profile` page is accessible to any authenticated player (session cookie).
- FR-2: The profile page displays the user's current **wallet balance** in ADIV, formatted as a currency amount.
- FR-3: The page shows a **bets table** with columns: Market title, Leg (YES/NO), Stake, Potential payout, Status (open/settled_win/settled_loss/voided/cashed_out), Placed at.
- FR-4: The bets table is filterable by status: All / Open / Won / Lost / Voided.
- FR-5: The page shows a **P&L summary** section with: total staked, total returned, net P&L (returned minus staked), win rate (won bets / (won + lost bets)), and number of open positions.
- FR-6: Won bets are visually highlighted (e.g. green row or badge); lost bets are de-emphasised.
- FR-7: Each row links to the relevant market detail page.
- FR-8: The P&L calculation excludes voided bets from both numerator and denominator.
- FR-9: Cashout-executed bets are shown with their actual cashout payout (not the original potential payout) and status "Cashed out".

### Out of scope (for this spec)

- Public profile pages visible to other users.
- P&L charted over time (requires F-004 dependency for timeline data — defer).
- CSV/tax export.

### Open questions

- Should unauthenticated users who visit `/web/profile` be redirected to the login page or shown a prompt to sign in?

---

## F-006: Market Creation UX Improvements

**Priority:** Medium
**Effort:** M
**Depends on:** F-001 (category/tags), F-003 (resolution criteria, source, close date)

### Problem

The backoffice market creation form is minimal — it collects only the market title and initial odds. Moderators must then separately configure legs and metadata via the admin JSON API. This friction increases the chance of markets being published with incomplete metadata (no resolution criteria, no close date), which undermines user trust. A richer, single-page creation form reduces operational errors and speeds up market publishing.

### Functional requirements

- FR-1: The backoffice "New Market" form includes all fields in a single page: title, description, category (required select), tags (optional, comma-separated), resolution criteria (required text area), resolution source (required text field), close date and time (required datetime picker), initial YES probability (slider 1–99, defaults to 50), and liability cap.
- FR-2: All required fields are validated client-side before submission; server-side validation returns field-specific errors on failure.
- FR-3: The YES leg and NO leg are created automatically from the initial YES probability (NO probability = 100 − YES).
- FR-4: Moderators can **preview** the market as it will appear to customers before confirming creation. The preview is a read-only modal or side panel.
- FR-5: A "Create from template" flow pre-fills the form from a selected template, allowing moderators to override any field before submission.
- FR-6: The backoffice market edit form includes the same enriched fields so moderators can update resolution criteria, close date, and source on draft or open markets.
- FR-7: Required-field validation prevents a market from being moved from `draft` to `open` if resolution criteria or close date are missing.

### Out of scope (for this spec)

- AI-assisted resolution criteria generation.
- Batch market creation.
- Market duplication (copy an existing market as a new draft).

### Open questions

- Should the preview be a server-rendered Turbo Frame or a client-side state toggle? (Turbo Frame is simpler and consistent with the existing stack.)

---

## F-007: Trader Leaderboard

**Priority:** Medium
**Effort:** S
**Depends on:** F-005 (P&L data must exist per user)

### Problem

Prediction markets derive a significant portion of their engagement from social competition. Polymarket's leaderboard is one of its most-visited pages, and Kalshi's analytics dashboard drives daily return visits. A visible leaderboard turns individual P&L tracking (F-005) into a social signal — it shows users where they rank, who is winning, and sets a competitive benchmark. Without it, Adivento is missing a core engagement loop that costs almost nothing to build once per-user P&L is available.

### Functional requirements

- FR-1: A public `/web/leaderboard` page is accessible without authentication.
- FR-2: The leaderboard shows a ranked table of players with columns: Rank, Username, Total P&L (ADIV), Win rate (%), Number of settled bets.
- FR-3: The leaderboard is ranked by net P&L descending by default.
- FR-4: A toggle allows switching the ranking metric between P&L and Win rate.
- FR-5: The table shows the top 50 traders. Pagination or a "load more" control reveals further entries.
- FR-6: An authenticated user's own row is highlighted regardless of their rank, even if they are outside the top 50.
- FR-7: The leaderboard is recalculated on a schedule (e.g. every 15 minutes via a background job), not on every page load, to avoid expensive per-request aggregation.
- FR-8: Each leaderboard row links to the user's public profile if public profiles are enabled (F-008); otherwise the username is non-linked.
- FR-9: The page shows the timestamp of the last recalculation next to the title ("Last updated: X minutes ago").

### Out of scope (for this spec)

- Time-scoped leaderboards (weekly/monthly) — these can be added later using the same P&L aggregation with a `settled_at` date filter.
- Real-time leaderboard updates.
- Category-specific leaderboards.

### Open questions

- Should P&L include cashed-out bets? (Yes — cashout is a legitimate realised gain/loss that should count.)
- Should voided bets be excluded from win rate? (Yes — consistent with F-005 FR-8.)

---

## F-008: Market Watchlist and Notifications

**Priority:** Medium
**Effort:** M
**Depends on:** F-003 (market detail enrichment provides the data worth watching)

### Problem

Users who find a market they care about have no way to track it passively — they must return to the site and navigate back to the market manually. Production platforms (Kalshi mobile app, third-party Polymarket alert services) provide watchlists and price-alert notifications. Even a simple server-side watchlist with email notifications dramatically increases return-visit rates and positions Adivento as an ongoing destination rather than a one-time visit.

### Functional requirements

- FR-1: Authenticated players can add any market to a personal watchlist by clicking a "Watch" button on the market detail page. The button toggles to "Watching" when active.
- FR-2: A `/web/watchlist` page shows all watched markets in a list, with current odds, volume, and status displayed identically to the market list page cards.
- FR-3: Watched markets are highlighted (e.g. star icon) on the main market list page.
- FR-4: When a watched market **settles or is cancelled**, the platform sends an in-app notification: a notification badge appears in the site header and a notification is added to a `/web/notifications` feed.
- FR-5: The notifications feed shows: notification type, market title, brief message ("Market settled — YES won"), and a link to the market detail page.
- FR-6: Notifications are marked as read when the user visits the notifications feed page.
- FR-7: Optionally (stretch): when a watched market's odds move by more than 10 percentage points within 24 hours, a "significant move" notification is generated.

### Out of scope (for this spec)

- Email or push notifications (in-app only for this spec).
- Price threshold alerts (notify me when YES reaches 70¢).
- SMS notifications.

### Open questions

- Notifications storage: a dedicated `notifications` table vs. repurposing `audit_events`? (A dedicated table is cleaner; `audit_events` is intended as an operator audit log.)

---

## F-009: Automated Market Close Enforcement

**Priority:** Medium
**Effort:** S
**Depends on:** F-003 (close date field must exist on markets)

### Problem

Currently, a market with a past close date will still accept new bets — there is no automated enforcement of the close date. Moderators must manually monitor and settle or close markets. In production, markets on Kalshi stop accepting orders automatically at the published close time. The absence of automated enforcement means Adivento's close date field (F-003) is a decorative display element rather than a real trading constraint, which erodes trust.

### Functional requirements

- FR-1: `BetPlacementService` rejects bet placement with an error ("Market is closed for new bets") if the market's `close_at` timestamp is set and is in the past.
- FR-2: A scheduled background job (`CloseExpiredMarketsJob`) runs every 5 minutes and transitions all markets whose `close_at` has passed and whose status is `open` to a new `closed` status.
- FR-3: The `closed` market status means: no new bets accepted, existing open bets remain valid, market is awaiting moderator settlement.
- FR-4: The customer market list and detail pages display a "Closed — awaiting settlement" banner on `closed` markets.
- FR-5: The backoffice market list displays `closed` markets in a dedicated section or with a distinct badge, making them easy for moderators to identify and act on.
- FR-6: The admin API `PATCH /admin/markets/:id` accepts a `close_at` datetime parameter for programmatic close-date management.
- FR-7: If a market has no `close_at` set, no automated close is triggered; the existing manual workflow applies.

### Out of scope (for this spec)

- Automated settlement (determining outcome and paying out) — this requires oracle integration or moderator verification and is out of scope here.
- Re-opening a closed market.

### Open questions

- Should `closed` be a new status value or just a derived state computed from `close_at < now && status == open`? (A real status is more explicit and queryable, but requires a migration and enum change.)

---

## F-010: Resolution Outcome Transparency

**Priority:** Medium
**Effort:** S
**Depends on:** F-003 (resolution criteria and source must exist)

### Problem

When a market settles, customers currently see only the final status change in the market list. They have no record of why YES or NO won — no link to the source, no moderator statement, no timestamp of the determination. On Kalshi every resolved market has a visible resolution note citing the authoritative source. The absence of this on Adivento leaves settled markets feeling opaque, and users who lost bets have no evidence that the outcome was determined fairly.

### Functional requirements

- FR-1: When a moderator settles a market in the backoffice, they must fill in a **resolution note** — a brief plain-language explanation of the outcome (e.g. "BLS reported CPI at 3.2% for March, exceeding the 3.0% threshold. YES resolved.").
- FR-2: The resolution note is stored on the market record alongside `settled_at` timestamp.
- FR-3: The resolution note, resolution source (from F-003), and `settled_at` are displayed in a "Resolution" section on the market detail page for all settled markets.
- FR-4: The admin API `POST /admin/markets/:id/settle` requires a `resolution_note` parameter; missing it returns a 422 with a descriptive error.
- FR-5: The resolution note is visible in the backoffice market detail view alongside the settlement history.
- FR-6: The resolution note field in the backoffice settle form includes a character minimum of 20 characters to discourage empty submissions.

### Out of scope (for this spec)

- User dispute/challenge mechanism.
- Linking to external evidence URLs (this could be added later as an optional `resolution_url` field).
- Moderator attribution (showing which moderator settled the market).

### Open questions

- Should `resolution_note` be mandatory for settlement via the admin API, or only strongly recommended via soft validation? (Mandatory is simpler to enforce and avoids half-settled markets with no explanation.)

---

## F-011: Platform Activity Feed

**Priority:** Low
**Effort:** M
**Depends on:** F-001 (categories), F-004 (price movement data)

### Problem

New users who land on Adivento's homepage see a list of markets but have no sense of what is happening on the platform right now. Production platforms communicate platform vitality through an activity feed: recent trades, newly opened markets, markets about to close. This social proof — seeing that other people are actively trading — is a key driver of first-bet conversion for new visitors.

### Functional requirements

- FR-1: The homepage shows a **Recent Activity** sidebar or section listing the last 20 significant events across all markets.
- FR-2: Activity event types included: new market opened, market settled, and large bet placed (above a configurable stake threshold).
- FR-3: Each activity item shows: event type icon, brief description ("Alice placed a large bet on YES in [Market Title]"), and a relative timestamp ("3 minutes ago").
- FR-4: User identities in the activity feed are anonymised to a truncated username or "a trader" to protect privacy.
- FR-5: Activity feed items are stored in the existing `audit_events` table with a new `feed_visible: boolean` flag; the feed query filters to `feed_visible = true`.
- FR-6: The activity feed is cached for 60 seconds to avoid per-request DB reads; a background job or SSE broadcast refreshes it on new qualifying events.

### Out of scope (for this spec)

- Personalised activity feed (activity from markets the user is watching).
- Real-time streaming of the feed (deferred to when SSE is extended).

### Open questions

- Stake threshold for "large bet" display: fixed value (e.g. 500 ADIV) or a percentage of the market's total volume?

---

## F-012: Responsible Gambling and Deposit Limits

**Priority:** Low
**Effort:** M
**Depends on:** F-005 (user profile must exist for self-assessment context)

### Problem

Adivento uses a fantasy wallet with no real money. However, building responsible gambling controls into the POC now costs little and positions the platform for any future real-money transition. More immediately, if Adivento is ever demo'd to regulators or institutional partners, the absence of any spending-control features is a credibility gap — Kalshi (as a CFTC-licensed exchange) is held to conduct standards, and the design should reflect that.

### Functional requirements

- FR-1: A player can set a **daily stake limit** on their account: a maximum total stake (in ADIV) they are willing to place across all bets in a rolling 24-hour window.
- FR-2: `BetPlacementService` checks the daily stake limit before accepting a bet; if placing the bet would exceed the limit, the service returns an error with the remaining allowance.
- FR-3: A player can set a **cooling-off period** of 24 hours, 7 days, or 30 days. During a cooling-off period, bet placement is blocked and the wallet faucet request flow is disabled.
- FR-4: Once a cooling-off period is activated, it cannot be cancelled or shortened by the player for its full duration. Only an admin can override it.
- FR-5: The profile page (F-005) displays the player's current daily stake limit and any active cooling-off period, with controls to set or modify them.
- FR-6: The backoffice shows a count of users currently in a cooling-off period on the dashboard, for operator monitoring.

### Out of scope (for this spec)

- Loss limits (as opposed to stake limits).
- Mandatory affordability checks.
- Integration with national self-exclusion registers.

### Open questions

- Is a daily limit sufficient, or should weekly/monthly limits be offered from day one? (Daily is simpler; weekly/monthly can be layered on with the same mechanism using different time windows.)

---

## Priority Summary

| Feature | Priority | Effort | Key rationale |
|---------|----------|--------|---------------|
| F-001: Market taxonomy & browsing | High | M | Without categories, discovery breaks at scale |
| F-002: Full-text search | High | S | Highest friction gap for new users |
| F-003: Market detail enrichment | High | M | Resolution criteria and close date are table stakes for trust |
| F-004: Price history and chart | High | L | Core trading context; every competitor has it |
| F-005: User profile and bet history | High | M | Without this, there is no retention loop |
| F-006: Market creation UX | Medium | M | Reduces operator errors; depends on F-001 + F-003 |
| F-007: Trader leaderboard | Medium | S | High engagement ROI; trivial once F-005 exists |
| F-008: Market watchlist and notifications | Medium | M | Return-visit driver; standard on all platforms |
| F-009: Automated market close | Medium | S | Enforces trust in the close date display |
| F-010: Resolution transparency | Medium | S | Fairness signal; critical for user confidence |
| F-011: Platform activity feed | Low | M | Social proof; nice-to-have for cold-start |
| F-012: Responsible gambling controls | Low | M | Regulatory hygiene; important before any real-money work |
