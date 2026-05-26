# Backoffice UI Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full template CRUD (edit + soft-delete) and a complete backoffice markets section (list, show, create, open, settle) so operators can manage the platform through the HTML backoffice without touching JSON APIs.

**Architecture:** All new backoffice controllers follow the existing `Backoffice::BaseController` pattern (session auth + role check). Markets in the backoffice render HTML forms and redirect on success. The settlement action delegates business logic to `SettlementService` if it exists, otherwise falls back to the direct `market.update!` approach already in `Admin::MarketsController#settle`.

**Tech Stack:** Rails 8, ERB views, existing CSS in `backoffice.html.erb` layout, Minitest integration tests.

---

## File Map

**Create:**
- `app/controllers/backoffice/markets_controller.rb`
- `app/views/backoffice/markets/index.html.erb`
- `app/views/backoffice/markets/show.html.erb`
- `app/views/backoffice/templates/_form.html.erb`
- `app/views/backoffice/templates/edit.html.erb`

**Modify:**
- `app/controllers/backoffice/templates_controller.rb` — add `edit`, `update`, `destroy`
- `app/views/backoffice/templates/index.html.erb` — add Edit / Deactivate links per card
- `config/routes.rb` — full resources for backoffice/templates + backoffice/markets with settle member action
- `app/views/layouts/backoffice.html.erb` — add Markets link in sidebar
- `test/integration/backoffice_management_test.rb` — extend with new actions

---

## Task 1: Template edit + update + deactivate

**Files:**
- Modify: `app/controllers/backoffice/templates_controller.rb`
- Create: `app/views/backoffice/templates/_form.html.erb`
- Create: `app/views/backoffice/templates/edit.html.erb`
- Modify: `app/views/backoffice/templates/index.html.erb`
- Modify: `config/routes.rb`

- [ ] **Step 1.1: Update routes for templates**

Open `config/routes.rb`. Replace:
```ruby
resources :templates, only: [:index, :create] do
  post :create_market, on: :member
end
```
With:
```ruby
resources :templates, only: [:index, :create, :edit, :update, :destroy] do
  post :create_market, on: :member
end
```

- [ ] **Step 1.2: Add edit, update, destroy actions to templates_controller**

Replace the entire `app/controllers/backoffice/templates_controller.rb` with:
```ruby
module Backoffice
  class TemplatesController < BaseController
    before_action -> { require_permission!("template.manage") }
    before_action :set_template, only: [:edit, :update, :destroy, :create_market]

    def index
      @templates = MarketTemplate.order(:name)
    end

    def create
      template = MarketTemplate.new(template_params)
      template.default_legs = params[:default_legs].to_s.split(",").map(&:strip).reject(&:blank?)

      if template.save
        AuditEvent.create!(
          actor: current_user,
          action: "template.create",
          target_type: "MarketTemplate",
          target_id: template.id,
          reason: params[:reason],
          metadata: {}
        )
        redirect_to backoffice_templates_path, notice: "Template created"
      else
        redirect_to backoffice_templates_path, alert: template.errors.full_messages.join(", ")
      end
    end

    def edit
    end

    def update
      legs = params[:default_legs].to_s.split(",").map(&:strip).reject(&:blank?)
      if @template.update(template_params.merge(default_legs: legs))
        AuditEvent.create!(
          actor: current_user,
          action: "template.update",
          target_type: "MarketTemplate",
          target_id: @template.id,
          reason: params[:reason],
          metadata: {}
        )
        redirect_to backoffice_templates_path, notice: "Template updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @template.update!(active: false)
      AuditEvent.create!(
        actor: current_user,
        action: "template.deactivate",
        target_type: "MarketTemplate",
        target_id: @template.id,
        reason: params[:reason],
        metadata: {}
      )
      redirect_to backoffice_templates_path, notice: "Template deactivated"
    end

    def create_market
      market = MarketFromTemplateService.create!(
        template: @template,
        question: params[:question],
        description: params[:description],
        creator: current_user
      )
      redirect_to backoffice_market_path(market), notice: "Market created from template"
    end

    private

    def set_template
      @template = MarketTemplate.find(params[:id])
    end

    def template_params
      params.permit(:key, :name, :description, :default_duration_hours, :active)
    end
  end
end
```

