# 01 · Information Architecture

## Customer web — navigation
Top bar (existing): **Adivento** · Markets · Leaderboard · Positions · My Profile · `balance chip` · Sign in/out.
Add a **visibility scope** control on Markets: `All · 🌐 Public · 👥 My communities` + community picker.

```
/web (Markets index)
├─ search + filters (category, mechanism, status) + sort + scope
├─ /web/markets/:id (Market detail)
│   ├─ price-history chart + decision stats (vol / liquidity / holders)
│   ├─ price panel (per mechanism) + bet rail
│   ├─ activity & top-holders feed
│   ├─ resolution details → links to "How settlement works"
│   └─ your bets
├─ /web/leaderboard
├─ /web/positions  (+ cashout)
├─ /web/profile    (wallet, P&L, faucet request, bet history)
├─ /web/communities/:slug  (NEW — community hub / group page)
├─ /web/settlement (NEW — how settlement works explainer)
└─ /signin · /register
```

## Native mobile app — navigation
Bottom tab bar: **Markets · Search · Positions · Profile**. Market detail uses a persistent, thumb-reachable **bet sheet** anchored above the tab bar. Same flows as web, restructured for one-handed use.

## Backoffice — navigation
Sidebar (existing): Dashboard · Markets · Templates · Faucet Requests · Permissions · Ad-hoc Grants. Add **Communities** + **Disputes** when those ship.

```
/backoffice (Dashboard — exposure, open markets, pending actions)
├─ /backoffice/markets (list)
│   ├─ /new  (create + mechanism config + visibility/access)
│   └─ /:id  (show → open / settle / edit-metadata)
├─ /backoffice/templates
├─ /backoffice/faucet_requests (approve / reject)
├─ /backoffice/permissions · /backoffice/grants
└─ /backoffice/communities · /backoffice/disputes  (future)
```

## Screen inventory (wireframed in PR 1)
| # | Screen | Surface | Frame id |
|---|--------|---------|----------|
| 1 | Discovery / browse | web | `web/browse` |
| 2 | Market detail + bet + chart/stats | web | `web/detail` |
| 3 | Profile / wallet / faucet | web | `web/profile` |
| 4 | Leaderboard | web | `web/leaderboard` |
| 5 | Auth / onboarding | web | `web/auth` |
| 6–9 | Bet panels: fixed-odds, CLOB, LMSR, parimutuel | web | `mech/*` |
| 10–13 | Mobile: markets, detail+sheet, profile, leaderboard | app | `mobile/*` |
| 14–17 | Backoffice: dashboard, create, settle, faucet | backoffice | `backoffice/*` |
| 18 | How settlement works | web | `extra/x-settle` |
| 19 | Browse · public vs community | web | `extra/x-scope` |
| 20 | Community hub (group page) | web | `extra/x-community` |
| 21 | Create · visibility & access | web/bo | `extra/x-visibility` |
