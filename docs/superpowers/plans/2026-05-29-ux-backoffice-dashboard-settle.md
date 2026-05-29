# UX — Backoffice Dashboard & Settlement Improvements

<!-- File location: docs/superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md -->

**Goal:** Close the wireframe gaps in the backoffice: upgrade the dashboard from 3 plain text stats to a full operator "mission control" (4 stat boxes, markets-needing-attention table, inline pending faucet card, recent audit events); add a two-step destructive confirmation guard to the settle action; and improve the faucet requests page with status filter tabs, current balance column, and reason column.

**Architecture:** View-only changes for dashboard and faucet. The settle two-step confirmation is a view-level JS guard (no new routes). The dashboard controller needs a few extra queries: house liability, 24h volume, closed markets awaiting settlement, recent audit events. No migrations.

**Tech Stack:** Rails 8 ERB, vanilla JS, existing backoffice CSS (dark + gold theme), Minitest.

**Spec:** `docs/design/02-flows-and-use-cases.md` §14 §17, `docs/design/wireframes/v1/wireframes-backoffice.jsx` (`WFBo.Dashboard`, `WFBo.Settle`, `WFBo.Faucet`), `docs/design/03-settlement-and-resolution.md`.

---

## File Map

**Modify:**
- `app/views/backoffice/dashboard/index.html.erb` — 4 stat boxes, attention table, faucet card, audit events
- `app/controllers/backoffice/dashboard_controller.rb` — add queries for liability, volume, closed markets, recent audit events
- `app/views/backoffice/markets/show.html.erb` — two-step settle confirmation with payout preview
- `app/views/backoffice/faucet_requests/index.html.erb` — status filter tabs, balance + reason columns

---

## Task 1: Dashboard — 4-stat overview + attention table + faucet/audit cards

**Files:**
- Modify: `app/views/backoffice/dashboard/index.html.erb`
- Modify: `app/controllers/backoffice/dashboard_controller.rb`
- Test: `test/integration/backoffice/dashboard_test.rb`

- [ ] **Step 1.1: Extend the dashboard controller**

```ruby
# app/controllers/backoffice/dashboard_controller.rb
def index
  @open_markets         = Market.open.count
  @pending_faucet_requests = FaucetRequest.pending.count
  @active_templates     = MarketTemplate.active.count
  @house_liability      = compute_house_liability   # see below
  @daily_volume         = compute_daily_volume
  @closed_markets       = Market.closed.order(close_at: :desc).limit(5)
  @draft_markets        = Market.draft.order(created_at: :desc).limit(3)
  @recent_faucets       = FaucetRequest.pending.includes(:user).order(created_at: :desc).limit(3)
  @recent_audit_events  = AuditEvent.order(created_at: :desc).limit(5)
end

private

def compute_house_liability
  # Sum of potential payouts on open fixed-odds bets (worst case per market)
  Bet.open.joins(:market).where(markets: { mechanism_type: 'fixed_odds' })
     .sum(:potential_payout_minor)
rescue StandardError
  0
end

def compute_daily_volume
  LedgerEntry.where(entry_type: %w[BET_STAKE LMSR_STAKE PARIMUTUEL_STAKE])
             .where('created_at >= ?', 24.hours.ago)
             .sum(:amount_minor)
rescue StandardError
  0
end
```

- [ ] **Step 1.2: Write a failing dashboard test**

```ruby
# test/integration/backoffice/dashboard_test.rb
test "GET /backoffice renders stat boxes" do
  post "/signin", params: { email: users(:admin).email, password: "password123" }
  get "/backoffice"
  assert_response :success
  assert_select "[data-testid='dashboard-stat-open-markets']"
  assert_select "[data-testid='dashboard-stat-liability']"
  assert_select "[data-testid='dashboard-attention-table']"
end
```

- [ ] **Step 1.3: Run test to verify it fails**

```bash
bin/rails test test/integration/backoffice/dashboard_test.rb -v
```
Expected: FAIL (elements not in current view)

- [ ] **Step 1.4: Rewrite the dashboard view**

Replace `app/views/backoffice/dashboard/index.html.erb`:

```erb
<h1>Operations dashboard</h1>
<p style="color:var(--muted);margin-bottom:16px;">House exposure, open markets &amp; pending actions</p>

<%# 4-stat grid %>
<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px;">
  <div class="panel" style="padding:14px 16px;" data-testid="dashboard-stat-open-markets">
    <div style="font-size:0.72rem;font-weight:600;letter-spacing:.05em;text-transform:uppercase;color:var(--muted);margin-bottom:4px;">Open markets</div>
    <div style="font-size:1.6rem;font-weight:800;"><%= @open_markets %></div>
  </div>
  <div class="panel" style="padding:14px 16px;" data-testid="dashboard-stat-liability">
    <div style="font-size:0.72rem;font-weight:600;letter-spacing:.05em;text-transform:uppercase;color:var(--muted);margin-bottom:4px;">House liability</div>
    <div style="font-size:1.6rem;font-weight:800;color:var(--accent);"><%= number_with_delimiter(@house_liability) %></div>
  </div>
  <div class="panel" style="padding:14px 16px;border-color:<%= @pending_faucet_requests > 0 ? '#c87f2a' : '#33434c' %>;" data-testid="dashboard-stat-faucets">
    <div style="font-size:0.72rem;font-weight:600;letter-spacing:.05em;text-transform:uppercase;color:var(--muted);margin-bottom:4px;">Pending faucets</div>
    <div style="font-size:1.6rem;font-weight:800;color:<%= @pending_faucet_requests > 0 ? 'var(--accent)' : 'inherit' %>;"><%= @pending_faucet_requests %></div>
  </div>
  <div class="panel" style="padding:14px 16px;" data-testid="dashboard-stat-volume">
    <div style="font-size:0.72rem;font-weight:600;letter-spacing:.05em;text-transform:uppercase;color:var(--muted);margin-bottom:4px;">24h volume</div>
    <div style="font-size:1.6rem;font-weight:800;"><%= number_with_delimiter(@daily_volume) %></div>
  </div>
</div>

<%# Two-column layout: attention table + action cards %>
<div style="display:grid;grid-template-columns:1.4fr 1fr;gap:16px;">

  <%# Markets needing attention %>
  <div class="panel">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
      <h3 style="margin:0;">Markets needing attention</h3>
      <%= link_to "+ New market", new_backoffice_market_path, style: "background:var(--accent);color:#1a1a1a;padding:6px 12px;border-radius:8px;font-size:0.82rem;font-weight:600;text-decoration:none;" rescue link_to "+ New market", backoffice_markets_path, style: "background:var(--accent);color:#1a1a1a;padding:6px 12px;border-radius:8px;font-size:0.82rem;font-weight:600;text-decoration:none;" %>
    </div>
    <table data-testid="dashboard-attention-table">
      <thead>
        <tr>
          <th style="font-size:0.72rem;text-transform:uppercase;letter-spacing:.05em;">Market</th>
          <th style="font-size:0.72rem;text-transform:uppercase;letter-spacing:.05em;">Mech</th>
          <th style="font-size:0.72rem;text-transform:uppercase;letter-spacing:.05em;">Status</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <% @closed_markets.each do |m| %>
          <tr>
            <td style="font-size:0.85rem;max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
              <%= m.question.truncate(40) %>
            </td>
            <td style="font-size:0.78rem;color:var(--muted);"><%= m.mechanism_type.upcase %></td>
            <td><span style="color:var(--accent);font-size:0.8rem;font-weight:600;">CLOSED</span></td>
            <td><%= link_to "Settle ›", backoffice_market_path(m), style: "color:var(--accent);font-size:0.82rem;" %></td>
          </tr>
        <% end %>
        <% @draft_markets.each do |m| %>
          <tr>
            <td style="font-size:0.85rem;max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
              <%= m.question.truncate(40) %>
            </td>
            <td style="font-size:0.78rem;color:var(--muted);"><%= m.mechanism_type.upcase %></td>
            <td><span style="color:var(--muted);font-size:0.8rem;">DRAFT</span></td>
            <td><%= link_to "View ›", backoffice_market_path(m), style: "color:var(--muted);font-size:0.82rem;" %></td>
          </tr>
        <% end %>
        <% if @closed_markets.empty? && @draft_markets.empty? %>
          <tr><td colspan="4" style="color:var(--muted);font-size:0.85rem;padding:12px 0;">No markets need attention right now.</td></tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <%# Right column: faucet requests + audit events %>
  <div style="display:flex;flex-direction:column;gap:14px;">
    <div class="panel" style="border-color:#c87f2a;" data-testid="dashboard-faucet-card">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
        <h3 style="margin:0;">Pending faucet requests &middot; <%= @pending_faucet_requests %></h3>
        <%= link_to "Review all ›", backoffice_faucet_requests_path, style: "color:var(--accent);font-size:0.82rem;" %>
      </div>
      <% @recent_faucets.each do |req| %>
        <div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid #33434c;">
          <div>
            <div style="font-size:0.88rem;font-weight:600;"><%= req.user.email.split('@').first %></div>
            <div style="font-size:0.75rem;color:var(--muted);"><%= number_with_delimiter(req.amount_minor) %> ADIV · <%= time_ago_in_words(req.created_at) %> ago</div>
          </div>
          <div style="display:flex;gap:6px;">
            <%= button_to "Approve", approve_backoffice_faucet_request_path(req), method: :post,
                  style: "background:#2e7d52;color:#fff;padding:4px 10px;font-size:0.78rem;",
                  data: { testid: "approve-#{req.id}" } %>
            <%= button_to "Reject", reject_backoffice_faucet_request_path(req), method: :post,
                  style: "background:#4a2222;color:#fff;padding:4px 10px;font-size:0.78rem;",
                  data: { testid: "reject-#{req.id}" } %>
          </div>
        </div>
      <% end %>
      <% if @recent_faucets.empty? %>
        <p style="color:var(--muted);font-size:0.85rem;margin:0;">No pending requests.</p>
      <% end %>
    </div>

    <div class="panel" data-testid="dashboard-audit-events">
      <h3 style="margin:0 0 10px;">Recent audit events</h3>
      <% @recent_audit_events.each do |evt| %>
        <div style="padding:6px 0;border-bottom:1px solid #33434c;font-size:0.82rem;">
          <span style="color:var(--muted);margin-right:6px;"><%= evt.created_at.strftime('%H:%M') %></span>
          <span><%= evt.action_type %></span>
        </div>
      <% end %>
      <% if @recent_audit_events.empty? %>
        <p style="color:var(--muted);font-size:0.82rem;margin:0;">No recent events.</p>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 1.5: Run dashboard tests**

```bash
bin/rails test test/integration/backoffice/dashboard_test.rb -v
```
Expected: PASS

- [ ] **Step 1.6: Run full suite**

```bash
bin/rails test
```
Expected: ≥ 90% coverage, 0 failures

- [ ] **Step 1.7: Commit**

```bash
git add app/views/backoffice/dashboard/index.html.erb app/controllers/backoffice/dashboard_controller.rb test/integration/backoffice/dashboard_test.rb
git commit -m "feat(backoffice): dashboard — 4-stat overview, attention table, faucet card, audit events"
```

---

## Task 2: Settle — two-step confirmation with payout preview

**Files:**
- Modify: `app/views/backoffice/markets/show.html.erb`

The wireframe shows a side card with YES/NO outcome selector, a preview box showing "will pay N winning bets · credit X ADIV", and a single **Confirm settlement** button. Currently the form has a browser `data-confirm` which is a poor UX for an irreversible operation.

- [ ] **Step 2.1: Replace data-confirm with a two-step inline confirmation**

In `app/views/backoffice/markets/show.html.erb`, replace the settle form block:

```erb
<% if @market.open? || @market.closed? %>
  <div style="margin-top:16px;border-top:1px solid #33434c;padding-top:14px;">
    <h4>Settle market</h4>

    <%# Step 1: outcome picker %>
    <div id="settle-step1" data-testid="settle-step1">
      <div style="display:flex;gap:8px;margin-bottom:12px;">
        <% @market.market_legs.each do |leg| %>
          <button type="button"
                  onclick="selectOutcome('<%= leg.label %>')"
                  style="flex:1;padding:12px;border:2px solid #33434c;border-radius:8px;background:#0f171d;color:var(--ink);font:inherit;font-weight:600;cursor:pointer;"
                  data-testid="settle-outcome-<%= leg.label.downcase %>"
                  id="btn-<%= leg.label.downcase %>">
            <%= leg.label %> wins
          </button>
        <% end %>
      </div>
      <button type="button" id="settle-preview-btn"
              onclick="showSettleConfirm()"
              style="display:none;background:var(--accent);color:#1a1a1a;padding:8px 18px;border:0;border-radius:8px;font:inherit;font-weight:700;cursor:pointer;"
              data-testid="settle-preview-btn">
        Preview settlement →
      </button>
    </div>

    <%# Step 2: confirmation panel (hidden until step 1 complete) %>
    <div id="settle-step2" style="display:none;" data-testid="settle-step2">
      <div style="background:#2a1f0a;border:1px solid #c87f2a;border-radius:8px;padding:12px;margin-bottom:12px;">
        <p style="color:#f0bc5c;font-size:0.88rem;margin:0;">
          This will settle <strong data-testid="settle-preview-bets"><%= @bets.select(&:open?).size %> open bets</strong>
          and credit approximately <strong data-testid="settle-preview-total"><%= number_with_delimiter(@bets.select(&:open?).sum(&:potential_payout_minor)) %> ADIV</strong>.
          <strong>This cannot be undone.</strong>
        </p>
      </div>
      <%= form_with url: settle_backoffice_market_path(@market), method: :post,
            html: { data: { testid: "settle-market-form" }, id: "settle-form" } do |f| %>
        <input type="hidden" name="outcome" id="settle-outcome-input" value="">
        <p><label>Reason</label><br><%= text_field_tag :reason, nil, data: { testid: "settle-reason" } %></p>
        <div style="display:flex;gap:10px;">
          <%= f.submit "Confirm settlement",
                style: "background:#4a2222;color:#fff;padding:8px 16px;",
                data: { testid: "settle-market-submit" } %>
          <button type="button" onclick="resetSettle()"
                  style="background:transparent;border:1px solid #33434c;color:var(--muted);padding:8px 16px;border-radius:8px;cursor:pointer;font:inherit;">
            Cancel
          </button>
        </div>
      <% end %>
    </div>

    <script>
      var selectedOutcome = null;
      function selectOutcome(outcome) {
        selectedOutcome = outcome;
        document.querySelectorAll('[id^="btn-"]').forEach(function(b) {
          b.style.borderColor = '#33434c';
          b.style.color = 'var(--ink)';
        });
        var btn = document.getElementById('btn-' + outcome.toLowerCase());
        if (btn) { btn.style.borderColor = '#f0bc5c'; btn.style.color = '#f0bc5c'; }
        document.getElementById('settle-preview-btn').style.display = 'inline-block';
      }
      function showSettleConfirm() {
        if (!selectedOutcome) return;
        document.getElementById('settle-outcome-input').value = selectedOutcome;
        document.getElementById('settle-step1').style.display = 'none';
        document.getElementById('settle-step2').style.display = 'block';
      }
      function resetSettle() {
        selectedOutcome = null;
        document.getElementById('settle-step1').style.display = 'block';
        document.getElementById('settle-step2').style.display = 'none';
        document.getElementById('settle-preview-btn').style.display = 'none';
      }
    </script>
  </div>
