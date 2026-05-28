# Findings: TD-008 Player Positions + Execution HTML Views

## Not yet started

Key files to read before starting:
- `app/controllers/web/positions_controller.rb`
- `app/controllers/web/betslip_executions_controller.rb`
- `app/views/web/profile/show.html.erb` — nav pattern to follow for new link
- `e2e/playwright/tests/workflow.spec.js` — existing betslip E2E to extend

Note: `GET /web/positions` returns `clob_positions` — check if fixed-odds `bets` should also appear on this page (they're currently only visible on the profile page bet history).
