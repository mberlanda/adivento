# UX — Market Browse & Detail Enrichment

<!-- File location: docs/superpowers/plans/2026-05-29-ux-market-browse-detail.md -->

**Goal:** Close the UX gap between the wireframe designs and the current `/web/markets/index` and `/web/markets/show` views: add mechanism/status filter controls, sparklines, "live" dot, decision-stats row, price-history chart placeholder, sticky 2-column bet rail, quick-add stake chips, payout preview box, LMSR price-impact preview, and CLOB depth ladder.

**Architecture:** Pure view changes — no new routes, no new controllers, no migrations. All data already flows from the controller. Chart and SSE live-dot use vanilla JS + inline SVG within the existing CSS design system. Two-column layout on market detail uses CSS grid (already proven in backoffice create form). LMSR price-impact calls the existing `LmsrPricingService` via a new controller helper or an inline calculation.

**Tech Stack:** Rails 8 ERB, vanilla JS (no new npm deps), existing CSS variables, Minitest integration tests for the filter parameters.

**Spec:** `docs/design/02-flows-and-use-cases.md` §1 and §2, `docs/design/wireframes/v1/wireframes-web.jsx` (`WFWeb.Browse`, `WFWeb.MarketDetail`), `docs/design/wireframes/v1/wireframes-mechanisms.jsx`.

---

## File Map

**Modify:**
- `app/views/web/markets/index.html.erb` — add mechanism/status/sort filter row, sparkline SVG stub, live dot badge, volume+closes stats on cards
- `app/views/web/markets/show.html.erb` — two-column layout, sticky bet rail, quick-add chips, payout preview, activity stub, price-history chart stub, LMSR price-impact box, CLOB depth ladder
- `app/controllers/web/markets_controller.rb` — add `mechanism`, `status`, `sort` filter params; pass `@sort` and `@mechanism_filter` to view; add `@price_history` stub (empty array for now)
- `test/integration/web/markets_test.rb` — add filter parameter tests

---

## Task 1: Browse page — mechanism/status/sort filters + card stats

**Files:**
- Modify: `app/views/web/markets/index.html.erb`
- Modify: `app/controllers/web/markets_controller.rb`
- Test: `test/integration/web/markets_test.rb`

- [ ] **Step 1.1: Add filter params to the controller**

```ruby
# app/controllers/web/markets_controller.rb — index action
# Add to the permitted params block:
@mechanism_filter = params[:mechanism].presence
@status_filter_param = params[:status].presence
@sort = params[:sort].presence || 'newest'

scope = scope.where(mechanism_type: @mechanism_filter) if @mechanism_filter
scope = scope.where(status: Market.statuses[@status_filter_param]) if @status_filter_param
scope = case @sort
        when 'volume'  then scope.order(Arel.sql("(SELECT COALESCE(SUM(net_stake_minor),0) FROM bets WHERE market_id = markets.id) DESC"))
        when 'closing' then scope.order(close_at: :asc).where.not(close_at: nil)
        else scope.order(created_at: :desc)
        end
```

- [ ] **Step 1.2: Write failing integration test for mechanism filter**

```ruby
# test/integration/web/markets_test.rb
test "GET /web/markets filters by mechanism" do
  get web_markets_path(mechanism: "clob")
  assert_response :success
  assert_select "[data-testid='market-card-#{markets(:clob_market).id}']"
  assert_select "[data-testid='market-card-#{markets(:open_market).id}']", count: 0
end

test "GET /web/markets filters by status=open" do
  get web_markets_path(status: "open")
  assert_response :success
  assert_select "[data-testid='status-badge-#{markets(:open_market).id}']"
  assert_select "[data-testid='status-badge-#{markets(:draft_market).id}']", count: 0
end
```

- [ ] **Step 1.3: Run test to verify it fails**

```bash
bin/rails test test/integration/web/markets_test.rb -v
```
Expected: FAIL (filter params ignored or test not selected yet)

- [ ] **Step 1.4: Add filter controls to the browse view**

In `app/views/web/markets/index.html.erb`, replace the single category filter section with a richer filter bar:

