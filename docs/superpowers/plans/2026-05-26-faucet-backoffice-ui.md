# Faucet Request Backoffice UI Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-26-faucet-backoffice-ui.md -->
<!-- Written AFTER the spec is approved. Describes HOW. -->

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use `- [ ]` for tracking.

**Goal:** Add a backoffice HTML interface for operators to view, approve, and reject faucet requests.

**Architecture:** Single `Backoffice::FaucetRequestsController` inheriting from `Backoffice::BaseController`, delegating approve/reject to the existing `WalletGrantService`. No new models, services, or migrations needed. Pattern is identical to `Backoffice::MarketsController`.

**Tech Stack:** Rails 8, Minitest, existing patterns (see `docs/INDEX.md`)

**Spec:** [docs/specs/2026-05-26-faucet-backoffice-ui.md](../../specs/2026-05-26-faucet-backoffice-ui.md)

---

## File Map

**Create:**
- `app/controllers/backoffice/faucet_requests_controller.rb`
- `app/views/backoffice/faucet_requests/index.html.erb`
- `test/integration/backoffice_faucet_requests_test.rb`

**Modify:**
- `config/routes.rb` — add backoffice faucet_requests routes
- `app/views/layouts/backoffice.html.erb` — add sidebar link

---

## Task 1: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1.1: Add routes**

In `config/routes.rb`, inside `namespace :backoffice`, add:

```ruby
resources :faucet_requests, only: [:index] do
  post :approve, on: :member
  post :reject,  on: :member
end
```

- [ ] **Step 1.2: Verify routes exist**

```bash
bin/rails routes | grep backoffice_faucet
```
Expected output includes:
```
approve_backoffice_faucet_request POST /backoffice/faucet_requests/:id/approve
reject_backoffice_faucet_request  POST /backoffice/faucet_requests/:id/reject
backoffice_faucet_requests        GET  /backoffice/faucet_requests
```

- [ ] **Step 1.3: Commit**

```bash
git add config/routes.rb
git commit -m "$(cat <<'EOF'
feat(faucet-ui): add backoffice faucet_requests routes

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Controller

**Files:**
- Create: `app/controllers/backoffice/faucet_requests_controller.rb`

- [ ] **Step 2.1: Write the failing integration test first**

```ruby
# test/integration/backoffice_faucet_requests_test.rb
require "test_helper"

class BackofficeFaucetRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @moderator = users(:moderator)
    @player = users(:player)

    @pending_request = FaucetRequest.create!(
      user: @player,
      amount_minor: 5_000
    )
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

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
bin/rails test test/integration/backoffice_faucet_requests_test.rb -v
```
Expected: FAIL with `uninitialized constant Backoffice::FaucetRequestsController`.

- [ ] **Step 2.3: Implement the controller**

```ruby
# app/controllers/backoffice/faucet_requests_controller.rb
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

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
bin/rails test test/integration/backoffice_faucet_requests_test.rb -v
```
Expected: 7 tests, 0 failures. (Will fail on missing view — proceed to Task 3.)

- [ ] **Step 2.5: Commit**

```bash
git add app/controllers/backoffice/faucet_requests_controller.rb \
        test/integration/backoffice_faucet_requests_test.rb
git commit -m "$(cat <<'EOF'
feat(faucet-ui): add Backoffice::FaucetRequestsController

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: View + sidebar link

**Files:**
- Create: `app/views/backoffice/faucet_requests/index.html.erb`
- Modify: `app/views/layouts/backoffice.html.erb`

- [ ] **Step 3.1: Create the index view**

```erb
<%# app/views/backoffice/faucet_requests/index.html.erb %>
<h1>Faucet Requests</h1>

<% if flash[:notice] %>
  <p class="notice"><%= flash[:notice] %></p>
<% end %>
<% if flash[:alert] %>
  <p class="alert"><%= flash[:alert] %></p>
<% end %>

<h2>Pending (<%= @pending.count %>)</h2>

<% if @pending.any? %>
  <table>
    <thead>
      <tr>
        <th>Player</th>
        <th>Amount (minor)</th>
        <th>Requested at</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <% @pending.each do |req| %>
        <tr>
          <td><%= req.user.email %></td>
          <td><%= req.amount_minor %></td>
          <td><%= req.created_at.strftime("%Y-%m-%d %H:%M") %></td>
          <td>
            <%= button_to "Approve",
                  approve_backoffice_faucet_request_path(req),
                  method: :post,
                  data: { testid: "approve-#{req.id}" } %>
            <%= button_to "Reject",
                  reject_backoffice_faucet_request_path(req),
                  method: :post,
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
    <thead>
      <tr>
        <th>Player</th>
        <th>Amount (minor)</th>
        <th>Status</th>
        <th>Reviewed by</th>
        <th>Processed at</th>
      </tr>
    </thead>
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

- [ ] **Step 3.2: Add sidebar link to backoffice layout**

In `app/views/layouts/backoffice.html.erb`, find the sidebar nav section and add:

```erb
<li><a href="/backoffice/faucet_requests" data-testid="nav-faucet-requests">Faucet Requests</a></li>
```

- [ ] **Step 3.3: Run the full integration test suite**

```bash
bin/rails test test/integration/backoffice_faucet_requests_test.rb -v
```
Expected: 7 tests, 0 failures.

- [ ] **Step 3.4: Run full suite to confirm no regressions**

```bash
bin/rails test
```
Expected: all tests pass, SimpleCov ≥ 90%.

- [ ] **Step 3.5: Commit**

```bash
git add app/views/backoffice/faucet_requests/index.html.erb \
        app/views/layouts/backoffice.html.erb
git commit -m "$(cat <<'EOF'
feat(faucet-ui): add faucet requests index view and sidebar link

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Update docs

- [ ] Append entry to `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` — move faucet backoffice UI from ⏳ Next to ✅ Done
- [ ] Commit: `docs: update INDEX and WORK_LOG after faucet-backoffice-ui`

---

## Self-Review Checklist
- [ ] Every spec invariant has a test (moderator can view/approve/reject, player blocked, double-process blocked)
- [ ] Approve writes AuditEvent and LedgerEntry (via `WalletGrantService`)
- [ ] Full test suite passes: `bin/rails test`
- [ ] No placeholder steps remain
