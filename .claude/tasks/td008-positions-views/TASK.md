# Task: TD-008 Player Positions + Execution HTML Views

Two endpoints currently return JSON only. Players have no browser-visible page for either:

1. **`GET /web/positions`** — returns `{ clob_positions: [...] }`. Players need an HTML view showing their open CLOB positions (YES/NO contracts, avg price, unrealised value).

2. **`GET /web/betslips/executions/:id`** — returns execution JSON. Players need a confirmation page after a betslip executes (shows what bets were placed, total stake, estimated payouts).

Both require:
- HTML view with `data-testid` attributes for E2E coverage
- A controller `respond_to :html, :json` block (JSON path already works)
- Nav/redirect from the betslip execute flow to the confirmation page
- E2E tests (Playwright) for the new HTML paths
