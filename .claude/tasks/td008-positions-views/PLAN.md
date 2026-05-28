# Plan: TD-008 Player Positions + Execution HTML Views

No separate plan file — tracked here. Two sub-tasks; can ship independently.

## Sub-task A: Positions HTML view

- [ ] Read `app/controllers/web/positions_controller.rb` — understand current JSON response
- [ ] Add `format.html` block to `PositionsController#index` (renders view, same data)
- [ ] Create `app/views/web/positions/index.html.erb`:
  - `data-testid="positions-page"` on container
  - CLOB positions table: market, side, contracts, avg price, unrealised value
  - Empty state: "No open positions"
  - Auth guard already in place (requires sign-in)
- [ ] Add link to positions page in nav (after "My Profile")
- [ ] Integration test: GET /web/positions with HTML accept header → 200
- [ ] E2E: sign in, place CLOB order, navigate to /web/positions, assert row visible
- [ ] Update WORK_LOG

## Sub-task B: Betslip execution confirmation HTML view

- [ ] Read `app/controllers/web/betslip_executions_controller.rb`
- [ ] Add `format.html` to `show` action
- [ ] Create `app/views/web/betslip_executions/show.html.erb`:
  - `data-testid="execution-confirmation"` on container
  - Table of bets placed (market, side, stake, estimated payout)
  - Total stake, "Back to markets" link
- [ ] Update `BetslipExecutionsController#create` or client-side redirect to point to HTML show
- [ ] Integration test: GET /web/betslips/executions/:id → HTML 200
- [ ] E2E: execute betslip → lands on confirmation page with bet summary
- [ ] Update WORK_LOG
