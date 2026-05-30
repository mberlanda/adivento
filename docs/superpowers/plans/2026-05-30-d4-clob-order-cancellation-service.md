# D4 CLOB Order Cancellation Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace duplicated web/admin CLOB order cancellation code with a shared `Clob::OrderCancellationService` that locks the order and wallet for the whole state transition.

**Architecture:** Introduce one service that owns order cancellation, reservation release, audit logging, and idempotent rejection of already-final orders. Controllers become thin authorization/response adapters. This builds on the partial TD-013 fix where admin cancellation already locks order and wallet, but it removes drift between web/admin paths. This service is also the canonical single-order cancellation primitive for D2 market cancellation; `MarketCancellationService#refund_clob!` should call it for open/partial orders unless D2 deliberately chooses one larger transaction and documents the trade-off.

**Tech Stack:** Rails 8, Minitest integration/service tests, existing `Order#reserved_minor` helper.

---

## File Map

- Create: `app/services/clob/order_cancellation_service.rb`
- Test: `test/services/clob/order_cancellation_service_test.rb`
- Modify: `app/controllers/admin/orders_controller.rb`
- Modify: `app/controllers/web/orders_controller.rb`
- Test: `test/integration/clob_orders_test.rb`
- Test: `test/integration/web_orders_test.rb`
- Update after implementation: `docs/wiki/tech-debt-backlog.md`, `.claude/tasks/ATTENTION.md`, `docs/WORK_LOG.md`

## Task 1: Write service tests first

- [ ] **Step 1: Create service test file**

Create `test/services/clob/order_cancellation_service_test.rb`:

```ruby
require 'test_helper'

module Clob
  class OrderCancellationServiceTest < ActiveSupport::TestCase
    setup do
      @market = markets(:clob_market)
      @leg = @market.market_legs.find_by!(label: 'YES')
      @user = users(:player)
      @actor = users(:admin)
      @user.wallet.update!(available_minor: 99_800, reserved_minor: 200)
      @order = Order.create!(
        market: @market, market_leg: @leg, user: @user,
        side: 'YES', price_cents: 40, quantity: 5,
        status: :open, time_in_force: :gtc
      )
    end

    test 'cancels open order and releases reserved funds under lock' do
      result = Clob::OrderCancellationService.call(order: @order, actor: @actor)

      assert result.success?
      assert_equal 200, result.released_minor
      assert_predicate @order.reload, :cancelled?
      assert_equal 100_000, @user.wallet.reload.available_minor
      assert_equal 0, @user.wallet.reserved_minor
      assert AuditEvent.exists?(action: 'order.cancel', target_type: 'Order', target_id: @order.id)
    end

    test 'rejects already filled order without releasing funds' do
      @order.update!(status: :filled, filled_quantity: 5)

      result = Clob::OrderCancellationService.call(order: @order, actor: @actor)

      assert_not result.success?
      assert_includes result.errors, 'Order cannot be cancelled'
      assert_equal 200, @user.wallet.reload.reserved_minor
    end
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:

```bash
bin/rails test test/services/clob/order_cancellation_service_test.rb
```

Expected: fail with `uninitialized constant Clob::OrderCancellationService`.

## Task 2: Implement the service

- [ ] **Step 1: Add service class**

Create `app/services/clob/order_cancellation_service.rb`:

```ruby
module Clob
  class OrderCancellationService
    Result = Struct.new(:success?, :order, :released_minor, :errors, keyword_init: true)

    def self.call(order:, actor:)
      new(order: order, actor: actor).call
    end

    def initialize(order:, actor:)
      @order = order
      @actor = actor
    end

    def call
      released = nil
      locked = nil

      ApplicationRecord.transaction do
        locked = Order.lock.find(@order.id)
        raise ActiveRecord::Rollback unless cancellable?(locked)

        released = locked.reserved_minor
        locked.cancelled_quantity += locked.unfilled_quantity
        locked.status = :cancelled
        locked.save!

        wallet = locked.user.wallet.lock!
        wallet.update!(
          reserved_minor: wallet.reserved_minor - released,
          available_minor: wallet.available_minor + released
        )

        AuditEvent.create!(
          action: 'order.cancel',
          actor: @actor,
          target_type: 'Order',
          target_id: locked.id,
          metadata: { released_minor: released, market_id: locked.market_id }
        )
      end

      if released.nil?
        Result.new(success?: false, order: @order, released_minor: 0, errors: ['Order cannot be cancelled'])
      else
        Result.new(success?: true, order: locked, released_minor: released, errors: [])
      end
    rescue StandardError => e
      Result.new(success?: false, order: @order, released_minor: 0, errors: [e.message])
    end

    private

    def cancellable?(order)
      order.open? || order.partial?
    end
  end
