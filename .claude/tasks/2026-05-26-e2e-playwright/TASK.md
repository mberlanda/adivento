# Task: E2E Playwright Test Suite

Implement and run a full Playwright end-to-end test suite against the Adivento application covering: authentication and nav visibility by role, backoffice template→market creation flow, player bet placement via authenticated API with UI validation, moderator/admin settlement with UI validation, and a voided-scenario placeholder. Tests must use `data-testid` selectors for deterministic interactions and produce HTML reports with traces/screenshots/videos on failure. The suite runs against a local Docker Compose stack (`BASE_URL=http://0.0.0.0:3000`) and must be wirable to a stage deployment via `BASE_URL=https://stage-host`.

Spec: `docs/specs/ITERATION_005_UI_E2E_SPEC.md` (legacy, content still valid)
E2E scaffold: `e2e/playwright/`
