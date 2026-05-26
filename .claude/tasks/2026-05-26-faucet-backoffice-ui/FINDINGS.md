# Findings

## 2026-05-26 — Plan written

`WalletGrantService.approve!` and `.reject!` exist and handle full ledger + audit. The admin JSON API controller uses `FaucetRequest.pending.find` (raises 404 if not pending). The backoffice controller intentionally uses `FaucetRequest.find` + pending? check to redirect with an alert instead of 404.

## 2026-05-26 — Implementation complete

All 4 tasks implemented. Key decisions:
- `before_action -> { require_permission!("wallet.faucet.review") }` on all actions (consistent with other backoffice controllers)
- `includes(:user)` on pending query; `includes(:user, :reviewed_by)` on processed query to avoid N+1
- `data-testid` attributes on approve/reject buttons for Playwright E2E hooks
- No AuditEvent in the controller — fully delegated to `WalletGrantService`
