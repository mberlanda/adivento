# Spec: Binary Line DB Invariants

<!-- File location: docs/specs/2026-05-26-binary-line-invariants.md -->
<!-- Written BEFORE the implementation plan. Describes WHAT, not HOW. -->

## Goal

Prevent invalid market configurations by enforcing at the DB and model level that each market has exactly 2 active legs, so that operators and API consumers can rely on all open markets having a consistent binary structure.

## Definitions

- **Binary market**: a market with exactly 2 mutually exclusive outcome legs (e.g., YES/NO, UP/DOWN)
- **Active leg**: a `market_leg` row with `active: true`
- **Draft market**: a market with `status: draft` (integer 0); may have 0 legs during construction
- **Open market**: a market with `status: open` (integer 1); must have exactly 2 legs before transition

## Invariants

1. A market must have exactly 2 `market_legs` at the moment its `status` transitions to `open`; a draft market may have 0 or more legs during construction
2. No market may have more than 2 `market_legs` total (active or inactive)
3. Leg labels within a market must be unique (case-insensitive)
4. A third leg cannot be added via any API or backoffice action once a market already has 2 legs

## API / UI Contract

No new endpoints are introduced. This spec tightens existing behaviour on three entry points:

**`Admin::MarketLegsController` POST `/admin/markets/:market_id/market_legs`**
- Returns `422 Unprocessable Entity` with `{ "error": "Market already has 2 legs" }` if the market already has 2 legs, before attempting to save
- Returns `422 Unprocessable Entity` with `{ "errors": [...] }` for other validation failures (existing behaviour)

**`Backoffice::MarketsController#create` POST `/backoffice/markets`**
- Already defaults to YES/NO legs; no change needed here as long as no more than 2 labels can be submitted
- The `market_leg.create` loop must not silently add more than 2 legs; if `params[:legs]` contains more than 2 values the extras are ignored (or the create action returns an error)

**`Market#open` transition — `Backoffice::MarketsController#open` POST `/backoffice/markets/:id/open`**
- Calls `@market.update!(status: :open)`; the model validation fires before the save
- If fewer than 2 legs exist, the `update!` raises `ActiveRecord::RecordInvalid` and the controller redirects with an alert message

## Status Taxonomy

No new status values. The existing `Market` enum (`draft: 0, open: 1, settled: 2, cancelled: 3`) is unchanged.

## Accounting / Ledger

This spec writes no ledger entries or audit events beyond what the existing open/create flows already emit.

## Test Requirements

- [ ] `Admin::MarketLegsController` POST with market that already has 2 legs returns 422 with `{ "error": "Market already has 2 legs" }`
- [ ] `MarketLeg` model validation: duplicate label (case-insensitive) within same market is invalid
- [ ] `MarketLeg` model validation: adding a 3rd leg to a market that already has 2 is invalid
- [ ] `Market` model validation: cannot transition to `open` with 0 legs (returns errors)
- [ ] `Market` model validation: cannot transition to `open` with 1 leg (returns errors)
- [ ] `Market` model validation: can transition to `open` with exactly 2 legs
- [ ] `Market` model validation: draft status save with 0 legs remains valid (no regression)
- [ ] DB-level trigger rejects a direct SQL insert of a 3rd leg, bypassing ActiveRecord validations

## Out of scope

- Changing the leg model to use canonical `OPTION_1`/`OPTION_2` internal labels (separate migration per the legacy `ITERATION_005_BINARY_MARKET_LINES_SPEC.md`)
- Localisation of leg labels
- Enforcing exactly 2 legs on `cancelled` or `settled` markets (historical records are untouched)
- Backoffice UI for editing existing legs
