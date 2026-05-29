# UX — Settlement Explainer Page (/web/settlement)

<!-- File location: docs/superpowers/plans/2026-05-29-ux-settlement-explainer-page.md -->

**Goal:** Create the `/web/settlement` static explainer page ("How markets settle") specified in the wireframes, and wire it into every market's resolution panel and settled/closed banner. The page covers the lifecycle diagram, four mechanism payout cards, disputes overview, and the trust model.

**Architecture:** New static controller action + view + route. No DB queries needed (entirely static content). Links added to `web/markets/show.html.erb` resolution panel and closed/settled banners. No migrations.

**Tech Stack:** Rails 8 ERB, existing customer web CSS design system, Minitest.

**Spec:** `docs/design/03-settlement-and-resolution.md`, `docs/design/wireframes/v1/wireframes-additions.jsx` (`WFExtra.Settlement`).

---

## File Map

**Create:**
- `app/views/web/settlement/index.html.erb` — the explainer page

**Modify:**
- `config/routes.rb` — add `get 'web/settlement', to: 'web/settlement#index', as: :web_settlement`
- `app/controllers/web/settlement_controller.rb` — new static controller
- `app/views/web/markets/show.html.erb` — add "How does settlement work?" link in resolution panel and settled/closed banners
- `app/views/layouts/application.html.erb` — no change needed (nav link is optional for this slice)
- `test/integration/web/settlement_test.rb` — basic render test

---

## Task 1: Route + controller + view

**Files:**
- Create: `app/controllers/web/settlement_controller.rb`
- Create: `app/views/web/settlement/index.html.erb`
- Modify: `config/routes.rb`
- Test: `test/integration/web/settlement_test.rb`

- [ ] **Step 1.1: Write failing test**

```ruby
# test/integration/web/settlement_test.rb
require "test_helper"

class Web::SettlementTest < ActionDispatch::IntegrationTest
  test "GET /web/settlement renders lifecycle and mechanism cards" do
    get web_settlement_path
    assert_response :success
    assert_select "[data-testid='settlement-lifecycle']"
    assert_select "[data-testid='settlement-mechanism-fixed-odds']"
    assert_select "[data-testid='settlement-mechanism-clob']"
    assert_select "[data-testid='settlement-mechanism-lmsr']"
    assert_select "[data-testid='settlement-mechanism-parimutuel']"
    assert_select "[data-testid='settlement-trust']"
  end
end
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
bin/rails test test/integration/web/settlement_test.rb -v
```
Expected: FAIL with routing error (route not defined)

- [ ] **Step 1.3: Add route**

In `config/routes.rb`, inside the `scope '/web'` (or wherever `web_` routes are defined — check current routes structure):

```ruby
get '/web/settlement', to: 'web/settlement#index', as: :web_settlement
```

- [ ] **Step 1.4: Create the controller**

```ruby
# app/controllers/web/settlement_controller.rb
class Web::SettlementController < Web::BaseController
  def index
  end
end
```

- [ ] **Step 1.5: Create the view**