<% end %>
```

- [ ] **Step 2.2: Run existing settle tests**

```bash
bin/rails test test/integration/backoffice/markets_test.rb -v
```
Expected: all pass (the hidden form still submits with the same params)

- [ ] **Step 2.3: Commit**

```bash
git add app/views/backoffice/markets/show.html.erb
git commit -m "feat(backoffice): settle — two-step confirmation with payout preview"
```

---

## Task 3: Faucet requests — status tabs + balance + reason columns

**Files:**
- Modify: `app/views/backoffice/faucet_requests/index.html.erb`
- Modify: `app/controllers/backoffice/faucet_requests_controller.rb` (add reason param, balance query)

- [ ] **Step 3.1: Extend faucet controller to include user balance and support status tab**

```ruby
# app/controllers/backoffice/faucet_requests_controller.rb
def index
  @tab = params[:tab] || 'pending'
  @pending   = FaucetRequest.pending.includes(:user).order(created_at: :desc)
  @processed = FaucetRequest.where(status: %w[approved rejected]).includes(:user, :reviewed_by).order(updated_at: :desc).limit(50)
  # Preload wallets for pending requests
  @user_balances = Wallet.where(user: @pending.map(&:user)).index_by(&:user_id)
end
```

- [ ] **Step 3.2: Rewrite faucet requests view**

Replace `app/views/backoffice/faucet_requests/index.html.erb`:

```erb
<h1>Faucet requests</h1>
<p style="color:var(--muted);margin-bottom:14px;">Approve or reject play-money top-up requests</p>

