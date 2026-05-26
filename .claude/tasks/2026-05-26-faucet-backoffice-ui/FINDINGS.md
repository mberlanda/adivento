# Findings

## 2026-05-26 — Plan written

`WalletGrantService.approve!` and `.reject!` exist and handle full ledger + audit. The admin JSON API controller uses `FaucetRequest.pending.find` (raises 404 if not pending). The backoffice controller intentionally uses `FaucetRequest.find` + pending? check to redirect with an alert instead of 404.