```erb
<%# app/views/web/settlement/index.html.erb %>

<div style="max-width:960px;margin:0 auto;">
  <div style="margin-bottom:8px;"><%= link_to "← Markets", web_markets_path, class: "muted" %></div>

  <h1 style="margin:0 0 6px;">How markets settle</h1>
  <p class="muted" style="margin:0 0 28px;">Every payout is recorded as an append-only ledger entry — settlement is idempotent and fully audited.</p>

  <%# Lifecycle diagram %>
  <section style="margin-bottom:32px;" data-testid="settlement-lifecycle">
    <h3 style="margin:0 0 14px;">Market lifecycle</h3>
    <div style="display:flex;align-items:stretch;gap:0;overflow-x:auto;">
      <% [
        ['Open', 'Accepting bets — prices live', 'var(--accent)'],
        ['Closed', 'close_at passed — no new bets', '#8a5c10'],
        ['Resolution', 'Moderator declares outcome + evidence', 'var(--accent)'],
        ['Dispute', 'Optional window to contest (coming soon)', '#8a5c10'],
        ['Settled', 'Payouts credited · ledger written', '#0e7c66'],
      ].each_with_index do |(title, desc, color), i| %>
        <% unless i == 0 %>
          <div style="align-self:center;color:var(--muted);font-size:1.2rem;padding:0 6px;flex-shrink:0;">→</div>
        <% end %>
        <div style="flex:1;min-width:140px;" data-testid="lifecycle-step-<%= title.downcase.gsub(' ','-') %>">
          <div style="display:flex;align-items:center;gap:7px;margin-bottom:5px;">
            <span style="width:22px;height:22px;border-radius:50%;background:<%= color %>;color:#fff;font-size:0.7rem;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;"><%= i + 1 %></span>
            <strong style="font-size:0.9rem;"><%= title %></strong>
          </div>
          <p class="muted" style="font-size:0.8rem;margin:0;padding-right:10px;"><%= desc %></p>
        </div>
      <% end %>
    </div>
  </section>

  <%# Payout by mechanism %>
  <section style="margin-bottom:32px;">
    <h3 style="margin:0 0 14px;">Payout by mechanism</h3>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
      <div class="card" data-testid="settlement-mechanism-fixed-odds">
        <span class="badge" style="margin-bottom:10px;display:inline-block;">Fixed-odds</span>
        <p style="font-size:0.9rem;line-height:1.6;margin:0;">
          Winning bets are paid <code>stake ÷ implied_probability</code>. The house covered the opposite side.
          Losing bets pay 0. Fee deducted from gross payout at placement.
        </p>
      </div>
      <div class="card" data-testid="settlement-mechanism-clob">
        <span class="badge" style="margin-bottom:10px;display:inline-block;">CLOB</span>
        <p style="font-size:0.9rem;line-height:1.6;margin:0;">
          Each winning contract redeems for <strong>1 ADIV</strong>; losing contracts expire at 0.
          Open and partially filled orders are cancelled first and reserved funds are released.
        </p>
      </div>
      <div class="card" data-testid="settlement-mechanism-lmsr">
        <span class="badge" style="margin-bottom:10px;display:inline-block;">LMSR</span>
        <p style="font-size:0.9rem;line-height:1.6;margin:0;">
          The winning outcome is declared. Winning shares pay out 1 ADIV per contract from the liquidity subsidy.
          Your position is tracked in the LMSR positions ledger.
        </p>
      </div>
      <div class="card" data-testid="settlement-mechanism-parimutuel">
        <span class="badge" style="margin-bottom:10px;display:inline-block;">Parimutuel</span>
        <p style="font-size:0.9rem;line-height:1.6;margin:0;">
          The winning pool splits the total pool minus takeout, pro-rata to stake.
          If no one backed the winning side, all stakes are refunded.
        </p>
      </div>
    </div>
  </section>

  <%# Trust model %>
  <section style="margin-bottom:32px;" data-testid="settlement-trust">
    <h3 style="margin:0 0 14px;">Why you can trust it</h3>
    <div class="card">
      <% [
        ['Append-only ledger', 'Balances are derived from ledger entries. No silent balance edits.'],
        ['Idempotent settlement', 'Running settlement twice never double-credits (settlement_items are unique per user/outcome).'],
        ['Separation of duties', 'Market creator ≠ resolver (configurable per community).'],
        ['Full audit trail', 'Every state transition writes an audit_event (before/after state).'],
      ].each do |title, desc| %>
        <div style="display:flex;gap:10px;align-items:flex-start;padding:8px 0;border-bottom:1px solid var(--border);">
          <span style="color:var(--accent);font-weight:800;font-size:1rem;flex-shrink:0;">✓</span>
          <div>
            <strong style="font-size:0.9rem;"><%= title %></strong>
            <p class="muted" style="font-size:0.82rem;margin:2px 0 0;"><%= desc %></p>
          </div>
        </div>
      <% end %>
    </div>
  </section>

  <%# Disputes (coming soon) %>
  <section style="margin-bottom:20px;" data-testid="settlement-disputes">
    <h3 style="margin:0 0 14px;">Disputes</h3>
    <div class="card" style="border-color:#f0dfc0;">
      <p style="font-size:0.9rem;line-height:1.6;margin:0;">
        During the dispute window any participant can contest the result with a reason.
        A Resolver reviews the evidence and finalises or reverses the outcome.
        Dispute states: <span class="badge">Open</span> <span class="badge">Accepted</span> <span class="badge">Rejected</span> <span class="badge">Reversed</span>
      </p>
      <p class="muted" style="font-size:0.8rem;margin:8px 0 0;">Dispute window UI coming in a future release.</p>
    </div>
  </section>

  <div style="margin-top:20px;text-align:center;">
    <%= link_to "Browse markets", web_markets_path, class: "pill pill-outline" %>
  </div>
</div>
```

- [ ] **Step 1.6: Run test to verify it passes**

```bash
bin/rails test test/integration/web/settlement_test.rb -v
```
Expected: PASS

- [ ] **Step 1.7: Commit**

```bash
git add config/routes.rb app/controllers/web/settlement_controller.rb app/views/web/settlement/index.html.erb test/integration/web/settlement_test.rb
git commit -m "feat(web): add /web/settlement explainer page"
```

---

## Task 2: Link from market resolution panel and banners

**Files:**
- Modify: `app/views/web/markets/show.html.erb`

- [ ] **Step 2.1: Add link to resolution panel**

In the existing resolution details section, after the "Resolution details" heading, append:

```erb
<span style="float:right;font-size:0.78rem;">
  <%= link_to "How does settlement work? →", web_settlement_path, data: { testid: "settlement-explainer-link" } %>
</span>
```

- [ ] **Step 2.2: Add link to closed and settled banners**

In the closed-market banner:
```erb
<a href="<%= web_settlement_path %>" style="color:#f0bc5c;font-size:0.82rem;margin-left:10px;">Learn more →</a>
```

In the settled outcome banner (inside the resolution panel's settled block):
```erb
<p style="font-size:0.82rem;margin:6px 0 0;">
  <%= link_to "See how payouts were calculated →", web_settlement_path, data: { testid: "payout-explainer-link" } %>
</p>
```

- [ ] **Step 2.3: Run full suite**

```bash
bin/rails test
```
Expected: ≥ 90% coverage, 0 failures

- [ ] **Step 2.4: Commit**

```bash
git add app/views/web/markets/show.html.erb
git commit -m "feat(web): link settlement explainer from market resolution panels"
```

---

## Task 3: Update docs

- [ ] Append entry to `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` — add to Done list
- [ ] Commit: `docs: update INDEX and WORK_LOG after ux-settlement-explainer-page`

---

## Open Design Questions

1. **Route namespace**: Check whether the existing web routes use `scope '/web'` or `namespace :web`. The controller inherits from `Web::BaseController`; the route path format must match. Run `bin/rails routes | grep web` to verify.

2. **Nav link for settlement**: The wireframe shows the settlement page linked from the market resolution panel but not from the top nav. A nav link could be added later. This plan only adds it as a contextual link, keeping the nav uncluttered.

---

## Self-Review Checklist
- [ ] `/web/settlement` renders for both guests and logged-in players
- [ ] All four mechanism cards present with correct data-testid values
- [ ] Links in market show page point to the correct named route
- [ ] Full test suite passes: `bin/rails test`