<%# Status tabs %>
<div style="display:flex;gap:0;margin-bottom:16px;border:1px solid #33434c;border-radius:10px;overflow:hidden;width:fit-content;" data-testid="faucet-status-tabs">
  <% [['pending', "Pending · #{@pending.count}"], ['approved', 'Approved'], ['rejected', 'Rejected']].each do |val, label| %>
    <%= link_to label, backoffice_faucet_requests_path(tab: val),
          style: "padding:8px 16px;font-size:0.85rem;font-weight:600;text-decoration:none;#{@tab == val ? 'background:var(--accent);color:#1a1a1a;' : 'color:var(--muted);'}",
          data: { testid: "tab-#{val}" } %>
  <% end %>
</div>

<% if @tab == 'pending' %>
  <% if @pending.any? %>
    <div class="panel" style="padding:0;overflow:hidden;">
      <table data-testid="faucet-pending-table">
        <thead>
          <tr>
            <th>Player</th>
            <th>Amount</th>
            <th>Current balance</th>
            <th>Reason</th>
            <th>Requested</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          <% @pending.each do |req| %>
            <% bal = @user_balances[req.user_id]&.available_minor %>
            <tr data-testid="faucet-row-<%= req.id %>">
              <td style="font-weight:600;"><%= req.user.email.split('@').first %></td>
              <td style="font-weight:700;"><%= number_with_delimiter(req.amount_minor) %> ADIV</td>
              <td style="color:var(--muted);font-size:0.85rem;"><%= bal ? number_with_delimiter(bal) : "—" %> ADIV</td>
              <td style="color:var(--muted);font-size:0.85rem;max-width:180px;"><%= req.reason.presence || "—" %></td>
              <td style="color:var(--muted);font-size:0.82rem;white-space:nowrap;"><%= time_ago_in_words(req.created_at) %> ago</td>
              <td>
                <div style="display:flex;gap:6px;">
                  <%= button_to "Approve", approve_backoffice_faucet_request_path(req), method: :post,
                        style: "background:#2e7d52;color:#fff;padding:5px 12px;font-size:0.82rem;",
                        data: { testid: "approve-#{req.id}" } %>
                  <%= button_to "Reject", reject_backoffice_faucet_request_path(req), method: :post,
                        style: "background:#4a2222;color:#fff;padding:5px 12px;font-size:0.82rem;",
                        data: { testid: "reject-#{req.id}" } %>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% else %>
    <div class="panel"><p style="color:var(--muted);">No pending faucet requests.</p></div>
  <% end %>