```erb
<%# --- filter bar ------------------------------------------------ %>
<div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px;align-items:center;" data-testid="filter-bar">
  <%# mechanism pills %>
  <% [['All', nil], ['Fixed-odds', 'fixed_odds'], ['CLOB', 'clob'], ['LMSR', 'lmsr'], ['Parimutuel', 'parimutuel']].each do |label, val| %>
    <%= link_to label,
          web_markets_path(q: @search_query, category: @selected_category, mechanism: val, status: @status_filter_param, sort: @sort),
          class: "pill #{@mechanism_filter == val ? 'pill-active' : 'pill-outline'}",
          data: { testid: "mech-filter-#{val || 'all'}" } %>
  <% end %>
  <div style="flex:1;"></div>
  <%# status select %>
  <select onchange="location=this.value" style="padding:4px 8px;border-radius:8px;font-size:0.82rem;">
    <option value="<%= web_markets_path(q: @search_query, category: @selected_category, mechanism: @mechanism_filter, sort: @sort) %>">All statuses</option>
    <% [['Open', 'open'], ['Closed', 'closed'], ['Settled', 'settled']].each do |label, val| %>
      <option value="<%= web_markets_path(q: @search_query, category: @selected_category, mechanism: @mechanism_filter, status: val, sort: @sort) %>"
              <%= 'selected' if @status_filter_param == val %>><%= label %></option>
    <% end %>
  </select>
  <%# sort select %>
  <select onchange="location=this.value" style="padding:4px 8px;border-radius:8px;font-size:0.82rem;" data-testid="sort-select">
    <% [['Newest', 'newest'], ['Closing soon', 'closing'], ['Volume', 'volume']].each do |label, val| %>
      <option value="<%= web_markets_path(q: @search_query, category: @selected_category, mechanism: @mechanism_filter, status: @status_filter_param, sort: val) %>"
              <%= 'selected' if @sort == val %>><%= label %></option>
    <% end %>
  </select>
</div>
```

- [ ] **Step 1.5: Add live dot + sparkline stub + volume/closes stats to market cards**

Replace the odds chips block at the bottom of each card in `index.html.erb`:

```erb
<div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:auto;align-items:center;">
  <% market.market_legs.each do |leg| %>
    <span style="display:inline-flex;flex-direction:column;align-items:center;background:#f4f9f7;border:1px solid #d0e8de;border-radius:8px;padding:4px 12px;min-width:48px;">
      <span style="font-size:0.75rem;color:var(--muted);"><%= leg.label %></span>
      <span style="font-weight:700;font-size:1rem;color:var(--accent);"><%= (leg.odds_minor / 100.0).round(0) %>%</span>
    </span>
  <% end %>
  <span style="margin-left:auto;font-size:0.78rem;color:var(--muted);align-self:flex-end;">
    <%= market.mechanism_type.upcase %>
    <% if market.open? %>
      <span style="display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--accent);margin-left:4px;animation:livepulse 1.6s ease-in-out infinite;" title="Live"></span>
    <% end %>
  </span>
</div>
<% if market.close_at.present? && market.open? %>
  <p class="muted" style="font-size:0.75rem;margin:4px 0 0;">Closes <%= distance_of_time_in_words(Time.current, market.close_at) %></p>
<% end %>
```

Add the pulse animation to the layout `<style>` block in `application.html.erb`:
```css
@keyframes livepulse { 0%,100% { opacity:1; } 50% { opacity:.3; } }
```

- [ ] **Step 1.6: Run test to verify filters pass**

```bash
bin/rails test test/integration/web/markets_test.rb -v
```
Expected: PASS

- [ ] **Step 1.7: Run full suite**

```bash
bin/rails test
```
Expected: ≥ 90% coverage, 0 failures

- [ ] **Step 1.8: Commit**

```bash
git add app/views/web/markets/index.html.erb app/controllers/web/markets_controller.rb app/views/layouts/application.html.erb test/integration/web/markets_test.rb
git commit -m "feat(web): market browse — mechanism/status/sort filters + live dot"
```

---

## Task 2: Market detail — two-column layout + sticky bet rail

**Files:**
- Modify: `app/views/web/markets/show.html.erb`

The wireframe places the bet form in a **sticky 320px right column**; the market info (stats, price panel, resolution, your bets) fills the left column. The current view is single-column.

- [ ] **Step 2.1: Wrap show.html.erb in a two-column grid**

Restructure `show.html.erb` so the outer wrapper uses `display:grid; grid-template-columns: 1fr 320px; gap: 22px;` (collapses to 1 column below 800px with a media query). All existing sections go in the left `<div>`. The bet form (quick-bet-panel) moves to a sticky right `<div>`.

