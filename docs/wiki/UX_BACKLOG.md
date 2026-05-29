# UX Backlog

Tracks UX gaps between the wireframe designs (`docs/design/`) and the current Rails views. Each gap maps to an implementable slice.

**Wireframe reference:** `docs/design/wireframes/v1/` (pan/zoom canvas: `Wireframes.html`).
**Design docs:** `docs/design/00-design-brief.md` through `04-public-and-community-markets.md`.

Updated: 2026-05-29.

---

## Gap inventory

| ID | Gap | Surface | Status | Plan |
|----|-----|---------|--------|------|
| UX-001 | Market browse: no mechanism/status filter, no sort control | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-002 | Market cards: no sparkline, no "live" pulse dot, no volume stat | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-003 | Market detail: single-column layout — no sticky bet rail in right column | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-004 | Market detail: no price-history chart (1H/6H/1D/1W/ALL) | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-005 | Market detail: no decision stats row (24h vol, liquidity, holders, trades) | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-006 | Market detail: no quick-add stake chips (+50, +100, +500) | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-007 | Market detail: no payout preview box (potential payout, fee) | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-008 | Market detail: no LMSR price-impact preview (avg cost, new price) | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-009 | Market detail: CLOB panel missing depth ladder (bid/ask levels + visual bars) | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-010 | Market detail: no CLOB open orders list + cancel controls | web | open | blocked (needs design decision on cancel endpoint) |
| UX-011 | Market detail: no recent activity feed (trades/bets by other players) | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-012 | Market detail: parimutuel panel missing visual pool-fill bars | web | open | [plan](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) |
| UX-013 | Leaderboard: no top-3 podium feature row | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-014 | Leaderboard: missing Volume, Win Rate, Bets columns | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-015 | Leaderboard: current user's row not highlighted | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-016 | Profile: no avatar + username + rank header | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-017 | Profile: faucet request buried in `<details>` instead of standalone card | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-018 | Profile: no faucet reason field | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-019 | Profile: no pending-faucet-request status banner | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-020 | Profile: P&L stats not in 4-stat grid (Net P&L, Total bets, Win rate, Volume) | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-021 | Profile: no open-positions summary card with links | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-022 | Positions page: plain table, not using card/stat-grid design system | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-023 | Auth: no register form — only sign-in exists | web | **done 2026-05-30** (= synthesis UX-036): `GET/POST /register`, `Web::RegistrationsController`, "Create an account" link on sign-in | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-024 | Auth: no first-run faucet nudge after registration | web | open | [plan](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) |
| UX-025 | Settlement explainer page (`/web/settlement`) missing entirely | web | open | [plan](../superpowers/plans/2026-05-29-ux-settlement-explainer-page.md) |
| UX-026 | Market resolution panel: no link to settlement explainer | web | open | [plan](../superpowers/plans/2026-05-29-ux-settlement-explainer-page.md) |
| UX-027 | Backoffice dashboard: only 3 text stats — no stat boxes, no attention table | backoffice | open | [plan](../superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md) |
| UX-028 | Backoffice dashboard: no inline faucet-requests card | backoffice | open | [plan](../superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md) |
| UX-029 | Backoffice dashboard: no recent audit events panel | backoffice | open | [plan](../superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md) |
| UX-030 | Backoffice settle: `data-confirm` browser dialog instead of two-step confirmation with payout preview | backoffice | open | [plan](../superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md) |
| UX-031 | Backoffice faucet requests: no status filter tabs (Pending/Approved/Rejected) | backoffice | open | [plan](../superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md) |
| UX-032 | Backoffice faucet requests: no current-balance column, no reason column | backoffice | open | [plan](../superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md) |
| UX-033 | Community features: Groups, Memberships, Invites, community hub, visibility selector | web + backoffice | deferred | future ADR + spec required |
| UX-034 | Mobile-responsive layouts: dedicated mobile bottom-tab nav, persistent bet sheet | web | deferred | blocked by community features |
| UX-035 | CLOB: open orders list + per-order cancel button on market detail page | web | deferred | needs cancel order endpoint design |

---

## PRs sliced from this backlog

| Slice | Gaps covered | Plan | Status |
|-------|-------------|------|--------|
| PR A: Market browse + detail | UX-001–UX-012 | [2026-05-29-ux-market-browse-detail.md](../superpowers/plans/2026-05-29-ux-market-browse-detail.md) | planned |
| PR B: Leaderboard + profile + auth + positions | UX-013–UX-024 | [2026-05-29-ux-leaderboard-profile-auth.md](../superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md) | planned |
| PR C: Settlement explainer page | UX-025–UX-026 | [2026-05-29-ux-settlement-explainer-page.md](../superpowers/plans/2026-05-29-ux-settlement-explainer-page.md) | planned |
| PR D: Backoffice dashboard + settle + faucet | UX-027–UX-032 | [2026-05-29-ux-backoffice-dashboard-settle.md](../superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md) | planned |
| Future: Communities | UX-033 | TBD — ADR + spec first | deferred |
| Future: CLOB open orders + cancel | UX-035 | TBD | deferred |
