# Implementation Plan Checklist

Reference plan: `docs/superpowers/plans/2026-05-27-pluggable-market-mechanisms.md`

Apply the six required changes from the plan review before starting:
- [x] PRE-1: Add `clob?`, `lmsr?`, `parimutuel?`, `fixed_odds?` helpers to Market model
- [x] PRE-2: Add `lmsr_b_parameter` computation on `draft → open` transition
- [x] PRE-3: Implement `Web::OrderBooksController#show`
- [x] PRE-4: Implement `Web::LmsrTradesController` and `Web::ParimutuelBetsController`
- [x] PRE-5: Add `market.open?` guard to `ParimutuelPoolService.add_stake`
- [x] PRE-6: Add `Admin::MarketsController` + `Backoffice::MarketsController` strong params for new fields

---

## Tasks

- [x] Task 1: DB migration — mechanism fee columns + LMSR/parimutuel state columns
- [x] Task 2: Market model — mechanism validations, `pricing_engine` factory, predicates
- [x] Task 3: Order model + migration (CLOB)
- [x] Task 4: `Clob::OrderMatchingService` — price-time priority, partial fills, fee, audit
- [x] Task 5: Admin + web order placement/cancellation endpoints + `Web::OrderBooksController`
- [x] Task 6: `Lmsr::LmsrPricingService` — cost function, marginal cost, `b_from_subsidy`
- [x] Task 7: `Lmsr::LmsrTradeService` — place trade, ledger, audit + `Web::LmsrTradesController`
- [x] Task 8: `Parimutuel::ParimutuelPoolService` — stake, pool update, implied odds + `Web::ParimutuelBetsController`
- [x] Task 9: `Parimutuel::ParimutuelSettlementService` — takeout, pro-rata payout (use ledger entry iteration)
- [x] Task 10: Settlement router — `SettlementService` branches on `mechanism_type`; `ClobSettlementHandler`, `LmsrSettlementHandler`
- [x] Task 11: `PriceSnapshot` model + `RecordPriceSnapshotJob` — mechanism-appropriate snapshot
- [x] Task 12: Hot storage — extend `MarketSnapshotProjector` with mechanism fields
- [x] Task 13: SSE — call projector after each trade/stake in CLOB/LMSR/parimutuel services
- [x] Task 14: Backoffice UI — mechanism picker + conditional fee fields (also update admin strong params)
- [x] Task 15: Web UI — mechanism-appropriate price display on market show page
- [x] Task 16: Full test suite passes at 90% coverage
- [x] Task 17: Update `docs/WORK_LOG.md` + `docs/INDEX.md`