- [ ] **Step 1.3: Create the shared form partial**

Create `app/views/backoffice/templates/_form.html.erb`:
```erb
<%= form_with model: [:backoffice, template], html: { data: { testid: "template-form" } } do |f| %>
  <p><label>Key</label><br><%= f.text_field :key, required: true, data: { testid: "template-key" } %></p>
  <p><label>Name</label><br><%= f.text_field :name, required: true, data: { testid: "template-name" } %></p>
  <p><label>Description</label><br><%= f.text_area :description, data: { testid: "template-description" } %></p>
  <p><label>Default Legs (comma separated)</label><br>
     <%= text_field_tag :default_legs, template.legs.join(", "), data: { testid: "template-default-legs" } %></p>
  <p><label>Default Duration (hours)</label><br><%= f.number_field :default_duration_hours, min: 1, data: { testid: "template-duration-hours" } %></p>
  <p><label>Active</label> <%= f.check_box :active, data: { testid: "template-active" } %></p>
  <p><label>Reason</label><br><%= text_field_tag :reason, nil, required: true, data: { testid: "template-reason" } %></p>
  <p><%= f.submit data: { testid: "template-submit" } %></p>
<% end %>
```

- [ ] **Step 1.4: Create the edit view**

Create `app/views/backoffice/templates/edit.html.erb`:
```erb
<h1>Edit Template: <%= @template.name %></h1>
<div class="panel">
  <%= render "form", template: @template %>
</div>
<p><%= link_to "Back to templates", backoffice_templates_path %></p>
```

- [ ] **Step 1.5: Update index view to add Edit / Deactivate links**

Replace `app/views/backoffice/templates/index.html.erb` with:
```erb
<h1 data-testid="backoffice-templates-title">Market Templates</h1>

<div class="panel">
  <h3>Create Template</h3>
  <%= form_with url: backoffice_templates_path, method: :post, html: { data: { testid: "create-template-form" } } do |f| %>
    <p><label>Key</label><br><%= text_field_tag :key, nil, required: true, data: { testid: "template-key" } %></p>
    <p><label>Name</label><br><%= text_field_tag :name, nil, required: true, data: { testid: "template-name" } %></p>
    <p><label>Description</label><br><%= text_area_tag :description, nil, data: { testid: "template-description" } %></p>
    <p><label>Default Legs (comma separated)</label><br><%= text_field_tag :default_legs, "YES,NO", data: { testid: "template-default-legs" } %></p>
    <p><label>Default Duration (hours)</label><br><%= number_field_tag :default_duration_hours, 24, min: 1, data: { testid: "template-duration-hours" } %></p>
    <p><label>Active</label> <%= check_box_tag :active, true, true, data: { testid: "template-active" } %></p>
    <p><label>Reason</label><br><%= text_field_tag :reason, nil, required: true, data: { testid: "template-reason" } %></p>
    <p><%= f.submit "Create template", data: { testid: "template-submit" } %></p>
  <% end %>
</div>

<div class="panel">
  <h3>Available Templates</h3>
  <% @templates.each do |template| %>
    <article style="padding:12px;border:1px solid #33434c;border-radius:10px;margin-bottom:10px;" data-testid="template-card-<%= template.id %>">
      <div style="display:flex;justify-content:space-between;align-items:flex-start;">
        <div>
          <strong><%= template.name %></strong> (<%= template.key %>)
          <% unless template.active? %>
            <span style="color:#f0bc5c;font-size:0.8em;margin-left:8px;">[INACTIVE]</span>
          <% end %>
          <p><%= template.description %></p>
          <p>Legs: <%= template.legs.join(", ") %></p>
        </div>
        <div style="display:flex;gap:8px;">
          <%= link_to "Edit", edit_backoffice_template_path(template),
                style: "background:#2a3a44;color:#edf3f5;padding:6px 12px;border-radius:6px;text-decoration:none;font-size:0.85em;",
                data: { testid: "edit-template-#{template.id}" } %>
          <%= form_with url: backoffice_template_path(template), method: :delete,
                html: { style: "display:inline;", data: { testid: "deactivate-template-form-#{template.id}" } } do |f| %>
            <%= hidden_field_tag :reason, "operator deactivation" %>
            <%= f.submit "Deactivate", style: "background:#4a2222;color:#edf3f5;padding:6px 12px;",
                  data: { testid: "deactivate-template-#{template.id}", confirm: "Deactivate this template?" },
                  disabled: !template.active? %>
          <% end %>
        </div>
      </div>
      <% if template.active? %>
        <%= form_with url: create_market_backoffice_template_path(template), method: :post,
              html: { data: { testid: "create-market-from-template-form-#{template.id}" } } do |f| %>
          <p><label>Question</label><br><%= text_field_tag :question, nil, required: true, data: { testid: "create-market-question-#{template.id}" } %></p>
          <p><label>Description</label><br><%= text_area_tag :description, nil, required: true, data: { testid: "create-market-description-#{template.id}" } %></p>
          <p><%= f.submit "Create market from template", data: { testid: "create-market-submit-#{template.id}" } %></p>
        <% end %>
      <% end %>
    </article>
  <% end %>
</div>
```

