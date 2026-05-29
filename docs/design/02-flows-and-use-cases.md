# 02 · Flows & Use Cases

Each screen below lists its **purpose**, **key use cases**, and the **numbered design notes** that appear as ① ② … markers on the wireframe frames. Use these as acceptance criteria when implementing.

---

## 1. Discovery / browse (`web/browse`)
**Purpose:** find a market to bet on fast.
**Use cases:** search by question/tag; filter by category/mechanism/status; sort by volume/closing/new; scan implied probability + trend at a glance; paginate (12/page, F-017).
- ① Open markets show a pulsing **live dot** (SSE).
- ② Pagination — 12 per page (matches F-017).
- Cards carry: status/category/mechanism chips, question, YES/NO chance, **sparkline**, 24h volume, closing countdown.

## 2. Market detail + bet (`web/detail`)
**Purpose:** decide and bet with full context.
**Use cases:** read the question + resolution criteria; study **price history** over 1H/6H/1D/1W/ALL; check vol/liquidity/holders; see recent **activity & top holders**; place a bet from a sticky rail; review your own bets.
- ② Price-history chart + decision stats (Polymarket/Kalshi benchmark).
- ③ Guests see "Sign in to bet" in place of the bet form.
- Bet rail: side toggle, stake + quick-add chips, payout/fee preview, place.

## 3. Profile / wallet / faucet (`web/profile`)
**Purpose:** manage balance and review performance.
**Use cases:** see balance + P&L/win-rate/volume; **request a faucet top-up**; filter bet history (all/open/settled); jump to open positions.
- ① Pending faucet request shows a status banner.

## 4. Leaderboard (`web/leaderboard`)
**Purpose:** social ranking.
**Use cases:** see top-3 podium; scan ranked table (net P&L across **all** mechanisms — F-015); find your own row (highlighted).
- ① Top-3 podium feature row.

## 5. Auth / onboarding (`web/auth`)
**Purpose:** sign in / register.
**Use cases:** session-cookie login; register; first-run nudge to request faucet ADIV.
- ① Session-cookie auth (web + backoffice). ② First-run → prompt faucet request after register.

## 6–9. Betting mechanisms (`mech/*`)
The mechanisms diverge most here — each gets a tailored panel.
- **Fixed-odds** ① — single stake, instant payout preview.
- **CLOB** ② — order-book depth ladder (bid/ask/last/spread) + limit-order form (price ¢, qty, GTC/IOC/FOK); open orders + cancel. *(TD-004: cashout = post a sell order.)*
- **LMSR** ③ — share quantity with **price-impact** preview (avg cost, new price), subsidy depth. *(TD-001: per-position settlement payout still pending.)*
- **Parimutuel** ④ — YES/NO pool bars + takeout; payout shown as an **estimate** that shifts as the pool fills.

## 10–13. Native mobile app (`mobile/*`)
**Use cases:** browse with bottom tabs; tap a card → detail; bet from a **persistent bottom sheet** (thumb reachable); manage wallet/positions; view leaderboard.
- ① Tap card → detail. ② Persistent bet sheet, thumb-reachable.

## 14–17. Backoffice (`backoffice/*`)
- **Dashboard** ① — "mission control": open markets, **house liability**, pending faucets, markets needing attention (closed→settle).
- **Create + config** ② — template prefill, mechanism picker with **conditional fee fields** (F-006), exactly-2 legs (DB-enforced), resolution fields, **live preview**.
- **Settle** ③ — read-only bets ledger + **two-step confirm** destructive guard; metadata-only edits once open (DD-007).
- **Faucet review** ④ — approve/reject → ledger credit + audit event.

## 18–21. Stats, settlement & community
- **How settlement works** ① — see `03-settlement-and-resolution.md`. Link from every market's resolution panel + settled banner.
- **Browse · public vs community** ② — scope filter; locked cards for non-members.
- **Community hub** ③ — group page: members, markets, invites, roles.
- **Create · visibility & access** ④ — Public / Community / Invite-only selector; see `04-public-and-community-markets.md`.
