# UX — Leaderboard, Profile & Auth Pages

<!-- File location: docs/superpowers/plans/2026-05-29-ux-leaderboard-profile-auth.md -->

**Goal:** Close the wireframe gaps on the leaderboard (add top-3 podium, volume/win-rate/bets columns, highlight current user's row), profile page (add avatar/username header, rank stat, 4-stat grid, open-positions summary card, faucet reason field, faucet pending banner), auth page (add a register form alongside sign-in, add post-register faucet nudge), and positions page (apply the customer web design system).

**Architecture:** Pure view and minimal controller changes. No migrations. The register form reuses the existing `POST /register` endpoint. The profile rank is derived from the leaderboard query (already available). No new routes except `GET /register` which already exists (or maps to `/signin` with a register tab).

**Tech Stack:** Rails 8 ERB, existing CSS design system, Minitest.

**Spec:** `docs/design/02-flows-and-use-cases.md` §3 §4 §5, `docs/design/wireframes/v1/wireframes-web.jsx` (`WFWeb.Leaderboard`, `WFWeb.Profile`, `WFWeb.Auth`).

---

## File Map

**Modify:**
- `app/views/web/leaderboard/index.html.erb` — top-3 podium, extra columns, current-user row highlight
- `app/controllers/web/leaderboard_controller.rb` — pass `@current_user_rank` + extra columns
- `app/views/web/profile/show.html.erb` — header with avatar/rank, 4-stat grid, positions summary card, faucet reason field, pending-request banner
- `app/controllers/web/profile_controller.rb` — pass `@pending_faucet`, `@rank`
- `app/views/web/sessions/new.html.erb` — add register form tab
- `app/views/web/positions/index.html.erb` — apply design system (cards, stat-grid, design polish)

---

## Task 1: Leaderboard — top-3 podium + extra columns + user highlight

**Files:**
- Modify: `app/views/web/leaderboard/index.html.erb`
- Modify: `app/controllers/web/leaderboard_controller.rb`
- Test: `test/integration/web/leaderboard_test.rb`

- [ ] **Step 1.1: Extend the leaderboard controller with extra columns**

```ruby
# app/controllers/web/leaderboard_controller.rb
# Already has @entries. Add:
@current_user_rank = current_user ? @entries.index { |e| e.user_id == current_user.id } : nil
# @entries already has total_staked, total_returned — add win_rate and bet_count via leaderboard query
# The leaderboard service/query may need to be extended to return win_count, total_bets
```

Check `app/models/leaderboard_entry.rb` (or wherever the query lives) to see if `win_count` and `bet_count` are available. If not, extend the SELECT to include:
```sql
COUNT(CASE WHEN le.entry_type IN ('BET_WIN','LMSR_WIN','PARIMUTUEL_WIN','CLOB_WIN') THEN 1 END) AS win_count,
COUNT(DISTINCT bets.id) AS total_bets
```

- [ ] **Step 1.2: Write failing test for podium presence**

```ruby
# test/integration/web/leaderboard_test.rb
test "GET /web/leaderboard renders podium" do
  get web_leaderboard_path
  assert_response :success
  assert_select "[data-testid='leaderboard-podium']"
end

test "GET /web/leaderboard highlights current user row" do
  post "/signin", params: { email: users(:player).email, password: "password123" }
  get web_leaderboard_path
  assert_response :success
  # The player row should exist (even if rank > 3)
  assert_select "[data-testid='leaderboard-row-#{users(:player).id}']"
end
```

- [ ] **Step 1.3: Run test to see it fail**

```bash
bin/rails test test/integration/web/leaderboard_test.rb -v
```
Expected: FAIL (podium element absent)

- [ ] **Step 1.4: Rewrite the leaderboard view with podium + extra columns**

Replace `app/views/web/leaderboard/index.html.erb`:

```erb
<div style="margin-bottom:20px;">
  <h1 style="margin:0 0 4px;" data-testid="leaderboard-title">Leaderboard</h1>
  <p class="muted" style="margin:0;">Ranked by net P&amp;L across all market mechanisms.</p>
</div>

<% top3 = @entries.first(3) %>
<% if top3.size >= 2 %>
  <%# Podium: order = 2nd, 1st, 3rd for visual height %>
  <div style="display:flex;gap:12px;align-items:flex-end;margin-bottom:24px;justify-content:center;" data-testid="leaderboard-podium">
    <% podium_order = [top3[1], top3[0], top3[2]].compact %>
    <% podium_heights = [80, 108, 64] %>
    <% podium_ranks   = [2, 1, 3] %>
    <% podium_order.each_with_index do |entry, pi| %>
      <% net = entry.total_returned.to_i - entry.total_staked.to_i %>
      <div style="display:flex;flex-direction:column;align-items:center;gap:6px;flex:1;max-width:140px;">
        <div style="width:40px;height:40px;border-radius:50%;background:#ecf7f3;border:2px solid var(--border);display:flex;align-items:center;justify-content:center;font-weight:800;color:var(--accent);">
          <%= entry.email.split('@').first[0].upcase %>
        </div>
        <span style="font-size:0.85rem;font-weight:700;"><%= entry.email.split('@').first %></span>
        <span style="font-size:0.82rem;color:<%= net >= 0 ? 'var(--accent)' : '#d9534f' %>;">
          <%= net >= 0 ? '+' : '' %><%= number_with_delimiter(net) %> ADIV
        </span>
        <div style="width:100%;background:#f4f9f7;border:1px solid var(--border);border-radius:8px 8px 0 0;height:<%= podium_heights[pi] %>px;display:flex;align-items:flex-start;justify-content:center;padding-top:10px;font-weight:800;font-size:1.3rem;color:var(--accent);">
          <%= podium_ranks[pi] %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>

<% if @entries.empty? %>
  <div class="card" style="text-align:center;padding:40px 20px;" data-testid="leaderboard-empty">
    <p class="muted">No settled bets yet. Be the first to play!</p>
    <%= link_to "Browse markets", web_markets_path, class: "pill pill-active" %>
  </div>
<% else %>
  <div class="card" style="padding:0;overflow:hidden;" data-testid="leaderboard-table-container">
    <table style="width:100%;border-collapse:collapse;" data-testid="leaderboard-table">
      <thead>
        <tr style="border-bottom:1px solid var(--border);background:var(--panel);">
          <% [['#', 'left'], ['Player', 'left'], ['Net P&L', 'right'], ['Volume', 'right'], ['Win rate', 'right'], ['Bets', 'right']].each do |h, align| %>
            <th style="padding:10px 14px;text-align:<%= align %>;font-size:0.78rem;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.04em;"><%= h %></th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <% @entries.each_with_index do |entry, idx| %>
          <% net_pnl    = entry.total_returned.to_i - entry.total_staked.to_i %>
          <% is_current = current_user && entry.user_id == current_user.id %>
          <tr style="border-bottom:1px solid var(--border);<%= is_current ? 'background:#f0fdf9;' : '' %>"
              data-testid="leaderboard-row-<%= entry.user_id %>">
            <td style="padding:10px 14px;font-size:0.88rem;">
              <% case idx
                 when 0 then %><span title="1st">🥇</span><%
                 when 1 then %><span title="2nd">🥈</span><%
                 when 2 then %><span title="3rd">🥉</span><%
                 else %><%= idx + 1 %><%
                 end %>
            </td>
            <td style="padding:10px 14px;font-weight:600;" data-testid="leaderboard-player-<%= entry.user_id %>">
              <%= entry.email.split('@').first %><% if is_current %> <span class="badge" style="font-size:0.7rem;">you</span><% end %>
            </td>
            <td style="padding:10px 14px;text-align:right;font-weight:700;" data-testid="leaderboard-pnl-<%= entry.user_id %>">
              <span style="color:<%= net_pnl >= 0 ? 'var(--accent)' : '#d9534f' %>;">
                <%= net_pnl >= 0 ? '+' : '' %><%= number_with_delimiter(net_pnl) %>
              </span>
            </td>
            <td style="padding:10px 14px;text-align:right;font-size:0.88rem;" class="muted"><%= number_with_delimiter(entry.total_staked.to_i) %></td>
            <td style="padding:10px 14px;text-align:right;font-size:0.88rem;" class="muted">
              <%= entry.respond_to?(:win_count) && entry.total_bets.to_i > 0 ? "#{(entry.win_count.to_i * 100 / entry.total_bets.to_i)}%" : "—" %>
            </td>
            <td style="padding:10px 14px;text-align:right;font-size:0.88rem;" class="muted"><%= entry.respond_to?(:total_bets) ? entry.total_bets.to_i : "—" %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>

<div style="margin-top:16px;text-align:center;">
  <%= link_to "Browse markets", web_markets_path, class: "pill pill-outline" %>
</div>
```

- [ ] **Step 1.5: Run leaderboard tests**

```bash
bin/rails test test/integration/web/leaderboard_test.rb -v
```
Expected: PASS

- [ ] **Step 1.6: Commit**

```bash
git add app/views/web/leaderboard/index.html.erb app/controllers/web/leaderboard_controller.rb test/integration/web/leaderboard_test.rb
git commit -m "feat(web): leaderboard — top-3 podium, extra columns, current-user row highlight"
```

---

## Task 2: Profile — header, 4-stat grid, positions card, faucet improvements

**Files:**
- Modify: `app/views/web/profile/show.html.erb`
- Modify: `app/controllers/web/profile_controller.rb`

- [ ] **Step 2.1: Extend the profile controller**

```ruby
# app/controllers/web/profile_controller.rb
# Add to show action:
@pending_faucet = current_user.faucet_requests.where(status: :pending).first
@rank = LeaderboardService.rank_for(current_user)  # or derive inline
@open_positions_summary = {
  fixed_odds: current_user.bets.open.joins(:market).where(markets: { mechanism_type: ['fixed_odds', 'parimutuel'] }).count,
  clob: current_user.bets.open.joins(:market).where(markets: { mechanism_type: 'clob' }).count,
  lmsr: LmsrPosition.where(user: current_user).where('contracts > 0').count
}
```

If `LeaderboardService.rank_for` doesn't exist, derive rank as:
```ruby
@rank = LedgerEntry.select(:user_id)
  .group(:user_id)
  .order(Arel.sql("SUM(CASE WHEN direction='credit' THEN amount_minor ELSE -amount_minor END) DESC"))
  .map(&:user_id)
  .index(current_user.id)&.+(1)
```

- [ ] **Step 2.2: Rewrite profile header and stat grid**

At the top of `app/views/web/profile/show.html.erb`, replace `<h1>` with a richer header:

```erb
<div style="display:flex;align-items:center;gap:16px;margin-bottom:20px;" data-testid="profile-header">
  <div style="width:52px;height:52px;border-radius:50%;background:#ecf7f3;border:2px solid var(--border);display:flex;align-items:center;justify-content:center;font-size:1.4rem;font-weight:800;color:var(--accent);">
    <%= current_user.email.split('@').first[0].upcase %>
  </div>
  <div>
    <h1 style="margin:0 0 2px;font-size:1.2rem;" data-testid="profile-username"><%= current_user.email.split('@').first %></h1>
    <p class="muted" style="margin:0;font-size:0.82rem;">
      Member since <%= current_user.created_at.strftime('%b %Y') %>
      <% if @rank %> · Rank #<%= @rank %><% end %>
    </p>
  </div>
  <div style="margin-left:auto;">
    <div style="background:#ecf7f3;border:1px solid #d0e8de;border-radius:12px;padding:12px 18px;text-align:right;">
      <div class="stat-label">Wallet balance</div>
      <div style="font-size:1.5rem;font-weight:800;color:var(--accent);" data-testid="wallet-available"><%= number_with_delimiter(@wallet.available_minor) %> ADIV</div>
    </div>
  </div>
</div>

<%# 4-stat grid %>
<div class="stat-grid" style="grid-template-columns:repeat(4,1fr);margin-bottom:20px;" data-testid="profile-stats">
  <div class="stat-card">
    <div class="stat-label">Net P&amp;L</div>
    <div class="stat-value" style="color:<%= @pnl[:net_pnl] >= 0 ? 'var(--accent)' : '#c0392b' %>;" data-testid="pnl-net">
      <%= @pnl[:net_pnl] >= 0 ? '+' : '' %><%= number_with_delimiter(@pnl[:net_pnl]) %>
    </div>
  </div>
  <div class="stat-card">
    <div class="stat-label">Total bets</div>
    <div class="stat-value"><%= @pnl[:won_count].to_i + @pnl[:lost_count].to_i + @pnl[:open_count].to_i %></div>
  </div>
  <div class="stat-card">
    <div class="stat-label">Win rate</div>
    <div class="stat-value"><%= @pnl[:win_rate] ? "#{@pnl[:win_rate]}%" : "—" %></div>
  </div>
  <div class="stat-card">
    <div class="stat-label">Volume</div>
    <div class="stat-value"><%= number_with_delimiter(@pnl[:total_staked]) %></div>
  </div>
</div>
```

Remove the old separate wallet card and P&L panel from the 2-column grid.

- [ ] **Step 2.3: Add pending faucet banner**

After the header block:

```erb
<% if @pending_faucet %>
  <div style="background:#fef3e2;border:1px solid #f0dfc0;border-radius:10px;padding:12px 16px;margin-bottom:16px;display:flex;align-items:center;gap:10px;" data-testid="pending-faucet-banner">
    <span style="font-size:1.1rem;">⏳</span>
    <div>
      <strong>Faucet request pending</strong>
      <span class="muted" style="margin-left:6px;">Requested <%= number_with_delimiter(@pending_faucet.amount_minor) %> ADIV — awaiting moderator approval.</span>
    </div>
  </div>
<% end %>
```

- [ ] **Step 2.4: Add faucet reason field and improve faucet card**

Replace the `<details>` faucet block with a standalone card:

```erb
<section class="card" style="margin-bottom:20px;" data-testid="faucet-card">
  <h3 style="margin-top:0;">Request ADIV top-up</h3>
  <p class="muted" style="font-size:0.85rem;margin-bottom:12px;">Out of play money? Request more from a moderator.</p>
  <% if @pending_faucet %>
    <p class="muted" style="font-size:0.85rem;">You already have a pending request. Wait for it to be reviewed.</p>
  <% else %>
    <%= form_with url: web_faucet_requests_path, method: :post, data: { testid: "faucet-request-form" } do |f| %>
      <div style="display:flex;gap:10px;flex-wrap:wrap;margin-bottom:10px;">
        <div style="flex:1;min-width:120px;">
          <label style="font-size:0.82rem;color:var(--muted);">Amount (ADIV)</label>
          <input type="number" name="amount_minor" value="10000" min="100" max="100000"
                 style="margin-top:4px;" data-testid="faucet-amount">
        </div>
        <div style="flex:2;min-width:180px;">
          <label style="font-size:0.82rem;color:var(--muted);">Reason (optional)</label>
          <input type="text" name="reason" placeholder="e.g. lost all in a CLOB trade"
                 style="margin-top:4px;" data-testid="faucet-reason">
        </div>
      </div>
      <%= f.submit "Request top-up", data: { testid: "faucet-submit" } %>
    <% end %>
  <% end %>
</section>
```

- [ ] **Step 2.5: Add open positions summary card**

Below the faucet card in the right column (or after the bet history section on mobile):

```erb
<section class="card" style="margin-bottom:16px;" data-testid="positions-summary-card">
  <h3 style="margin-top:0;">Open Positions</h3>
  <% if @open_positions_summary.values.sum == 0 %>
    <p class="muted" style="font-size:0.85rem;">No open positions.</p>
  <% else %>
    <% [['Fixed-odds & Parimutuel bets', @open_positions_summary[:fixed_odds]], ['CLOB orders/contracts', @open_positions_summary[:clob]], ['LMSR positions', @open_positions_summary[:lmsr]]].each do |label, count| %>
      <% next if count.zero? %>
      <div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--border);">
        <span style="font-size:0.88rem;"><%= label %></span>
        <span style="font-size:0.88rem;font-weight:700;color:var(--accent);"><%= count %></span>
      </div>
    <% end %>
  <% end %>
  <div style="margin-top:10px;">
    <%= link_to "View all positions →", web_positions_path, class: "pill pill-outline", style: "font-size:0.82rem;" %>
  </div>
</section>
```

- [ ] **Step 2.6: Run integration tests for profile**

```bash
bin/rails test test/integration/web/profile_test.rb -v
```
Expected: existing tests pass; add assertions for the new banner/card if tests exist.

- [ ] **Step 2.7: Commit**

```bash
git add app/views/web/profile/show.html.erb app/controllers/web/profile_controller.rb
git commit -m "feat(web): profile — avatar header, 4-stat grid, pending-faucet banner, reason field, positions summary card"
```

---

## Task 3: Auth page — add register form + post-register faucet nudge

**Files:**
- Modify: `app/views/web/sessions/new.html.erb`
- Check: `config/routes.rb` for existing register route
- Check: `app/controllers/auth/sessions_controller.rb` for register action

- [ ] **Step 3.1: Verify register route exists**

```bash
bin/rails routes | grep register
```
Expected: `POST /register` route present. If not, it's already defined under `auth/sessions`.

- [ ] **Step 3.2: Add tabbed sign-in / register layout**

Replace `app/views/web/sessions/new.html.erb`:

```erb
<div style="display:flex;justify-content:center;padding:40px 20px;">
  <div style="width:100%;max-width:400px;">
    <%# Tab switcher %>
    <div style="display:flex;gap:0;margin-bottom:20px;border:1px solid var(--border);border-radius:10px;overflow:hidden;">
      <button type="button" id="tab-signin"
              onclick="showTab('signin')"
              style="flex:1;padding:10px;border:0;background:var(--accent);color:#fff;font-weight:600;cursor:pointer;font:inherit;">
        Sign in
      </button>
      <button type="button" id="tab-register"
              onclick="showTab('register')"
              style="flex:1;padding:10px;border:0;background:transparent;color:var(--muted);cursor:pointer;font:inherit;">
        Register
      </button>
    </div>

    <%# Sign-in form %>
    <div id="panel-signin" class="card" style="padding:22px;">
      <h2 style="margin:0 0 4px;">Welcome back</h2>
      <p class="muted" style="margin:0 0 18px;font-size:0.88rem;">Sign in to bet and track your positions.</p>
      <%= form_with url: "/signin", method: :post, html: { data: { testid: "signin-form" } } do |f| %>
        <p><label>Email</label><br><%= f.email_field :email, required: true, data: { testid: "signin-email" } %></p>
        <p><label>Password</label><br><%= f.password_field :password, required: true, data: { testid: "signin-password" } %></p>
        <p><%= f.submit "Sign in", data: { testid: "signin-submit" }, style: "width:100%;" %></p>
      <% end %>
    </div>

    <%# Register form %>
    <div id="panel-register" class="card" style="padding:22px;display:none;">
      <h2 style="margin:0 0 4px;">Create account</h2>
      <p class="muted" style="margin:0 0 18px;font-size:0.88rem;">No real money — play with ADIV fantasy tokens.</p>
      <%= form_with url: "/register", method: :post, html: { data: { testid: "register-form" } } do |f| %>
        <p><label>Email</label><br><%= f.email_field :email, required: true, data: { testid: "register-email" } %></p>
        <p><label>Password</label><br><%= f.password_field :password, required: true, minlength: 8, data: { testid: "register-password" } %></p>
        <p><%= f.submit "Create account", data: { testid: "register-submit" }, style: "width:100%;" %></p>
      <% end %>
      <div style="margin-top:14px;padding:12px;background:#f4f9f7;border-radius:8px;font-size:0.82rem;" data-testid="register-nudge">
        <strong>After registering:</strong> request free ADIV tokens from your profile to start betting.
      </div>
    </div>

    <script>
      function showTab(tab) {
        document.getElementById('panel-signin').style.display   = tab === 'signin'   ? '' : 'none';
        document.getElementById('panel-register').style.display = tab === 'register' ? '' : 'none';
        document.getElementById('tab-signin').style.background   = tab === 'signin'   ? 'var(--accent)' : 'transparent';
        document.getElementById('tab-signin').style.color        = tab === 'signin'   ? '#fff' : 'var(--muted)';
        document.getElementById('tab-register').style.background = tab === 'register' ? 'var(--accent)' : 'transparent';
        document.getElementById('tab-register').style.color      = tab === 'register' ? '#fff' : 'var(--muted)';
      }
      <% if params[:tab] == 'register' %>
        showTab('register');
      <% end %>
    </script>
  </div>
</div>
```

- [ ] **Step 3.3: Verify register controller sends user to profile with faucet nudge**

After a successful registration, the controller should redirect to `web_profile_path` with a flash notice:
```
"Welcome! Request ADIV tokens to start betting."
```
Check `app/controllers/auth/sessions_controller.rb` — if the redirect is to `/` or `/signin`, change it to `web_profile_path`.

- [ ] **Step 3.4: Run auth integration tests**

```bash
bin/rails test test/integration/auth_test.rb -v
```
Expected: all pass

- [ ] **Step 3.5: Commit**

```bash
git add app/views/web/sessions/new.html.erb app/controllers/auth/sessions_controller.rb
git commit -m "feat(web): auth — tabbed sign-in/register, post-register faucet nudge"
```

---

## Task 4: Positions page — apply design system

**Files:**
- Modify: `app/views/web/positions/index.html.erb`

The current positions page uses plain `<table>` without the card/stat-grid design system. Apply consistent styling.

- [ ] **Step 4.1: Restyle positions view with card system**

Rewrite `app/views/web/positions/index.html.erb` using the `card`, `stat-grid`, `badge`, `muted` CSS classes and ensuring table cells match the rest of the web surface. Key additions: market question links styled as ink (not accent), stat chips for YES/NO contracts, cashout button where applicable.

Key structural change: wrap each section in `<section class="card">`, replace inline styles with CSS classes from the design system.

- [ ] **Step 4.2: Commit**

```bash
git add app/views/web/positions/index.html.erb
git commit -m "feat(web): positions — apply design system, card sections, stat styling"
```

---

## Task 5: Update docs

- [ ] Append entry to `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` — add to Done list
- [ ] Commit: `docs: update INDEX and WORK_LOG after ux-leaderboard-profile-auth`

---

## Open Design Questions

1. **Register endpoint**: If `POST /register` is a JSON-only endpoint (in the `admin` namespace), the register form tab needs a separate web-scoped session register action. Check: `bin/rails routes | grep register`. If it's JSON-only, this task requires adding `POST /web/register` under the web sessions controller.

2. **Win rate / bet count on leaderboard**: The current leaderboard query may not include `win_count`/`total_bets`. Adding them requires extending the leaderboard SQL. If the query is in a dedicated service, extend it there. If it's inline in the controller, add a subquery.

3. **Rank computation**: Computing every user's rank on every profile load is O(n) over all users. For a POC this is fine; index on `created_at` on `ledger_entries` if it's slow.

---

## Self-Review Checklist
- [ ] All existing auth tests still pass
- [ ] Profile page gracefully handles missing `@pending_faucet` (nil)
- [ ] Positions summary card handles 0 open positions
- [ ] Full test suite passes: `bin/rails test`
