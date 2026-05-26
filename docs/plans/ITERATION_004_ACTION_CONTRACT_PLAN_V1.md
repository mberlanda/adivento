# Iteration 004 Plan V1: Unified Action Contract

## Implementation Status
- Status: IN_PROGRESS
- Implemented:
	- domain catalogs for permissions/templates/actions
	- seed synchronization services wired into seeds
	- auth payload includes actions for register/login/me
	- nav rendering uses available actions contract
- Pending:
	- unit tests for AvailableActionsService permutations
	- full regression around seeds sync idempotency

## Problem
Navigation and capability visibility are currently derived in multiple places (web views and auth checks), which risks drift across web and future mobile clients.

## Goal
Create a single backend action contract that:
- powers top-nav visibility
- is returned by authenticated API payloads
- can be consumed by mobile apps without re-implementing permission logic

## Scope
1. Add domain catalogs for:
- permission taxonomy
- market templates

2. Replace seed inline arrays with catalog-driven synchronization.

3. Add `AvailableActionsService` that resolves actions by user + authorization rules.

4. Expose available actions in auth payloads:
- `POST /auth/login`
- `POST /auth/register`
- `GET /auth/me`

5. Make web nav read from the action contract rather than embedding permission checks in view logic.

6. Add tests:
- unit tests for action resolution
- integration tests for auth payload actions
- integration tests for player/admin nav behavior

## Risks
- Existing fixtures include ad hoc grants that can change expected nav visibility.
- Action schema changes can break clients if unstable.

## Mitigations
- Keep a stable, explicit action schema with key/path/method/surface fields.
- Use grant-free users in tests where baseline role behavior is asserted.

## Done Criteria
- One action source drives both API payload and web nav.
- Player without grants does not see backoffice action.
- Admin sees backoffice action.
- Seeds rely on domain constants for permissions and templates.
- Full suite passes with coverage >= 90%.