- [ ] **Step 1.6: Run tests to verify existing tests still pass**

```bash
bin/rails test test/integration/backoffice_management_test.rb -v
```
Expected: all existing tests PASS.

- [ ] **Step 1.7: Commit**

```bash
git add app/controllers/backoffice/templates_controller.rb \
        app/views/backoffice/templates/ \
        config/routes.rb
git commit -m "feat(backoffice): add template edit, update, and deactivate actions"
```

---

## Task 2: Backoffice Markets section

**Files:**
- Create: `app/controllers/backoffice/markets_controller.rb`
- Create: `app/views/backoffice/markets/index.html.erb`
- Create: `app/views/backoffice/markets/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/backoffice.html.erb`

- [ ] **Step 2.1: Add backoffice markets routes**

In `config/routes.rb`, inside the `namespace :backoffice` block, add after `resources :templates ...`:
```ruby
resources :markets, only: [:index, :show, :create, :update] do
  post :open, on: :member
  post :settle, on: :member
end
```

- [ ] **Step 2.2: Create backoffice markets controller**

Create `app/controllers/backoffice/markets_controller.rb`:
```ruby
module Backoffice
  class MarketsController < BaseController
    before_action -> { require_permission!("market.read") }
    before_action :set_market, only: [:show, :update, :open, :settle]

    def index
      @markets = Market.includes(:market_legs, :created_by).order(created_at: :desc)
    end

    def show
      @bets = @market.bets.includes(:user, :market_leg).order(created_at: :desc)
    end

    def create
      require_permission!("market.create")
      return if performed?

      market = Market.new(market_create_params.merge(created_by: current_user))
      if market.save
        legs = params[:legs].to_s.split(",").map(&:strip).reject(&:blank?)
        legs = %w[YES NO] if legs.empty?
        legs.each do |label|
          market.market_legs.find_or_create_by!(label: label) do |leg|
            leg.odds_minor = 5000
            leg.active = true
          end
        end
        HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: "market.create")
        AuditEvent.create!(
          actor: current_user,
          action: "market.create",
          target_type: "Market",
          target_id: market.id,
          metadata: {}
        )
        redirect_to backoffice_market_path(market), notice: "Market created"
      else
        @markets = Market.includes(:market_legs, :created_by).order(created_at: :desc)
        flash.now[:alert] = market.errors.full_messages.join(", ")
        render :index, status: :unprocessable_entity
      end
    end

    def open
      require_permission!("market.update")
      return if performed?

      unless @market.draft?
        return redirect_to backoffice_market_path(@market), alert: "Market is not in draft state"
      end

      @market.update!(status: :open)
      HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: "market.open")
      AuditEvent.create!(
        actor: current_user,
        action: "market.open",
        target_type: "Market",
        target_id: @market.id,
        metadata: {}
      )
      redirect_to backoffice_market_path(@market), notice: "Market is now open"
    end

    def settle
      require_permission!("market.settle")
      return if performed?

      outcome = params[:outcome].to_s.upcase
      unless @market.market_legs.where(label: outcome).exists?
        return redirect_to backoffice_market_path(@market), alert: "Invalid outcome: #{outcome}"
      end

      unless @market.open?
        return redirect_to backoffice_market_path(@market), alert: "Market must be open to settle"
      end

      if defined?(SettlementService)
        SettlementService.settle!(market: @market, outcome: outcome, actor: current_user)
      else
        @market.update!(status: :settled, settled_outcome: outcome, settled_by: current_user)
        HotStorage::MarketSnapshotProjector.project!(market: @market.reload, reason: "market.settle")
        AuditEvent.create!(
          actor: current_user,
          action: "market.settle",
          target_type: "Market",
          target_id: @market.id,
          reason: params[:reason],
          metadata: { outcome: outcome }
        )
      end

      redirect_to backoffice_market_path(@market), notice: "Market settled: #{outcome}"
    end

    private

    def set_market
      @market = Market.includes(:market_legs).find(params[:id])
    end

    def market_create_params
      params.permit(:question, :description, :mechanism_type, :fee_bps, :liability_cap_minor)
    end
  end
end
```

