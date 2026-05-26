# Iteration 005 Plan V1: UI End-to-End Automation

## Objective
Create browser-driven UI tests that run against local, docker compose, and stage deployments.

## Framework Decision
- Use Playwright over Cypress for multi-browser support and API+UI hybrid orchestration in one runner.

## Scope
1. Add test-id hooks for stable UI selectors.
2. Add Playwright configuration with environment-driven BASE_URL.
3. Implement core scenarios:
- moderator/admin creates market flow
- player places bet path
- settle win/loss path
- placeholder test for voided path until endpoint exists
4. Support headless and headed runs.

## Exit Criteria
- Tests executable via npm scripts.
- Compatible with docker compose app URL.
- HTML report produced for CI/stage visibility.
