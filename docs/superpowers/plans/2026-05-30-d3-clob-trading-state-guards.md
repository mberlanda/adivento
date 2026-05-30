# D3 CLOB Trading-State Guards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize CLOB order lifecycle checks in `Clob::OrderMatchingService` so web and admin callers cannot place orders outside valid market trading states.

**Architecture:** Add a service-level guard before `build_incoming_order`. Keep controller-specific response formatting in controllers, but remove duplicate lifecycle checks from `Web::OrdersController#create` after the service returns consistent errors. `Admin::OrdersController#create` will inherit the same draft/closed/settled/cancelled/expired protection without duplicating rules. Preserve the current user-facing error copy: `Market is not open` and `Market is closed for new bets`.

**Tech Stack:** Rails 8, Minitest integration/service tests, existing CLOB service/controller patterns.

---

## File Map

- Modify: `app/services/clob/order_matching_service.rb`
- Modify: `app/controllers/web/orders_controller.rb`
- Test: `test/services/clob/order_matching_service_test.rb`
- Test: `test/integration/clob_orders_test.rb`
- Test: `test/integration/web_orders_test.rb`
- Update after implementation: `docs/wiki/tech-debt-backlog.md`, `.claude/tasks/ATTENTION.md`, `docs/WORK_LOG.md`

## Task 1: Add service-level lifecycle tests

- [ ] **Step 1: Add direct service tests**

Add these tests to `test/services/clob/order_matching_service_test.rb`:

```ruby
test 'rejects order when CLOB market is draft' do
  @market.update!(status: :draft)
  yes_leg = @market.market_legs.find_by!(label: 'YES')
  result = nil

  assert_no_difference('Order.count') do
    result = Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: @buyer, market_leg: yes_leg,
        side: 'YES', price_cents: 40, quantity: 1, time_in_force: :gtc
      }
    )
  end

  assert_not result.success?
  assert_includes result.errors, 'Market is not open'
end

test 'rejects order when CLOB market is past close_at' do
  @market.update!(close_at: 1.minute.ago)
  yes_leg = @market.market_legs.find_by!(label: 'YES')
  result = nil

  assert_no_difference('Order.count') do
    result = Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: @buyer, market_leg: yes_leg,
        side: 'YES', price_cents: 40, quantity: 1, time_in_force: :gtc
      }
    )
  end

  assert_not result.success?
  assert_includes result.errors, 'Market is closed for new bets'
end

test 'rejects order when CLOB market is closed, settled, or cancelled' do
  yes_leg = @market.market_legs.find_by!(label: 'YES')

  %i[closed settled cancelled].each do |status|
    @market.update!(status: status, close_at: (status == :closed ? 1.minute.ago : nil))
    result = Clob::OrderMatchingService.call(
      market: @market,
      incoming_order_params: {
        user: @buyer, market_leg: yes_leg,
        side: 'YES', price_cents: 40, quantity: 1, time_in_force: :gtc
      }
    )

    assert_not result.success?, "expected #{status} market to reject CLOB order"
    assert_includes result.errors, 'Market is not open'
  end
end
```

- [ ] **Step 2: Run the service tests and verify failure**

Run:

```bash
bin/rails test test/services/clob/order_matching_service_test.rb -n '/rejects order/'
```

Expected: both tests fail because `OrderMatchingService` currently creates the order before checking market lifecycle.

## Task 2: Add admin/web integration regression tests

- [ ] **Step 1: Add admin API tests**

Add to `test/integration/clob_orders_test.rb`:

```ruby
test 'admin order placement rejects draft CLOB market through service guard' do
  @market.update!(status: :draft)

  post "/admin/markets/#{@market.id}/orders",
       headers: auth_headers_for(users(:admin)),
       params: { user_id: users(:player).id, side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
       as: :json

  assert_response :unprocessable_content
  assert_includes response.parsed_body['errors'], 'Market is not open'
end

test 'admin order placement rejects expired CLOB market through service guard' do
  @market.update!(close_at: 1.minute.ago)

  post "/admin/markets/#{@market.id}/orders",
       headers: auth_headers_for(users(:admin)),
       params: { user_id: users(:player).id, side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
       as: :json

  assert_response :unprocessable_content
  assert_includes response.parsed_body['errors'], 'Market is closed for new bets'
end

test 'admin order placement rejects closed, settled, and cancelled CLOB markets through service guard' do
  %i[closed settled cancelled].each do |status|
    @market.update!(status: status, close_at: (status == :closed ? 1.minute.ago : nil))

    post "/admin/markets/#{@market.id}/orders",
         headers: auth_headers_for(users(:admin)),
         params: { user_id: users(:player).id, side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
         as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body['errors'], 'Market is not open'
  end
end
```

- [ ] **Step 2: Add web JSON regression test**

Add to `test/integration/web_orders_test.rb`:

```ruby
test 'web order placement surfaces service lifecycle guard for expired CLOB market' do
  @market.update!(close_at: 1.minute.ago)

  post "/web/markets/#{@market.id}/orders",
       headers: auth_headers_for(@player),
       params: { side: 'YES', price_cents: 40, quantity: 5, time_in_force: 'GTC' },
       as: :json

  assert_response :unprocessable_content
  assert_includes response.parsed_body['errors'], 'Market is closed for new bets'
end
```

- [ ] **Step 3: Run integration tests and verify admin failures**

Run:

```bash
bin/rails test test/integration/clob_orders_test.rb test/integration/web_orders_test.rb
```

Expected: admin draft/expired tests fail before implementation; web may still pass through controller-local guards until Task 3 removes duplication.

## Task 3: Implement centralized guard

- [ ] **Step 1: Add the guard to the service**

In `app/services/clob/order_matching_service.rb`, add this call as the first line inside the transaction:

```ruby
def call
  ApplicationRecord.transaction do
    validate_market_trading_state!
    order = build_incoming_order
```

Add this private method:

```ruby
def validate_market_trading_state!
  raise 'Market is not open' unless @market.open?
  raise 'Market is closed for new bets' if @market.close_at.present? && @market.close_at <= Time.current
end
```

- [ ] **Step 2: Simplify web controller lifecycle checks**

In `app/controllers/web/orders_controller.rb`, keep the `market.clob?` check, then remove the local `market.open?` and `close_at` blocks. The service result branch already renders errors as JSON or HTML alert:

```ruby
unless market.clob?
  return respond_to do |format|
    format.html { redirect_to web_market_path(market), alert: 'Not a CLOB market' }
    format.json { render json: { error: 'Not a CLOB market' }, status: :unprocessable_content }
  end
end
```

- [ ] **Step 3: Run targeted tests**

Run:

```bash
bin/rails test test/services/clob/order_matching_service_test.rb test/integration/clob_orders_test.rb test/integration/web_orders_test.rb
```

Expected: all pass.

## Task 4: Document and commit

- [ ] **Step 1: Update docs**

Update `docs/wiki/tech-debt-backlog.md` TD-020 to `Status: Planned` before implementation or `Status: Done` after implementation, depending on execution scope.

- [ ] **Step 2: Run full verification**

Run:

```bash
bin/rails test
```

Expected: all tests pass, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add app/services/clob/order_matching_service.rb app/controllers/web/orders_controller.rb \
        test/services/clob/order_matching_service_test.rb test/integration/clob_orders_test.rb \
        test/integration/web_orders_test.rb docs/wiki/tech-debt-backlog.md
git commit -m "fix(clob): centralize order trading-state guards"
```