- [ ] **Step 2.3: Create markets index view**

Create `app/views/backoffice/markets/index.html.erb`:
```erb
<h1 data-testid="backoffice-markets-title">Markets</h1>

<div class="panel">
  <h3>Create Market</h3>
  <%= form_with url: backoffice_markets_path, method: :post, html: { data: { testid: "create-market-form" } } do |f| %>
    <p><label>Question</label><br><%= text_field_tag :question, nil, required: true, data: { testid: "market-question" } %></p>
    <p><label>Description</label><br><%= text_area_tag :description, nil, required: true, data: { testid: "market-description" } %></p>
    <p><label>Legs (comma separated)</label><br><%= text_field_tag :legs, "YES,NO", data: { testid: "market-legs" } %></p>
    <p><label>Fee (basis points, default 100 = 1%)</label><br><%= number_field_tag :fee_bps, 100, min: 0, data: { testid: "market-fee-bps" } %></p>
    <p><label>Liability Cap (minor units, default 100000)</label><br><%= number_field_tag :liability_cap_minor, 100000, min: 1, data: { testid: "market-liability-cap" } %></p>
    <%= hidden_field_tag :mechanism_type, "fixed_odds" %>
    <p><%= submit_tag "Create market", data: { testid: "market-create-submit" } %></p>
  <% end %>
</div>

<div class="panel">
  <h3>All Markets</h3>
  <table data-testid="markets-table">
    <thead>
      <tr>
        <th>ID</th>
        <th>Question</th>
        <th>Status</th>
        <th>Created by</th>
        <th>Created at</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <% @markets.each do |market| %>
        <tr data-testid="market-row-<%= market.id %>">
          <td><%= market.id %></td>
          <td><%= link_to market.question.truncate(60), backoffice_market_path(market) %></td>
          <td><span style="text-transform:uppercase;font-size:0.8em;"><%= market.status %></span></td>
          <td><%= market.created_by.email %></td>
          <td><%= market.created_at.strftime("%Y-%m-%d %H:%M") %></td>
          <td>
            <%= link_to "View", backoffice_market_path(market),
                  style: "color:#f0bc5c;text-decoration:none;font-size:0.85em;" %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
  <% if @markets.empty? %>
    <p style="color:#9fb2b8;">No markets yet. Create one above or via a template.</p>
  <% end %>
</div>
```

