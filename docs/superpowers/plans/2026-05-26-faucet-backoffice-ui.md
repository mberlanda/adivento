# Faucet Request Backoffice UI Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-26-faucet-backoffice-ui.md -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a backoffice HTML interface for operators to view, approve, and reject faucet requests.
**Architecture:** Single `Backoffice::FaucetRequestsController` inheriting from `Backoffice::BaseController`, delegating approve/reject to the existing `WalletGrantService`. No new models, services, or migrations needed. Pattern is identical to `Backoffice::MarketsController`.
**Tech Stack:** Rails 8, Minitest, ERB views, existing Backoffice::BaseController
**Spec:** [docs/specs/2026-05-26-faucet-backoffice-ui.md](../../specs/2026-05-26-faucet-backoffice-ui.md)

---

## File Map

**Create:**
- `app/controllers/backoffice/faucet_requests_controller.rb`
- `app/views/backoffice/faucet_requests/index.html.erb`
- `test/integration/backoffice_faucet_requests_test.rb`

**Modify:**
- `config/routes.rb` — add backoffice faucet_requests routes

---

## Task 1: Controller + Routes

**Files:**
- Create: `app/controllers/backoffice/faucet_requests_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1 — Write the failing test**

Create `test/integration/backoffice_faucet_requests_test.rb`:

```ruby
require "test_helper"

class BackofficeFaucetRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @moderator = users(:moderator)
    @player = users(:player)
    @pending_request = FaucetRequest.create!(user: @player, amount_minor: 5_000)
  end

  def sign_in(user)
    post "/signin", params: { email: user.email, password: "password123" }
  end

  test "moderator can view faucet requests list" do
    sign_in @moderator
    get "/backoffice/faucet_requests"
    assert_response :success
  end

  test "player cannot access faucet requests list" do
    sign_in @player
    get "/backoffice/faucet_requests"
    assert_response :redirect
  end

  test "unauthenticated request is redirected" do
    get "/backoffice/faucet_requests"
    assert_response :redirect
  end

  test "moderator can approve a pending request" do
    sign_in @moderator
    initial_balance = @player.wallet.available_minor
    post "/backoffice/faucet_requests/#{@pending_request.id}/approve"
    assert_response :redirect
    follow_redirect!
    assert_response :success
    @pending_request.reload
    assert_predicate @pending_request, :approved?
    assert_equal initial_balance + 5_000, @player.wallet.reload.available_minor
    assert AuditEvent.where(action: "faucet_request.approve", target_id: @pending_request.id).exists?
  end

  test "moderator can reject a pending request" do
    sign_in @moderator
    post "/backoffice/faucet_requests/#{@pending_request.id}/reject"
    assert_response :redirect
    @pending_request.reload
    assert_predicate @pending_request, :rejected?
  end

  test "cannot approve an already-approved request" do
    @pending_request.update!(status: :approved, reviewed_by: @admin)
    sign_in @moderator
    initial_balance = @player.wallet.reload.available_minor
    post "/backoffice/faucet_requests/#{@pending_request.id}/approve"
    assert_response :redirect
    assert_equal initial_balance, @player.wallet.reload.available_minor
  end

  test "cannot reject an already-rejected request" do
    @pending_request.update!(status: :rejected, reviewed_by: @admin)
    sign_in @moderator
    post "/backoffice/faucet_requests/#{@pending_request.id}/reject"
    assert_response :redirect
    follow_redirect!
    assert_match "already been processed", flash[:alert]
  end
end
```

- [ ] **Step 2 — Run test, verify it fails**

```bash
bin/rails test test/integration/backoffice_faucet_requests_test.rb -v
```

Expected: FAIL with `uninitialized constant Backoffice::FaucetRequestsController` (routing error before controller exists).

- [ ] **Step 3 — Implement controller + routes**

In `config/routes.rb`, inside `namespace :backoffice`, add:

```ruby
resources :faucet_requests, only: [:index] do
  post :approve, on: :member
  post :reject,  on: :member
end
```

Create `app/controllers/backoffice/faucet_requests_controller.rb`:

```ruby
module Backoffice
  class FaucetRequestsController < BaseController
    before_action -> { require_permission!("wallet.faucet.review") }

    def index
      @pending = FaucetRequest.pending
                              .includes(:user)
                              .order(created_at: :asc)
      @processed = FaucetRequest.where.not(status: :pending)
                                .includes(:user, :reviewed_by)
                                .order(updated_at: :desc)
                                .limit(50)
    end

    def approve
      faucet_request = FaucetRequest.find(params[:id])
      unless faucet_request.pending?
        return redirect_to backoffice_faucet_requests_path,
                           alert: "Request has already been processed"
      end
      WalletGrantService.approve!(faucet_request: faucet_request, actor: current_user)
      redirect_to backoffice_faucet_requests_path, notice: "Faucet request approved"
    end

    def reject
      faucet_request = FaucetRequest.find(params[:id])
      unless faucet_request.pending?
        return redirect_to backoffice_faucet_requests_path,
                           alert: "Request has already been processed"
      end
      WalletGrantService.reject!(faucet_request: faucet_request, actor: current_user)
      redirect_to backoffice_faucet_requests_path, notice: "Faucet request rejected"
    end
  end
end
```

- [ ] **Step 4 — Run test, verify it passes**

```bash
bin/rails test test/integration/backoffice_faucet_requests_test.rb -v
```

Expected: tests pass (or fail only on missing template — proceed to Task 2).

- [ ] **Step 5 — Commit**

```bash
git add app/controllers/backoffice/faucet_requests_controller.rb \
        test/integration/backoffice_faucet_requests_test.rb \
        config/routes.rb
