<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 005 Spec: UI End-to-End Suite

## Runtime Targets
- Local development: BASE_URL=http://0.0.0.0:3000
- Docker compose: same target or mapped host
- Stage: BASE_URL=https://stage.example

## Browser Matrix
- Chromium
- Firefox
- WebKit

## Required Scenarios
1. Authentication and nav visibility by role.
2. Backoffice template -> market creation flow through UI.
3. Player stake placement using authenticated API call with UI validation of market state.
4. Moderator/admin settlement with UI validation.
5. Voided scenario test placeholder until void endpoint is implemented.

## Selector Contract
- Components must expose data-testid for deterministic interactions.

## Project Structure
- Runner and dependencies are isolated under `e2e/playwright`.
- Tests live under `e2e/playwright/tests`.
- Docker image and compose overlay are under `e2e/playwright`.

## Reporting
- HTML report with traces/screenshots/videos on failure.