- [ ] **Step 2.4: Create markets show view**

Create `app/views/backoffice/markets/show.html.erb`:
```erb
<h1 data-testid="backoffice-market-title"><%= @market.question %></h1>
<p style="color:#9fb2b8;"><%= @market.description %></p>

<div class="panel">
  <h3>Status</h3>
  <p>Status: <strong><%= @market.status.upcase %></strong></p>
  <p>Mechanism: <%= @market.mechanism_type %> | Fee: <%= @market.fee_bps %>bps | Liability cap: <%= @market.liability_cap_minor %></p>
  <% if @market.settled? %>
    <p>Settled outcome: <strong><%= @market.settled_outcome %></strong></p>
  <% end %>

  <% if @market.draft? %>
    <%= form_with url: open_backoffice_market_path(@market), method: :post,
          html: { style: "display:inline;", data: { testid: "open-market-form" } } do |f| %>
      <%= f.submit "Open market for betting", data: { testid: "open-market-submit" } %>
    <% end %>
  <% end %>

  <% if @market.open? %>
    <div style="margin-top:16px;">
      <h4>Settle market</h4>
      <%= form_with url: settle_backoffice_market_path(@market), method: :post,
            html: { data: { testid: "settle-market-form" } } do |f| %>
        <p>
          <label>Winning outcome</label>
          <select name="outcome" data-testid="settle-outcome">
            <% @market.market_legs.each do |leg| %>
              <option value="<%= leg.label %>"><%= leg.label %></option>
            <% end %>
          </select>
        </p>
        <p><label>Reason</label><br><%= text_field_tag :reason, nil, data: { testid: "settle-reason" } %></p>
        <%= f.submit "Settle market", style: "background:#4a2222;",
              data: { testid: "settle-market-submit", confirm: "This will settle all bets. Proceed?" } %>
      <% end %>
    </div>
  <% end %>
</div>

<div class="panel">
  <h3>Lines / Legs</h3>
  <table>
    <thead><tr><th>Label</th><th>Odds (minor)</th><th>Active</th></tr></thead>
    <tbody>
      <% @market.market_legs.each do |leg| %>
        <tr data-testid="leg-row-<%= leg.id %>">
          <td><strong><%= leg.label %></strong></td>
          <td><%= leg.odds_minor %></td>
          <td><%= leg.active? ? "Yes" : "No" %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>

<div class="panel">
  <h3>Bets (<%= @bets.size %>)</h3>
  <% if @bets.any? %>
    <table>
      <thead>
        <tr>
          <th>ID</th><th>User</th><th>Leg</th><th>Stake</th><th>Payout</th><th>Status</th>
        </tr>
      </thead>
      <tbody>
        <% @bets.each do |bet| %>
          <tr data-testid="bet-row-<%= bet.id %>">
            <td><%= bet.id %></td>
            <td><%= bet.user.email %></td>
            <td><%= bet.market_leg.label %></td>
            <td><%= bet.stake_minor %></td>
            <td><%= bet.potential_payout_minor %></td>
            <td><%= bet.status %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  <% else %>
    <p style="color:#9fb2b8;">No bets placed yet.</p>
  <% end %>
</div>

<p><%= link_to "Back to markets", backoffice_markets_path %></p>
```

- [ ] **Step 2.5: Add Markets link to backoffice sidebar**

In `app/views/layouts/backoffice.html.erb`, add after `<a href="/backoffice/templates">Templates</a>`:
```erb
<a href="/backoffice/markets">Markets</a>
```

- [ ] **Step 2.6: Run the test suite**

```bash
bin/rails test -v 2>&1 | tail -20
```
Expected: no failures related to routing or templates.

- [ ] **Step 2.7: Commit**

```bash
git add app/controllers/backoffice/markets_controller.rb \
        app/views/backoffice/markets/ \
        app/views/layouts/backoffice.html.erb \
        config/routes.rb
git commit -m "feat(backoffice): add markets section with list, show, create, open, and settle"
```

