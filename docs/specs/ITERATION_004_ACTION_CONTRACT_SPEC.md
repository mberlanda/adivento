<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 004 Action Contract Spec

## Implementation Tracking
- Spec status: PARTIALLY_IMPLEMENTED
- Implemented items:
  - action object fields key/surface/path/method
  - auth payload includes actions
  - web nav consumes action contract
  - seed taxonomy moved to domain catalogs and sync services
- Remaining:
  - service-level unit tests for guest/player/admin matrices
  - seed idempotency regression test

## 1. Action Object
Each action is represented as:
- `key`: globally unique string identifier
- `surface`: `navigation` or `capability`
- `path`: canonical route path
- `method`: HTTP method (`get`, `post`, `delete`, etc.)

Example:
```json
{
  "key": "navigation.backoffice",
  "surface": "navigation",
  "path": "/backoffice",
  "method": "get"
}
```

## 2. Resolution Rules
1. Start from static action catalog.
2. Keep actions with no permission requirement.
3. For permission-gated actions, include action only if `AuthorizationService.allowed?` is true.
4. Apply authentication guards:
- guest only actions excluded for signed-in users
- signed-in actions excluded for guests

## 3. Initial Action Set
### 3.1 Navigation
- `navigation.markets` -> `/web/markets` (`get`, guest + signed-in)
- `navigation.backoffice` -> `/backoffice` (`get`, requires `backoffice.access`)
- `navigation.sign_in` -> `/signin` (`get`, guest only)
- `navigation.sign_out` -> `/signout` (`delete`, signed-in only)

### 3.2 Capability
- `capability.bet.place` -> `/markets/:market_id/bets` (`post`, requires `bet.place`)
- `capability.risk.read` -> `/admin/markets/:id/risk` (`get`, requires `risk.read`)

## 4. API Contract Changes
### 4.1 Register/Login
Add an additive field `actions` to existing auth payload.

### 4.2 Me
`GET /auth/me` returns:
- `id`
- `email`
- `role`
- `actions`

## 5. Seed Data Contract
Permissions and template taxonomy definitions live in domain constants.
Seeds perform synchronization, not taxonomy definition.

## 6. Non-Goals
- No frontend JavaScript hydration for nav.
- No endpoint versioning change in this slice.