git commit -m "$(cat <<'EOF'
feat(faucet-ui): add Backoffice::FaucetRequestsController and routes

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Index View

**Files:**
- Create: `app/views/backoffice/faucet_requests/index.html.erb`

- [ ] **Step 1 — Write the failing test**

The test from Task 1 (`"moderator can view faucet requests list"`) will fail with `ActionView::MissingTemplate` if the view does not exist. No new test code is needed.

- [ ] **Step 2 — Run test, verify it fails**

```bash
bin/rails test test/integration/backoffice_faucet_requests_test.rb -v
```

Expected: FAIL — `ActionView::MissingTemplate` for `backoffice/faucet_requests/index`.

- [ ] **Step 3 — Implement the view**

Create `app/views/backoffice/faucet_requests/index.html.erb`:

```erb
<%# app/views/backoffice/faucet_requests/index.html.erb %>
<h1>Faucet Requests</h1>

<% if flash[:notice] %><p class="notice"><%= flash[:notice] %></p><% end %>
<% if flash[:alert] %><p class="alert"><%= flash[:alert] %></p><% end %>

<h2>Pending (<%= @pending.count %>)</h2>

<% if @pending.any? %>
  <table>
    <thead><tr><th>Player</th><th>Amount (minor)</th><th>Requested at</th><th>Actions</th></tr></thead>
    <tbody>
      <% @pending.each do |req| %>
        <tr>
          <td><%= req.user.email %></td>
          <td><%= req.amount_minor %></td>
          <td><%= req.created_at.strftime("%Y-%m-%d %H:%M") %></td>
          <td>
            <%= button_to "Approve", approve_backoffice_faucet_request_path(req), method: :post,
                  data: { testid: "approve-#{req.id}" } %>
            <%= button_to "Reject", reject_backoffice_faucet_request_path(req), method: :post,
                  data: { testid: "reject-#{req.id}" } %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% else %>
  <p>No pending faucet requests.</p>
<% end %>

<h2>Recently Processed</h2>

<% if @processed.any? %>
  <table>
    <thead><tr><th>Player</th><th>Amount (minor)</th><th>Status</th><th>Reviewed by</th><th>Processed at</th></tr></thead>
    <tbody>
      <% @processed.each do |req| %>
        <tr>
          <td><%= req.user.email %></td>
          <td><%= req.amount_minor %></td>
          <td><%= req.status %></td>
          <td><%= req.reviewed_by&.email %></td>
          <td><%= req.updated_at.strftime("%Y-%m-%d %H:%M") %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% else %>
  <p>No processed requests.</p>
<% end %>
```

- [ ] **Step 4 — Run test, verify it passes**

```bash
bin/rails test test/integration/backoffice_faucet_requests_test.rb -v
```

Expected: 7 tests, 0 failures.

- [ ] **Step 5 — Commit**

```bash
git add app/views/backoffice/faucet_requests/index.html.erb
git commit -m "$(cat <<'EOF'
feat(faucet-ui): add faucet requests index view

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Integration Tests

> **Note (retrospective):** Tests were written as part of Task 1 (TDD — tests first, then controller). This task is a verification checkpoint confirming full suite health.

**Files:**
- Test: `test/integration/backoffice_faucet_requests_test.rb`

- [ ] **Step 1 — Write the failing test**

Already written in Task 1, Step 1. No new test code.

- [ ] **Step 2 — Run test, verify it fails**

Already executed in Task 1, Step 2.

- [ ] **Step 3 — Implement**

Already implemented in Tasks 1 and 2.

- [ ] **Step 4 — Run full suite to confirm no regressions**

```bash
bin/rails test
```

Expected: all tests pass, SimpleCov ≥ 90%.

- [ ] **Step 5 — Commit**

No additional commit needed (tests committed with controller in Task 1, Step 5).

---

## Task 4: Update Docs

**Files:**
- Modify: `docs/WORK_LOG.md`
- Modify: `docs/INDEX.md`

- [ ] **Step 1 — Write the failing test**

No test applicable for doc updates.

- [ ] **Step 2 — Run test, verify it fails**

N/A.

- [ ] **Step 3 — Implement**

Prepend a dated entry to `docs/WORK_LOG.md`:

```
## 2026-05-26 — faucet-backoffice-ui

Built `Backoffice::FaucetRequestsController` with index/approve/reject actions guarded by
`wallet.faucet.review` permission. Delegates state changes to `WalletGrantService`. Added
index view with pending and processed tables. 7 integration tests covering access control
and idempotency guard.

Key files:
- app/controllers/backoffice/faucet_requests_controller.rb
- app/views/backoffice/faucet_requests/index.html.erb
- test/integration/backoffice_faucet_requests_test.rb
```

Update `docs/INDEX.md` — move faucet backoffice UI item from TODO/Next to Done.

- [ ] **Step 4 — Run test, verify it passes**

N/A.

- [ ] **Step 5 — Commit**

```bash
git add docs/WORK_LOG.md docs/INDEX.md
git commit -m "$(cat <<'EOF'
docs: update INDEX and WORK_LOG after faucet-backoffice-ui

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist

- [ ] Every spec invariant has a test (moderator can view/approve/reject, player blocked, unauthenticated blocked, double-process blocked)
- [ ] Approve writes AuditEvent and LedgerEntry (delegated to `WalletGrantService`)
- [ ] Reject writes AuditEvent (delegated to `WalletGrantService`)
- [ ] Already-processed redirect uses `alert: "Request has already been processed"`
- [ ] Full test suite passes: `bin/rails test`
- [ ] SimpleCov ≥ 90%
- [ ] No placeholder steps remain