---

## Task 3: Integration tests for new backoffice actions

**Files:**
- Modify: `test/integration/backoffice_management_test.rb`

- [ ] **Step 3.1: Add template edit/update/deactivate tests**

Append to `test/integration/backoffice_management_test.rb`:

```ruby
  test "admin can edit a template" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    template = market_templates(:binary)

    get "/backoffice/templates/#{template.id}/edit"
    assert_response :success
    assert_match "Edit Template", response.body
  end

  test "admin can update a template" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    template = market_templates(:binary)

    patch "/backoffice/templates/#{template.id}", params: {
      key: template.key,
      name: "Updated Binary",
      description: "Updated desc",
      default_legs: "YES,NO",
      default_duration_hours: 48,
      active: true,
      reason: "name correction"
    }

    assert_response :redirect
    template.reload
    assert_equal "Updated Binary", template.name
    assert AuditEvent.exists?(action: "template.update", target_id: template.id)
  end

  test "admin can deactivate a template" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    template = market_templates(:binary)

    delete "/backoffice/templates/#{template.id}", params: { reason: "retiring template" }

    assert_response :redirect
    template.reload
    assert_not template.active?
    assert AuditEvent.exists?(action: "template.deactivate", target_id: template.id)
  end

  test "admin can list markets in backoffice" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    get "/backoffice/markets"

    assert_response :success
    assert_match "Markets", response.body
  end

  test "admin can create a market in backoffice" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }

    assert_difference("Market.count", 1) do
      post "/backoffice/markets", params: {
        question: "Will it snow tomorrow?",
        description: "Weather prediction",
        legs: "YES,NO",
        fee_bps: 100,
        liability_cap_minor: 50000,
        mechanism_type: "fixed_odds"
      }
    end

    market = Market.last
    assert_response :redirect
    assert market.market_legs.count >= 2
    assert AuditEvent.exists?(action: "market.create", target_id: market.id)
  end

  test "admin can open a draft market" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    market = markets(:draft_market)

    post "/backoffice/markets/#{market.id}/open"

    assert_response :redirect
    market.reload
    assert_predicate market, :open?
  end

  test "admin can view market detail in backoffice" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    market = markets(:open_market)

    get "/backoffice/markets/#{market.id}"

    assert_response :success
    assert_match market.question, response.body
  end

  test "admin can settle an open market" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    market = markets(:open_market)

    post "/backoffice/markets/#{market.id}/settle", params: {
      outcome: "YES",
      reason: "result confirmed"
    }

    assert_response :redirect
    market.reload
    assert_predicate market, :settled?
    assert_equal "YES", market.settled_outcome
  end

  test "player cannot access backoffice markets" do
    post "/signin", params: { email: users(:player).email, password: "password123" }
    get "/backoffice/markets"

    assert_response :redirect
  end
```

- [ ] **Step 3.2: Run new tests**

```bash
bin/rails test test/integration/backoffice_management_test.rb -v
```
Expected: all tests PASS including the newly added ones.

- [ ] **Step 3.3: Run full test suite**

```bash
bin/rails test -v 2>&1 | tail -30
```
Expected: no failures.

- [ ] **Step 3.4: Commit**

```bash
git add test/integration/backoffice_management_test.rb
git commit -m "test(backoffice): integration coverage for template CRUD and markets section"
```

---

## Self-Review Checklist

- [x] Template edit/update/destroy wired in routes + controller
- [x] Template form partial shared between create (index inline) and edit
- [x] Deactivation sets active:false, not hard delete
- [x] AuditEvent written for every write action
- [x] Markets backoffice: index, show, create, open, settle
- [x] create_market from template now redirects to backoffice (not web surface)
- [x] Settlement delegates to SettlementService if defined (forward-compatible)
- [x] Sidebar updated with Markets link
- [x] Integration tests cover all new actions and RBAC
- [x] Routes include both template full CRUD and markets with open/settle members
