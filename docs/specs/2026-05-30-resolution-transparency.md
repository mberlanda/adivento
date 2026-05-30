# Spec: Resolution Transparency (D7)

<!-- Decision D7-TODO-006. Recommended option: require a resolution note + settlement metadata across all settlement paths. -->
<!-- Scope decision (see tracker): MINIMAL mandatory-note path. The propose/approve/execute -->
<!-- workflow (SEC-003) is an explicit follow-up, NOT part of this spec. -->

## Goal
Every settled market records a mandatory operator-written resolution note and a settlement timestamp, which are shown to players on the market page — so a player who lost a bet can see *why* and *when* the market resolved.

## Definitions
- **Resolution note**: free-text explanation (operator-supplied) of why the market resolved to the winning outcome. Stored on `markets.resolution_note`.
- **Settled-at**: the timestamp settlement executed. Stored on `markets.settled_at`.
- **Settlement path**: any code path that transitions a market to `settled`. There is exactly one entry point — `SettlementService.settle!` — which dispatches to the four mechanism handlers. This spec enforces the note centrally at that entry point so all mechanisms are covered uniformly.

## Background / current state
- `markets` has `settled_outcome`, `settled_by_id`, `resolution_criteria`, `resolution_source`, but **no `resolution_note` and no `settled_at`** (verified in `db/structure.sql`).
- The backoffice settle form already renders a "Reason" text field (`app/views/backoffice/markets/show.html.erb:86`, testid `settle-reason`) but the value is **discarded** — the controller passes only `outcome`.
- `SettlementService.settle!(market:, outcome:, actor:)` takes no note. `Admin::MarketsController#settle` and `Backoffice::MarketsController#settle` both call it with `outcome` only.

## Invariants
1. `SettlementService.settle!` requires a `resolution_note` whose stripped length ≥ 10; otherwise it raises `SettlementService::InvalidSettlement` and the market stays unsettled (transaction rolls back).
2. On successful settlement, `markets.resolution_note` is persisted and `markets.settled_at` is set to the settlement time, regardless of mechanism (fixed_odds, clob, lmsr, parimutuel).
3. The `market.settle` `AuditEvent` metadata includes the `resolution_note`.
4. The customer market page displays the resolution note and settled-at timestamp for any settled market.
5. The note requirement is enforced at the single `SettlementService.settle!` entry point (no settlement path can bypass it).

## API / UI Contract
**Service** — `SettlementService.settle!(market:, outcome:, actor:, resolution_note:)`
- New required keyword `resolution_note:`. Validates length ≥ 10 (stripped) before dispatch.

**Backoffice (HTML)** — `POST /backoffice/markets/:id/settle`
- Existing `reason` field is renamed to `resolution_note` (testid stays `settle-reason`), marked `required`, and passed through. On blank/short note → re-render with the validation error (alert), market unchanged.

**Admin (JSON)** — `POST /admin/markets/:id/settle`
- Request now requires `resolution_note` in params. Missing/short → `422` with `{ "error": "<message>" }`. Success response adds `"resolution_note"` and `"settled_at"`.

**Customer market page** — `app/views/web/markets/show.html.erb` resolution panel
- For settled markets, render the resolution note (testid `market-resolution-note`) and the settled-at timestamp (testid `market-settled-at`) alongside the existing "Settled outcome".

## Status Taxonomy
None (no new enums; `settled` already exists).

## Accounting / Ledger
None new. The existing settlement ledger/audit writes are unchanged except the `market.settle` AuditEvent now carries `resolution_note` in metadata (invariant 3).

## Test Requirements
- [ ] `settle!` with a blank or <10-char note raises `InvalidSettlement` and leaves the market unsettled (no payouts, no status change).
- [ ] `settle!` with a valid note persists `resolution_note` + `settled_at` for each of the 4 mechanisms.
- [ ] The `market.settle` AuditEvent metadata includes the note.
- [ ] Backoffice settle with a valid note settles and shows it; backoffice settle with a blank note re-renders an error and does not settle.
- [ ] Admin settle without a note returns 422; with a note returns the note + settled_at.
- [ ] Customer market page shows the note + settled-at for a settled market.

## Out of scope
- Propose → approve → execute resolution workflow, separation of duties, evidence attachments (tracked as **SEC-003** in the synthesis; this spec is the minimal note-only path).
- Two-step settle confirmation with payout preview (UX-030).
- Editing/retracting a resolution note after settlement.
- Per-bet "why you lost" breakdown beyond the market-level note.
