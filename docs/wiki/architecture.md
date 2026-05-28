# Architecture Reference

Summary of the major architectural decisions. For full rationale, read the ADRs in `docs/adr/`.

---

## System topology

```
Browser (Customer web)          Browser (Backoffice)
       │                               │
       ▼                               ▼
  Rails 8 monolith (/web/)      Rails 8 monolith (/backoffice/)
       │                               │
       └───────────────┬───────────────┘
                       │
               PostgreSQL (primary store)
               Redis (hot snapshot + SSE channel)
```

External callers (CI, integrations) use the `/admin/` JSON API with JWT.

---

## Key constraints

**One DB, no microservices yet.** The codebase has modular seams (`app/domain/`, service objects, context boundaries) so that individual modules can be extracted later. No external message bus in v1.

**Rails 8 + Zeitwerk.** `app/domain/` is a Zeitwerk autoload root. Files must define constants matching their path (e.g. `app/domain/catalogs/action_catalog.rb` → `Catalogs::ActionCatalog`). No `module Domain` wrapper.

**Ledger-first wallet.** Balance is always derived from `ledger_entries`. There is no mutable balance column. This gives a complete audit trail for every credit/debit.

**Redis is optional.** All reads fall back to PostgreSQL if Redis is unavailable. Redis stores: market hot snapshots (SSE), session data.

---

## Context boundaries (ADR-0008)

| Context | Owns | Talks to |
|---------|------|---------|
| Access Control | Users, roles, permissions, grants | — |
| Markets | Market, MarketLeg, MarketTemplate | Settlement, Wallet |
| Wallet/Ledger | Wallet, LedgerEntry, AuditEvent | — |
| Settlement | SettlementService, mechanism handlers | Markets, Wallet |
| Web Customer | Web:: controllers, views | All |
| Web Backoffice | Backoffice:: controllers, views | All |
| Realtime | SSE controller, MarketSnapshotProjector | Markets, Redis |

---

## Service layer

All business logic lives in service objects under `app/services/`. Controllers are thin — they validate params, call a service, and render the result.

Key services:
- `BetPlacementService` — stake deduction, liability check, ledger debit
- `SettlementService` — routes to mechanism-specific handler, credits winners
- `BetslipQuoteService` / `BetslipExecutionService` — multi-bet quote-execute pattern
- `CashoutQuoteService` / `CashoutExecutionService` — position close
- `HouseRiskService` — worst-case liability across legs
- `MarketSnapshotProjector` — builds and writes Redis hot snapshot

---

## Hot/cold storage (ADR-0012)

- **Hot path**: Redis key `market_snapshot:{id}` — JSON blob with prices, volume, last trade price. Written by `MarketSnapshotProjector` after every trade. Served directly by SSE controller.
- **Cold path**: DB query + projection. Used if Redis misses or errors. `ReconcileMarketHotStateJob` runs periodically to sync drift.
- **SSE protocol**: client opens `GET /sse/markets/:id`. Server sends snapshot event first, then incremental updates as trades happen. `Last-Event-ID` header supported for resume.

---

## Auth

- **Session cookie**: used by `/backoffice/` and `/web/` for browser flows.
- **JWT Bearer**: used by `/admin/` JSON API. Token issued at login. Claims: `user_id`, `role`, `jti` (for future revocation).
- Web controllers accept JWT too (Bearer header bypasses CSRF) — this allows E2E API-driven setup.

---

## CLOB order matching

Price-time priority matching. On order submit:
1. Check `taker_fee_bps` and deduct from stake.
2. Walk opposing side of book looking for matches.
3. For each fill: create fill records, credit maker, deduct from taker.
4. If order type is IOC/FOK and not fully filled: cancel remainder.
5. Write `ORDER_FILL_STAKE` + `ORDER_FILL_CREDIT` ledger entries per fill.
6. Update `markets.last_fill_price_cents`.

---

## E2E testing (Playwright)

Suite lives in `e2e/playwright/`. Runs against the app in production mode via Docker Compose:

```bash
docker compose -f docker-compose.yml -f docker-compose.e2e.yml run --rm playwright
# or
bash scripts/e2e.sh
```

Tests use `mcr.microsoft.com/playwright:v1.54.1-noble`. Production mode (`RAILS_ENV=production`) catches Zeitwerk eager-load issues that development lazy-loading would hide.

Helper pattern: API setup (register players, fund wallets, create markets) then UI assertions. This keeps tests fast and deterministic.
