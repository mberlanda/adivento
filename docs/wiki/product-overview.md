# Adivento — Product Overview

Adivento is a fantasy prediction-market platform. Users bet ADIV coins (a fictional currency) on binary outcomes. There is no real money. The operator acts as house underwriter (fixed-odds) or provides initial liquidity (LMSR/CLOB), depending on the market mechanism chosen.

---

## Actors

| Role | What they can do |
|------|-----------------|
| **Guest** | Browse open/settled markets, view prices |
| **Player** | All guest rights + register, deposit via faucet, bet, view profile/positions, cashout |
| **Moderator** | All player rights + create markets, open/settle markets, review faucet requests |
| **Admin** | All moderator rights + full JSON API access, void bets, manage grants |

Authorization: deny grant > allow grant > role permission > implicit deny. This lets a specific player be blocked from an action their role would normally allow.

---

## Market lifecycle

```
draft → open → settled
              ↑ (no reopening)
```

- **Draft**: created, not yet accepting bets. Legs must be set, mechanism configured.
- **Open**: accepting bets. Prices displayed per mechanism. SSE stream active.
- **Settled**: winning outcome declared. Payouts credited. No more bets.

Every market has exactly two legs: `YES`/`NO` (or `UP`/`DOWN`, `TEAM_A`/`TEAM_B`). This binary invariant is enforced at DB level via a PostgreSQL trigger.

---

## ADIV wallet

- Fantasy currency. 1 ADIV = 100 ADIV-cents (minor units).
- New players start with 0 ADIV. They request a faucet top-up; a moderator approves it.
- Every debit/credit is recorded in the append-only `ledger_entries` table.
- Balance is the running sum of ledger entries; no separate balance column.

---

## Bet placement rules

1. Player places a bet: picks a side (YES/NO), enters stake.
2. Service deducts stake from wallet (ledger debit).
3. Service checks the market's **liability cap**: worst-case payout across all legs cannot exceed `liability_cap_minor`. Bet rejected if it would breach this cap.
4. On settlement: winning bets receive payout (ledger credit), losing bets receive nothing.

Void: a bet can be voided before settlement, which refunds the stake via ledger credit.

---

## Betslip (multi-bet)

Players can place multiple bets across different markets in one transaction:
- Quote: system locks prices and checks all bets can be placed.
- Execute: all-or-nothing. If any bet fails, none are placed.
- Cashout: a player can close an open position before settlement for a partial payout.

---

## Market templates

Templates are operator-defined presets (stored in `MarketTemplateCatalog`):
- `binary_yes_no` — generic YES/NO, 24 h default
- `sports_winner` — TEAM_A / TEAM_B, 12 h default
- `macro_direction` — UP / DOWN, 48 h default

From the backoffice, a moderator picks a template to prefill a market creation form. They can override any field.

---

## Platform surfaces

| Surface | URL prefix | Auth | Audience |
|---------|-----------|------|---------|
| Customer web | `/web/` | Session cookie (optional) | Players + guests |
| Backoffice | `/backoffice/` | Session cookie (moderator+) | Operators |
| Admin JSON API | `/admin/` | JWT Bearer | Internal / CI |
| Auth | `/` (`/register`, `/login`, `/me`) | — | All |

---

## Real-time

Markets emit SSE events at `GET /sse/markets/:id`. Payload is a full market snapshot (prices, volume, status). The client receives a snapshot first, then incremental updates as trades happen. Redis stores the hot snapshot; PostgreSQL is the source of truth. If Redis is unavailable, the SSE controller falls back to a cold DB read.
