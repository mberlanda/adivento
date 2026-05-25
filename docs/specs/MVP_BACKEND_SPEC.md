# MVP Backend Spec (Iteration 001)

## 1. Actors and Visibility
- Guest (non-logged): can list/view open or settled markets only.
- Player: can authenticate, see all markets, request faucet credits, view wallet.
- Moderator: player rights + create legs on existing markets and settle markets.
- Admin: moderator rights + create/update markets and full faucet request moderation.

## 2. Authentication
- Token model: JWT bearer token.
- Endpoints:
  - `POST /auth/register`
  - `POST /auth/login`
  - `GET /auth/me`
- Registration always creates `player` role.

## 3. Markets
- Market states: `draft`, `open`, `settled`, `cancelled`.
- Endpoints:
  - `GET /markets` (guest-filtered)
  - `GET /markets/:id` (guest restricted on non-public states)
  - `POST /admin/markets` (admin)
  - `PATCH /admin/markets/:id` (admin)
  - `POST /admin/markets/:id/legs` (moderator/admin)
  - `POST /admin/markets/:id/settle` (moderator/admin)
- Default legs on creation: `YES`, `NO`.

## 4. Wallet and Faucet
- Wallet asset code: `ADIV` (fantasy coin).
- Wallet balances tracked in minor units.
- Endpoints:
  - `GET /wallet` (authenticated)
  - `POST /faucet_requests` (player)
  - `GET /admin/faucet_requests` (moderator/admin)
  - `POST /admin/faucet_requests/:id/approve` (moderator/admin)
  - `POST /admin/faucet_requests/:id/reject` (moderator/admin)
- Approval side effects:
  - wallet `available_minor` increment
  - `ledger_entries` append-only insert
  - `audit_events` append-only insert

## 5. Data Integrity Rules
- Unique user email.
- Exactly one wallet per user.
- Unique market leg label per market.
- Positive faucet amount.
- Settled outcome must match an existing market leg.

## 6. Test and Quality Gates
- Rails test suite includes model + integration + service tests.
- Coverage tool: SimpleCov.
- Quality target for this iteration: > 90% line coverage.