end
```

- [ ] **Step 2: Run service tests**

Run:

```bash
bin/rails test test/services/clob/order_cancellation_service_test.rb
```

Expected: pass.

## Task 3: Refactor controllers

- [ ] **Step 1: Refactor admin controller**

Replace `Admin::OrdersController#destroy` body with:

```ruby
def destroy
  order = Order.find(params.expect(:id))
  result = Clob::OrderCancellationService.call(order: order, actor: current_user)

  unless result.success?
    return render json: { error: result.errors.join(', ') }, status: :unprocessable_content
  end

  render json: {
    order_id: result.order.id,
    status: result.order.status,
    released_minor: result.released_minor
  }
end
```

- [ ] **Step 2: Refactor web controller**

Replace `Web::OrdersController#destroy` body with:

```ruby
def destroy
  order = Order.find(params.expect(:id))
  return render json: { error: 'Forbidden' }, status: :forbidden unless order.user_id == current_user.id

  result = Clob::OrderCancellationService.call(order: order, actor: current_user)

  unless result.success?
    return render json: { error: result.errors.join(', ') }, status: :unprocessable_content
  end

  render json: { order_id: result.order.id, status: result.order.status }
end
```

- [ ] **Step 3: Run existing controller tests**

Run:

```bash
bin/rails test test/integration/clob_orders_test.rb test/integration/web_orders_test.rb
```

Expected: all pass.

## Task 4: Add duplicate-cancel regression

- [ ] **Step 1: Add idempotent rejection integration tests**

Add to `test/integration/clob_orders_test.rb`:

```ruby
test 'admin duplicate cancel does not release funds twice' do
  order = Order.create!(
    market: @market, market_leg: @leg, user: users(:player),
    side: 'YES', price_cents: 40, quantity: 5,
    status: :open, time_in_force: :gtc
  )
  users(:player).wallet.update!(available_minor: 99_800, reserved_minor: 200)

  delete "/admin/orders/#{order.id}", headers: auth_headers_for(users(:admin)), as: :json
  assert_response :ok

  delete "/admin/orders/#{order.id}", headers: auth_headers_for(users(:admin)), as: :json
  assert_response :unprocessable_content

  assert_equal 100_000, users(:player).wallet.reload.available_minor
  assert_equal 0, users(:player).wallet.reserved_minor
end
```

- [ ] **Step 2: Run cancellation tests**

Run:

```bash
bin/rails test test/services/clob/order_cancellation_service_test.rb test/integration/clob_orders_test.rb test/integration/web_orders_test.rb
```

Expected: all pass.

Note: `Web::OrdersController#destroy` currently writes no audit row. Routing web cancellation through this service intentionally adds one `order.cancel` `AuditEvent` for parity with admin cancellation and auditability; keep a web integration assertion for the new audit row, not only the service-level assertion.

## Task 5: Document and commit

- [ ] **Step 1: Update backlog docs**

Update `docs/wiki/tech-debt-backlog.md` TD-021 with the selected shared-service approach and note that admin's previous lock patch was only partial.

- [ ] **Step 2: Run full verification**

Run:

```bash
bin/rails test
```

Expected: all tests pass, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add app/services/clob/order_cancellation_service.rb \
        app/controllers/admin/orders_controller.rb app/controllers/web/orders_controller.rb \
        test/services/clob/order_cancellation_service_test.rb \
        test/integration/clob_orders_test.rb test/integration/web_orders_test.rb \
        docs/wiki/tech-debt-backlog.md
git commit -m "fix(clob): centralize order cancellation"
```
