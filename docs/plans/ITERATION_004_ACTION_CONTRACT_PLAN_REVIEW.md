# Iteration 004 Plan Review

## Tracking Status
- Review status: DONE
- Implementation status: IN_PROGRESS
- Notes: action schema and additive payload requirements were implemented; test hardening remains ongoing.

## Strengths
- Correctly targets logic duplication risk before mobile rollout.
- Keeps authorization as backend-owned contract.
- Includes testing and fixture caveats.

## Gaps Found
1. Plan should explicitly define action payload schema fields.
2. Plan should state if guest actions are included.
3. Plan should ensure web layout uses exactly same service as API.
4. Plan should preserve backward compatibility in auth payload shape.

## Required Improvements
- Define stable action object:
  - `key`
  - `surface`
  - `path`
  - `method`
- Include guest-visible actions where applicable.
- Inject `actions` as additive field to avoid breaking current consumers.
- Add focused service tests for guest/player/admin permutations.

## Review Outcome
Approved with changes.