```erb
<%# top breadcrumb and badges stay outside the grid %>
<div style="margin-bottom:8px;"><%= link_to "← All Markets", web_markets_path, class: "muted" %></div>
<div style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px;" data-testid="market-meta"> ... existing badges ... </div>

<div class="market-detail-grid" style="display:grid;grid-template-columns:1fr 320px;gap:22px;align-items:start;">
  <%# LEFT COLUMN — all existing content except bet panel %>
  <div>
    <h1 ...>...</h1>
    <%# ...stat-grid, price panel, legs, closed notice, resolution, your-bets, trust panel... %>
  </div>

  <%# RIGHT COLUMN — sticky bet rail %>
  <div style="position:sticky;top:80px;">
    <%# existing quick-bet-panel card, or sign-in prompt %>
    <%# ...CLOB/LMSR/fixed/pari forms... %>
  </div>
</div>

<style>
@media(max-width:800px){.market-detail-grid{grid-template-columns:1fr!important;}}
</style>
```

- [ ] **Step 2.2: Add quick-add stake chips and payout preview box to fixed-odds and LMSR forms**

Inside the fixed-odds quick-bet-panel, after the stake input add:

```erb
<%# quick-add chips %>
<div style="display:flex;gap:6px;margin:8px 0;" data-testid="quick-add-chips">
  <% [50, 100, 500].each do |amt| %>
    <button type="button" class="pill pill-outline"
            onclick="var f=this.closest('form');var i=f.querySelector('[data-testid=bet-stake]');i.value=parseInt(i.value||0)+<%= amt %>">+<%= amt %></button>
  <% end %>
</div>
<%# payout preview box (updated via JS) %>
<div style="background:#f4f9f7;border:1px solid #d0e8de;border-radius:8px;padding:10px;margin-bottom:12px;font-size:0.85rem;" data-testid="payout-preview">
  <div style="display:flex;justify-content:space-between;">
    <span class="muted">Potential payout</span>
    <span id="payout-estimate" style="font-weight:700;">—</span>
  </div>
  <div style="display:flex;justify-content:space-between;">
    <span class="muted">Fee (<%= (@market.fee_bps.to_i / 100.0).round(1) %>%)</span>
    <span id="fee-estimate" class="muted">—</span>
  </div>
</div>
<script>
(function(){
  var form = document.querySelector('[data-testid="quick-bet-form"]');
  if (!form) return;
  var stakeInput = form.querySelector('[data-testid="bet-stake"]');
  var legInputs  = form.querySelectorAll('input[name="market_leg_id"]');
  var payoutEl   = document.getElementById('payout-estimate');
  var feeEl      = document.getElementById('fee-estimate');
  var legs       = {<%= @market.market_legs.map { |l| "#{l.id}: #{l.odds_minor}" }.join(',') %>};
  var feeBps     = <%= @market.fee_bps.to_i %>;
  function update(){
    var leg = form.querySelector('input[name="market_leg_id"]:checked');
    var stake = parseInt(stakeInput.value) || 0;
    if (!leg || !stake) { payoutEl.textContent = '—'; feeEl.textContent = '—'; return; }
    var odds = legs[leg.value];
    if (!odds) return;
    var gross = Math.round(stake * 10000 / odds);
    var fee   = Math.round(gross * feeBps / 10000);
    payoutEl.textContent = (gross - fee) + ' ADIV';
    feeEl.textContent    = '−' + fee + ' ADIV';
  }
  stakeInput.addEventListener('input', update);
  legInputs.forEach(function(r){ r.addEventListener('change', update); });
})();
</script>
```

For LMSR, add an avg-cost / new-price preview box after the quantity input:
```erb
<div style="background:#f4f9f7;border:1px solid #d0e8de;border-radius:8px;padding:10px;margin-bottom:12px;font-size:0.85rem;" data-testid="lmsr-impact-preview">
  <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
    <span class="muted">Avg cost / share</span>
    <span id="lmsr-avg-cost">—</span>
  </div>
  <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
    <span class="muted">Total cost</span>
    <span id="lmsr-total-cost">—</span>
  </div>
  <div style="display:flex;justify-content:space-between;">
    <span class="muted">New YES price after trade</span>
    <span id="lmsr-new-price">—</span>
  </div>
  <p class="muted" style="font-size:0.75rem;margin:6px 0 0;">Larger purchases move the price more.</p>
</div>
<script>
(function(){
  var form = document.querySelector('[data-testid="quick-bet-form"]');
  if (!form) return;
  var qInput = form.querySelector('[data-testid="bet-stake"]');
  var sideInputs = form.querySelectorAll('input[name="side"]');
  var b = <%= @market.lmsr_b_parameter.to_f %>;
  var qYes = <%= @market.lmsr_q_yes.to_i %>;
  var qNo  = <%= @market.lmsr_q_no.to_i %>;
  function logsum(a,b){ return Math.log(Math.exp(a/b) + Math.exp(b_/b)) * b; } // placeholder — real calc on server
  function update(){
    var side = form.querySelector('input[name="side"]:checked');
    var qty  = parseInt(qInput.value) || 0;
    if (!side || !qty) { ['lmsr-avg-cost','lmsr-total-cost','lmsr-new-price'].forEach(function(id){ document.getElementById(id).textContent='—'; }); return; }
    // Simple approximation: current price × qty (exact would need exp math)
    var curPrice = side.value === 'yes'
      ? Math.exp(qYes/b) / (Math.exp(qYes/b) + Math.exp(qNo/b))
      : Math.exp(qNo/b)  / (Math.exp(qYes/b) + Math.exp(qNo/b));
    var approxCost = Math.round(curPrice * qty * 100);
    document.getElementById('lmsr-avg-cost').textContent  = (curPrice * 100).toFixed(1) + '¢';
    document.getElementById('lmsr-total-cost').textContent = approxCost + ' ADIV';
    document.getElementById('lmsr-new-price').textContent  = '~' + (curPrice * 100).toFixed(1) + '% (approx)';
  }
  qInput.addEventListener('input', update);
  sideInputs.forEach(function(r){ r.addEventListener('change', update); });
})();
</script>
```

