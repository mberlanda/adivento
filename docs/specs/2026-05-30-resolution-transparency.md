# Spec: Resolution Transparency (D7)

<!-- Decision D7-TODO-006. Recommended option: require a resolution note + settlement metadata across all settlement paths. -->
<!-- Scope decision (see tracker): MINIMAL mandatory-note path. The propose/approve/execute -->
<!-- workflow (SEC-003) is an explicit follow-up, NOT part of this spec. -->

## Goal

Every settled market records a mandatory operator-written resolution note and a settlement timestamp, which are shown to players on the market page so a player who lost a bet can see why and when the market resolved.

## Definitions

- **Resolution note**: free-text explanation of why the market resolved to the winning outcome. Stored on `markets.resolution_note`.
- **Settled-at**: timestamp settlement executed. Stored on `markets.settled_at`.
- **Settlement path**: any code path that transitions a market to `settled`. The entry point is `SettlementService.settle!`, which dispatches to the four mechanism handlers.

## Background / Current State

- `markets` has `settled_outcome`, `settled_by_id`, `resolution_criteria`, and `resolution_source`, but no `resolution_note` and no `settled_at`.
- The backoffice settle form has used a free-text reason in some flows, but the value is not persisted as player-visible resolution metadata.
- `SettlementService.settle!(market:, outcome:, actor:)` takes no note. `Admin::MarketsController#settle` and `Backoffice::MarketsController#settle` both call it with `outcome` only.

## Invariants

1. `SettlementService.settle!` requires a `resolution_note` whose stripped length is at least 20 characters.
2. Blank or too-short notes raise `SettlementService::InvalidSettlement` and leave the market unsettled.
3. Successful settlement persists `markets.resolution_note` and `markets.settled_at` for fixed-odds, CLOB, LMSR, and parimutuel markets.
4. Settlement audit metadata includes `resolution_note`, `resolution_source`, `settled_at`, `outcome`, and `mechanism`.
5. Customer and backoffice market pages display the resolution note and settled-at timestamp for settled markets.
6. The note requirement is enforced at `SettlementService.settle!`, so no settlement path can bypass it.

## API / UI Contract

**Service:** `SettlementService.settle!(market:, outcome:, actor:, resolution_note:)`

- New required keyword `resolution_note:`.
- Validates stripped length >= 20 before dispatch.

**Backoffice HTML:** `POST /backoffice/markets/:id/settle`

- Settle form includes required `resolution_note` textarea.
- Blank/short note redirects or re-renders with an error and leaves market unchanged.

**Admin JSON:** `POST /admin/markets/:id/settle`

- Request requires `resolution_note`.
- Missing/short note returns 422 with `{ "error": "<message>" }`.
- Success response includes `resolution_note` and `settled_at`.

**Customer market page:** `app/views/web/markets/show.html.erb`

- Settled markets render the note and timestamp alongside the existing outcome/source information.

## Accounting / Ledger

No new ledger entries. Existing settlement payout entries are unchanged. Audit metadata is strengthened so settlement evidence is visible without replaying controller params.

## Test Requirements

- [ ] `settle!` with blank or less-than-20-character note raises `InvalidSettlement` and leaves market unsettled.
- [ ] `settle!` with a valid note persists `resolution_note` and `settled_at` for all four mechanisms.
- [ ] `market.settle` audit metadata includes the note and timestamp.
- [ ] Backoffice settle with a valid note settles and shows it.
- [ ] Backoffice settle with a blank note does not settle.
- [ ] Admin settle without a note returns 422; with a note returns the note and `settled_at`.
- [ ] Customer market page shows the note and `settled_at` for a settled market.

## Out of Scope

- Propose/approve/execute resolution workflow, separation of duties, and evidence attachments. Track under SEC-003.
- Two-step settle confirmation with payout preview. Track under UX-030.
- Editing or retracting a resolution note after settlement.
- Per-bet "why you lost" breakdown beyond the market-level note.
