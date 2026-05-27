# Implementation Plan Checklist

Reference plan: `docs/superpowers/plans/2026-05-27-pluggable-market-mechanisms.md`

Apply the six required changes from the plan review before starting:
- [ ] PRE-1: Add `clob?`, `lmsr?`, `parimutuel?`, `fixed_odds?` helpers to Market model
- [ ] PRE-2: Add `lmsr_b_parameter` computation on `draft → open` transition
- [ ] PRE-3: Implement `Web::OrderBooksController#show`
- [ ] PRE-4: Implement `Web::LmsrTradesController` and `Web::ParimutuelBetsController`
- [ ] PRE-5: Add `market.open?` guard to `ParimutuelPoolService.add_stake`
- [ ] PRE-6: Add `Admin::MarketsController` + `Backoffice::MarketsController` strong params for new fields

---

## Tasks

- [ ] Task 1: DB migration — mechanism fee columns + LMSR/parimutuel state columns
- [ ] Task 2: Market model — mechanism validations, `pricing_engine` factory, predicates
- [ ] Task 3: Order model + migration (CLOB)
- [ ] Task 4: `Clob::OrderMatchingService` — price-time priority, partial fills, fee, audit
- [ ] Task 5: Admin + web order placement/cancellation endpoints + `Web::OrderBooksController`
- [ ] Task 6: `Lmsr::LmsrPricingService` — cost function, marginal cost, `b_from_subsidy`
- [ ] Task 7: `Lmsr::LmsrTradeService` — place trade, ledger, audit + `Web::LmsrTradesController`
- [ ] Task 8: `Parimutuel::ParimutuelPoolService` — stake, pool update, implied odds + `Web::ParimutuelBetsController`
- [ ] Task 9: `Parimutuel::ParimutuelSettlementService` — takeout, pro-rata payout (use ledger entry iteration)
- [ ] Task 10: Settlement router — `SettlementService` branches on `mechanism_type`; `ClobSettlementHandler`, `LmsrSettlementHandler`
- [ ] Task 11: `PriceSnapshot` model + `RecordPriceSnapshotJob` — mechanism-appropriate snapshot
- [ ] Task 12: Hot storage — extend `MarketSnapshotProjector` with mechanism fields
- [ ] Task 13: SSE — call projector after each trade/stake in CLOB/LMSR/parimutuel services
- [ ] Task 14: Backoffice UI — mechanism picker + conditional fee fields (also update admin strong params)
- [ ] Task 15: Web UI — mechanism-appropriate price display on market show page
- [ ] Task 16: Full test suite passes at 90% coverage
- [ ] Task 17: Update `docs/WORK_LOG.md` + `docs/INDEX.md`
