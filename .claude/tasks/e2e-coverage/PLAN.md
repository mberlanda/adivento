# Plan: E2E Coverage Expansion

## Done

- [x] Analyze all web controllers, routes, and views for data-testid coverage
- [x] Create task artifact (TASK.md, FINDINGS.md, PLAN.md)
- [x] GAP-1: Guest market browsing test (no sign-in, sees markets-list)
- [x] GAP-2: Backoffice settle-market via UI (moderator signs in, navigates to market, settles)
- [x] GAP-3: Betslip API round-trip (quote → execute → fetch execution via /web/betslips/*)
- [x] GAP-4: Positions list API test (GET /web/positions after placing bet)
- [x] GAP-5: Cashout API test (cashout_quotes → cashout_execute)
- [x] Run E2E suite to verify new tests pass
- [x] Commit

## TODO — needs view-level changes first

- [ ] GAP-7: Backoffice open-market via UI
  - Prereq: create market via admin API WITHOUT opening it (pass status: 'draft')
  - Test: sign in as moderator → navigate to market → click open-market-submit → assert status open
  - View already has data-testid: no change needed, just test setup change

- [ ] GAP-8: Faucet request approve flow
  - Prereq: add `data-testid="faucet-row-{id}"` to the faucet_requests/index.html.erb table rows
  - Then: player POST /faucet_requests → admin navigates to /backoffice/faucet_requests → approves
  - Verify: row disappears from pending table

- [ ] GAP-9: Positions HTML page for player
  - Prereq: create `app/views/web/positions/index.html.erb` with data-testid="positions-list"
    and data-testid="position-row-{bet_id}"
  - Then: test player places bet → navigates to /web/positions → sees their bet

- [ ] GAP-10: Betslip execution confirmation page
  - Prereq: create `app/views/web/betslip_executions/show.html.erb` with data-testid="execution-status"
  - Then: test betslip execute → redirect/navigate to execution show page → confirm status

## Low priority (defer)

- [ ] GAP-6: Backoffice market create directly (duplicate of template-based path)
- [ ] GAP-11: SSE settlements endpoint
- [ ] GAP-12: Sign-out flow