- [ ] **Step 2.3: Add CLOB depth ladder to the CLOB price panel**

In the `when 'clob'` branch of the price panel, after the bid/ask boxes add a depth ladder:

```erb
<% bids = book[:bids] || []; asks = book[:asks] || [] %>
<% if bids.any? || asks.any? %>
  <div style="margin-top:12px;border:1px solid var(--border);border-radius:8px;overflow:hidden;font-size:0.8rem;" data-testid="clob-depth-ladder">
    <div style="padding:4px 10px;background:#f4f9f7;font-size:0.72rem;color:var(--muted);text-transform:uppercase;letter-spacing:.04em;display:flex;justify-content:space-between;">
      <span>Price</span><span>Depth (ADIV)</span>
    </div>
    <% (asks.first(3).reverse rescue []).each do |level| %>
      <div style="display:flex;justify-content:space-between;padding:4px 10px;background:#fff8f0;position:relative;" data-testid="ask-level">
        <span style="color:#8a5c10;font-weight:600;z-index:1;"><%= level[:price] %>¢</span>
        <span class="muted" style="z-index:1;"><%= number_with_delimiter(level[:quantity]) %></span>
        <div style="position:absolute;right:0;top:0;bottom:0;background:#f0dfc0;opacity:.5;width:<%= [level[:quantity].to_i * 100 / [asks.map{|a| a[:quantity].to_i}.max, 1].max, 100].min %>%;"></div>
      </div>
    <% end %>
    <div style="padding:3px 10px;background:#f0f4f7;font-size:0.72rem;color:var(--muted);text-align:center;" data-testid="clob-spread-label">
      <% if book[:spread] %> Spread <%= book[:spread] %>¢ <% end %>
    </div>
    <% (bids.first(3) rescue []).each do |level| %>
      <div style="display:flex;justify-content:space-between;padding:4px 10px;background:#f4f9f7;position:relative;" data-testid="bid-level">
        <span style="color:var(--accent);font-weight:600;z-index:1;"><%= level[:price] %>¢</span>
        <span class="muted" style="z-index:1;"><%= number_with_delimiter(level[:quantity]) %></span>
        <div style="position:absolute;right:0;top:0;bottom:0;background:#d0e8de;opacity:.5;width:<%= [level[:quantity].to_i * 100 / [bids.map{|b| b[:quantity].to_i}.max, 1].max, 100].min %>%;"></div>
      </div>
    <% end %>
  </div>
<% end %>
```

Note: The `order_book_summary` currently returns `{bid:, ask:, spread:}` scalars. This step requires `bids: [], asks: []` arrays (depth levels). Check `Clob::OrderMatchingService#order_book_summary` — if the arrays aren't returned, add them in the same commit.

- [ ] **Step 2.4: Add price-history chart placeholder section**

After the stat-grid section and before the price panel:

