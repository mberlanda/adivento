# 00 · Design Brief

## Product in one line
Adivento is a fantasy prediction-market platform: users bet **ADIV** play-money on **binary** outcomes across four market mechanisms, with manual/admin resolution and an append-only ledger.

## Audience & surfaces
| Surface | Route | Auth | Audience |
|---------|-------|------|----------|
| Customer web (desktop + mobile web) | `/web` | session (optional) | guests + players |
| Native mobile app | — (new) | session/token | players |
| Backoffice / operator console | `/backoffice` | session (moderator+) | operators |
| Admin JSON API | `/admin` | JWT | internal/CI |

## Actors
- **Guest** — browse public markets, view prices.
- **Player** — register, faucet top-up, bet, positions, cashout, profile.
- **Moderator/Operator** — create/open/settle markets, review faucet requests.
- **Community roles** (per group) — Owner, Admin, Resolver, Member, Read-only.

## Design principles
1. **Probability-forward.** The current YES/NO chance is the loudest element on every market surface (Polymarket/Kalshi benchmark).
2. **Decision support.** Price history + volume/liquidity/holders stats sit next to the bet action, not buried.
3. **Mechanism honesty.** Each of the four mechanisms gets a bet UI that matches its mechanics (stake / order book / share-buy / pool) instead of a one-size form.
4. **Trust by transparency.** Resolution criteria, source, settlement math, and the append-only ledger are always one tap away.
5. **Iterate from what exists.** Evolve the current `/web` and `/backoffice` styling rather than rebrand from zero.

## Existing design-system DNA (extracted from the repo)
**Customer web** (`app/views/layouts/application.html.erb`):
```
--bg:#f6f4ec  (warm cream)      --panel:#ffffff
--ink:#18252f (dark slate)      --accent:#0e7c66 (teal)
--muted:#5f6f79                 --border:#d9e2df
radial mint gradient · 16px rounded cards · pills · stat-cards · balance chip
```
**Backoffice** (`app/views/layouts/backoffice.html.erb`):
```
--bg:#11171d  --panel:#182129   --ink:#ecf4f6
--accent:#f0bc5c (gold)         --muted:#9fb2b8
dark gradient · sidebar + data tables
```

## The two theme directions (decided in PR 3)
Both descend from the DNA above and will ship as a **toggle with predefined CSS classes** so screens can be styled by class, not bespoke markup.

- **Theme A — "Playful Fantasy"** — evolves cream + teal. Friendlier, rounder, social, game-like. Customer-leaning.
- **Theme B — "Serious Terminal"** — evolves dark + gold. Denser, sharper, data-forward, pro/operator-leaning.

The wireframes are intentionally grayscale — they lock **layout, hierarchy and flow** before either theme is applied.