<% else %>
  <% display = @processed.select { |r| r.status == @tab } %>
  <% if display.any? %>
    <div class="panel" style="padding:0;overflow:hidden;">
      <table>
        <thead>
          <tr><th>Player</th><th>Amount</th><th>Status</th><th>Reviewed by</th><th>Processed</th></tr>
        </thead>
        <tbody>
          <% display.each do |req| %>
            <tr>
              <td><%= req.user.email.split('@').first %></td>
              <td><%= number_with_delimiter(req.amount_minor) %> ADIV</td>
              <td style="text-transform:capitalize;"><%= req.status %></td>
              <td><%= req.reviewed_by&.email&.split('@')&.first || "—" %></td>
              <td style="color:var(--muted);font-size:0.82rem;"><%= req.updated_at.strftime("%Y-%m-%d %H:%M") %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% else %>
    <div class="panel"><p style="color:var(--muted);">No <%= @tab %> requests.</p></div>
  <% end %>
<% end %>
```

Note: `req.reason` requires a `reason` column on `faucet_requests`. Check the model — if the column doesn't exist, this step is blocked. In that case, skip the reason column and note it as a follow-up.

- [ ] **Step 3.3: Run faucet integration tests**

```bash
bin/rails test test/integration/backoffice/faucet_requests_test.rb -v
```
Expected: all pass

- [ ] **Step 3.4: Commit**

```bash
git add app/views/backoffice/faucet_requests/index.html.erb app/controllers/backoffice/faucet_requests_controller.rb
git commit -m "feat(backoffice): faucet requests — status tabs, balance column, reason column"
```

---

## Task 4: Update docs

- [ ] Append entry to `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` — add to Done list
- [ ] Commit: `docs: update INDEX and WORK_LOG after ux-backoffice-dashboard-settle`

---

## Open Design Questions

1. **`faucet_requests.reason` column**: The wireframe and profile form show a reason field. Check the migration history:
   ```bash
   grep -r "reason" db/structure.sql | grep faucet
   ```
   If the column doesn't exist, add a migration (`add_column :faucet_requests, :reason, :string`) as the first step of Task 3, and update `FaucetRequest` permitted params.

2. **`AuditEvent#action_type`**: The dashboard audit event card displays `evt.action_type`. Confirm the attribute name in `app/models/audit_event.rb`. It may be `event_type` or `action`. Adjust the view accordingly.

3. **`new_backoffice_market_path`**: The create form is currently embedded in the index page (`backoffice/markets/index`), not a separate `new` route. The "+ New market" dashboard link should go to `backoffice_markets_path` (the index which contains the create form) or the create form can be extracted to a dedicated `new.html.erb` — the latter is cleaner. This plan uses `backoffice_markets_path` as a safe default.

---

## Self-Review Checklist
- [ ] Dashboard page renders without errors even when no closed markets exist
- [ ] `compute_house_liability` rescued with 0 in case of unexpected DB state
- [ ] Two-step settle form still submits correct `outcome` param
- [ ] Settle confirmation JS resets correctly on cancel
- [ ] Full test suite passes: `bin/rails test`