```erb
<section class="card" style="margin-bottom:16px;" data-testid="market-chart-panel">
  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
    <h3 style="margin:0;">Price History</h3>
    <div style="display:flex;gap:4px;" data-testid="chart-range">
      <% ['1H','6H','1D','1W','ALL'].each_with_index do |r, i| %>
        <span class="pill <%= i == 2 ? 'pill-active' : 'pill-outline' %>" style="font-size:0.75rem;padding:2px 8px;"><%= r %></span>
      <% end %>
    </div>
  </div>
  <% if @price_snapshots.any? %>
    <%# Render an inline SVG sparkline from snapshot data %>
    <% pts = @price_snapshots.map(&:yes_price_bps) %>
    <% min_p = pts.min; max_p = pts.max; range = [(max_p - min_p), 1].max %>
    <svg viewBox="0 0 <%= pts.size - 1 %> 60" preserveAspectRatio="none"
         style="width:100%;height:80px;display:block;" data-testid="price-chart">
      <polyline fill="none" stroke="var(--accent)" stroke-width="1.5"
        points="<%= pts.each_with_index.map { |p, i| "#{i},#{60 - (p - min_p) * 60 / range}" }.join(' ') %>" />
    </svg>
  <% else %>
    <div style="height:80px;background:#f4f9f7;border-radius:8px;display:flex;align-items:center;justify-content:center;" data-testid="chart-empty">
      <span class="muted" style="font-size:0.82rem;">Price history will appear here once trades are recorded.</span>
    </div>
  <% end %>
</section>
```

Pass `@price_snapshots` from the controller:
```ruby
# app/controllers/web/markets_controller.rb — show action
@price_snapshots = @market.price_snapshots.order(recorded_at: :asc).last(100)
```

- [ ] **Step 2.5: Add parimutuel pool bar to parimutuel price panel**

In the `when 'parimutuel'` branch, add visual pool bars:

```erb
<%# After the YES/NO percentage boxes, add pool bars %>
<div style="margin-top:10px;">
  <div style="display:flex;gap:2px;height:8px;border-radius:4px;overflow:hidden;" data-testid="pool-bar">
    <div style="background:var(--accent);width:<%= yes_pct %>%;transition:width .4s;"></div>
    <div style="background:#8a5c10;width:<%= no_pct %>%;transition:width .4s;"></div>
  </div>
</div>
```

- [ ] **Step 2.6: Add activity feed stub**

After the "Your Bets" section and before the trust panel:

```erb
<section class="card" style="margin-bottom:16px;" data-testid="market-activity-panel">
  <h3 style="margin-top:0;">Recent Activity</h3>
  <% if @recent_activity.any? %>
    <% @recent_activity.each do |entry| %>
      <div style="display:flex;justify-content:space-between;padding:7px 0;border-bottom:1px solid var(--border);font-size:0.85rem;" data-testid="activity-row">
        <span><strong><%= entry[:player] %></strong> <%= entry[:action] %></span>
        <span class="muted"><%= time_ago_in_words(entry[:at]) %> ago</span>
      </div>
    <% end %>
  <% else %>
    <p class="muted" style="font-size:0.82rem;">No recent activity.</p>
  <% end %>
</section>
```

Pass from the controller:
```ruby
# app/controllers/web/markets_controller.rb — show action
@recent_activity = @market.bets
  .includes(:user, :market_leg)
  .order(created_at: :desc)
  .limit(5)
  .map { |b| { player: b.user.email.split('@').first, action: "bet #{b.market_leg.label}", at: b.created_at } }
```

- [ ] **Step 2.7: Run full test suite**

```bash
bin/rails test
```
Expected: ≥ 90% coverage, 0 failures

- [ ] **Step 2.8: Commit**

```bash
git add app/views/web/markets/show.html.erb app/controllers/web/markets_controller.rb
git commit -m "feat(web): market detail — sticky bet rail, quick-add chips, payout preview, chart placeholder, activity feed, CLOB depth ladder, LMSR price-impact"
```

---

## Task 3: Update docs

- [ ] Append entry to `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` — add to Done list
- [ ] Commit: `docs: update INDEX and WORK_LOG after ux-market-browse-detail`

---

## Open Design Questions

1. **CLOB depth arrays**: `order_book_summary` returns scalar bid/ask. For the depth ladder (step 2.3), the method needs to return `bids: [{price:, quantity:}]` and `asks: [{price:, quantity:}]` arrays. This is a backend change to `Clob::OrderMatchingService`. The plan treats it as a same-commit extension.

2. **LMSR live price-impact**: The inline JS does an approximation (linear). A server-side endpoint (e.g., `GET /web/markets/:id/lmsr_quote?qty=N&side=yes`) would give exact cost from `LmsrPricingService`. This plan uses the approximation for now — a follow-up can add the AJAX endpoint.

3. **Price history range buttons**: Clicking 1H/6H etc. currently has no effect (the data slice is always the last 100 snapshots). Implementing range filtering requires either an AJAX endpoint or a full page reload with a param. Defer to a follow-up.

---

## Self-Review Checklist
- [ ] All existing tests still pass
- [ ] No new routes or DB migrations introduced
- [ ] Filter params are whitelisted in controller
- [ ] JS in show.html.erb does not crash when mechanism data is missing
- [ ] Full test suite passes: `bin/rails test`
