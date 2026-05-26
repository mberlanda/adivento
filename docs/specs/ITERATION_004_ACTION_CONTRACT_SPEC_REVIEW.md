# Iteration 004 Spec Review

## Tracking Status
- Review status: DONE
- Residual risk: grant-heavy fixtures can mask baseline role behavior unless grant-free test users are used.
- Follow-up: keep endpoint integration assertions in sync with actions contract evolution.

## Correctness Check
- Action schema is explicit and stable.
- Rules align with existing authorization precedence.
- API change is additive and backward compatible.

## Implementation Feasibility
- Can be implemented with one service plus controller payload wiring.
- Web layout can consume helper wrappers around service output.
- Seed refactor can be isolated to constants + seeds.

## Edge Cases
- User-specific grants can alter expected nav visibility.
- Inactive permissions should exclude related actions.
- Guest session must still receive navigation actions (markets/sign_in).

## Test Matrix Required
- Guest: sees markets + sign_in, no backoffice.
- Player role baseline: no backoffice, yes bet.place capability.
- Moderator/admin: backoffice visible; admin gets full set.
- `auth/me` includes `actions` field.

## Review Outcome
Approved for implementation.
