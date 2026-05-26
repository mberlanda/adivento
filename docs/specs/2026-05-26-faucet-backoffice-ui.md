# Spec: Faucet Request Backoffice UI

<!-- File location: docs/specs/2026-05-26-faucet-backoffice-ui.md -->
<!-- Written BEFORE the implementation plan. Describes WHAT, not HOW. -->

## Goal

Allow moderators and admins to view pending faucet requests and approve or reject them through the backoffice HTML interface.

## Definitions

- **FaucetRequest**: a player's request for a wallet top-up (ADIV tokens); requires operator approval before any tokens are credited
- **Pending**: a faucet request that has not yet been reviewed (status: 0)
- **Approved**: a faucet request that was accepted and whose amount was credited to the player's wallet (status: 1)
- **Rejected**: a faucet request that was declined; no wallet change occurs (status: 2)

## Invariants

1. Only users with the `wallet.faucet.review` permission (moderators and admins by default) can access faucet backoffice pages
2. Approving a faucet request credits the player's wallet via `WalletGrantService.approve!` — the same service used by the admin JSON API
3. Rejecting a faucet request marks it rejected via `WalletGrantService.reject!` without any wallet change
4. Already-processed requests (status approved or rejected) cannot be approved or rejected again; attempts return a redirect with an alert
5. Every approve and reject action writes an AuditEvent (delegated to `WalletGrantService`)

## API / UI Contract

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/backoffice/faucet_requests` | List all faucet requests — pending first (oldest first), then processed (newest first, limit 50) |
| `POST` | `/backoffice/faucet_requests/:id/approve` | Approve a pending request; redirect to index with notice |
| `POST` | `/backoffice/faucet_requests/:id/reject` | Reject a pending request; redirect to index with notice |

**Index page layout:**
- Section 1: pending requests table — player email, amount (minor units), created_at, Approve button, Reject button
- Section 2: recently processed requests table — player email, amount, status, processed_at (updated_at)

**Redirect behavior:**
- Success (approve/reject): redirect to `backoffice_faucet_requests_path` with `notice`
- Already processed: redirect to `backoffice_faucet_requests_path` with `alert: "Request has already been processed"`
- Record not found: raises `ActiveRecord::RecordNotFound` (standard Rails 404)

## Accounting / Ledger

This feature does not introduce new ledger entry types. It reuses existing service logic:

| entry_type | direction | when |
|-----------|-----------|------|
| `FAUCET_GRANT` | credit | on approve (via `WalletGrantService.approve!`) |

## Test Requirements

- [ ] Moderator can view faucet requests list (200 response, table present)
- [ ] Player cannot access faucet requests list (redirect, no access)
- [ ] Unauthenticated request cannot access faucet requests list (redirect)
- [ ] Moderator can approve a pending request (wallet credited, AuditEvent written, redirect with notice)
- [ ] Moderator can reject a pending request (status updated, AuditEvent written, redirect with notice)
- [ ] Cannot approve an already-approved request (redirect with alert, no double-credit)
- [ ] Cannot reject an already-rejected request (redirect with alert)

## Out of scope

- Pagination of faucet requests (the processed list is capped at 50)
- Bulk approve/reject actions
- Free-text note input in the backoffice UI (note field is not surfaced; approve/reject use nil note)
- Player-facing view of their own faucet request status
