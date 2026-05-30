# Market Price History Implementation Plan (D6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the existing `PriceSnapshot` data as a `/web/markets/:id/price_history` JSON endpoint and a simple server-rendered SVG line chart on the market detail page, and wire snapshot recording into the four market-mutating services so the chart has data.

**Architecture:** Add a stateless serializer that normalizes any mechanism's `snapshot_data` to a `{ t:, yes: }` series; a read-only `Web::PriceHistoryController#index` returning that series as JSON; a server-side SVG partial rendered on `markets/show`; and `RecordPriceSnapshotJob.perform_later` calls after each mutating service's transaction commits. No new tables. Recording is best-effort and never participates in the trade transaction.

**Tech Stack:** Rails 8, Minitest, existing patterns (see docs/INDEX.md). No npm/JS chart library.

**Spec:** `docs/specs/2026-05-30-price-history.md`

---

## File Map

**Create:**
- `app/serializers/price_series_serializer.rb` — normalizes snapshots → `[{ t:, yes: }]`
- `test/serializers/price_series_serializer_test.rb`
- `app/controllers/web/price_history_controller.rb`
- `test/integration/web_price_history_test.rb`
- `app/views/web/markets/_price_history.html.erb` — server-side SVG chart partial
- `test/integration/web_price_history_chart_test.rb`

**Modify:**
- `config/routes.rb` — add nested `price_history` route under `web/markets`
- `app/services/bet_placement_service.rb` — enqueue snapshot after commit
- `app/services/clob/order_matching_service.rb` — enqueue snapshot after commit
- `app/services/lmsr/lmsr_trade_service.rb` — enqueue snapshot after commit
- `app/services/parimutuel/parimutuel_pool_service.rb` — enqueue snapshot after commit
- `app/views/web/markets/show.html.erb` — render the price_history partial
- `docs/wiki/tech-debt-backlog.md` — add TD-035 (retention follow-up)
- `docs/WORK_LOG.md`, `docs/INDEX.md` — status

---

## Task 1: Price series normalization serializer

**Files:**
- Create: `app/serializers/price_series_serializer.rb`
- Test: `test/serializers/price_series_serializer_test.rb`

- [ ] **Step 1.1: Write the failing test**

```ruby
# test/serializers/price_series_serializer_test.rb
require 'test_helper'

class PriceSeriesSerializerTest < ActiveSupport::TestCase
  def snap(mechanism, data, at)
    PriceSnapshot.new(mechanism_type: mechanism, snapshot_data: data, recorded_at: at)
  end

  test 'fixed_odds maps YES leg odds_minor to percentage' do
    s = snap('fixed_odds', { 'legs' => [{ 'label' => 'YES', 'odds_minor' => 5000 }, { 'label' => 'NO', 'odds_minor' => 5000 }] }, Time.utc(2026, 5, 30, 10))
    assert_equal [{ t: '2026-05-30T10:00:00Z', yes: 50.0 }], PriceSeriesSerializer.call([s])
  end

  test 'clob uses bid then 100-ask, skips when both nil' do
    pts = PriceSeriesSerializer.call([
      snap('clob', { 'bid' => 41, 'ask' => 60 }, Time.utc(2026, 5, 30, 10)),
      snap('clob', { 'bid' => nil, 'ask' => 55 }, Time.utc(2026, 5, 30, 10, 5)),
      snap('clob', { 'bid' => nil, 'ask' => nil }, Time.utc(2026, 5, 30, 10, 10))
    ])
    assert_equal [{ t: '2026-05-30T10:00:00Z', yes: 41.0 }, { t: '2026-05-30T10:05:00Z', yes: 45.0 }], pts
  end

  test 'lmsr and parimutuel use yes_probability' do
    assert_equal 63.0, PriceSeriesSerializer.call([snap('lmsr', { 'yes_probability' => 63.0 }, Time.utc(2026, 5, 30))]).first[:yes]
    assert_equal 20.0, PriceSeriesSerializer.call([snap('parimutuel', { 'yes_probability' => 20.0 }, Time.utc(2026, 5, 30))]).first[:yes]
  end
end
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
bin/rails test test/serializers/price_series_serializer_test.rb -v
```
Expected: FAIL with `uninitialized constant PriceSeriesSerializer`

- [ ] **Step 1.3: Implement minimal code**

```ruby
# app/serializers/price_series_serializer.rb
class PriceSeriesSerializer
  def self.call(snapshots)
    snapshots.filter_map do |s|
      yes = yes_percentage(s)
      next if yes.nil?

      { t: s.recorded_at.utc.iso8601, yes: yes.to_f.round(2) }
    end
  end

  def self.yes_percentage(snapshot)
    d = snapshot.snapshot_data || {}
    case snapshot.mechanism_type
    when 'fixed_odds'
      leg = Array(d['legs']).find { |l| l['label'] == 'YES' }
      leg && leg['odds_minor'].to_f / 100.0
    when 'clob'
      if d['bid'] then d['bid'].to_f
      elsif d['ask'] then 100.0 - d['ask'].to_f
      end
    when 'lmsr', 'parimutuel'
      d['yes_probability']&.to_f
    end
  end
end
```

- [ ] **Step 1.4: Run test to verify it passes**

```bash
bin/rails test test/serializers/price_series_serializer_test.rb -v
```
Expected: PASS

- [ ] **Step 1.5: Commit**

```bash
git add app/serializers/price_series_serializer.rb test/serializers/price_series_serializer_test.rb
git commit -m "feat(price-history): add PriceSeriesSerializer normalizing snapshots"
```

---

## Task 2: JSON endpoint

**Files:**
- Create: `app/controllers/web/price_history_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/integration/web_price_history_test.rb`

- [ ] **Step 2.1: Write the failing test**

```ruby
# test/integration/web_price_history_test.rb
require 'test_helper'

class WebPriceHistoryTest < ActionDispatch::IntegrationTest
  setup { @market = markets(:clob_market) }

  test 'returns ascending points for a market with snapshots' do
    PriceSnapshot.create!(market: @market, mechanism_type: 'clob', snapshot_data: { bid: 40 }, recorded_at: 2.minutes.ago)
    PriceSnapshot.create!(market: @market, mechanism_type: 'clob', snapshot_data: { bid: 45 }, recorded_at: 1.minute.ago)

    get "/web/markets/#{@market.id}/price_history.json"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @market.id, body['market_id']
    assert_equal [40.0, 45.0], body['points'].map { |p| p['yes'] }
  end

  test 'empty market returns 200 with empty points' do
    get "/web/markets/#{@market.id}/price_history.json"

    assert_response :success
    assert_equal [], JSON.parse(response.body)['points']
  end

  test 'limit returns the most recent N points' do
    5.times { |i| PriceSnapshot.create!(market: @market, mechanism_type: 'clob', snapshot_data: { bid: 30 + i }, recorded_at: (5 - i).minutes.ago) }

    get "/web/markets/#{@market.id}/price_history.json?limit=2"

    points = JSON.parse(response.body)['points']
    assert_equal 2, points.size
    assert_equal [33.0, 34.0], points.map { |p| p['yes'] }
  end
end
```

- [ ] **Step 2.2: Run test to verify it fails**

```bash
bin/rails test test/integration/web_price_history_test.rb -v
```
Expected: FAIL — `No route matches [GET] "/web/markets/.../price_history"`

- [ ] **Step 2.3: Add the route**

In `config/routes.rb`, inside the existing `namespace :web do … resources :markets, only: %i[index show] do` block (next to `get :order_book`), add:

```ruby
      get :price_history, to: 'price_history#index'
```

- [ ] **Step 2.4: Implement the controller**

```ruby
# app/controllers/web/price_history_controller.rb
module Web
  class PriceHistoryController < BaseController
    def index
      market = Market.find(params.expect(:market_id))
      limit = params.fetch(:limit, 500).to_i.clamp(1, 1000)
      snapshots = market.price_snapshots.order(recorded_at: :asc).last(limit)

      render json: {
        market_id: market.id,
        mechanism_type: market.mechanism_type,
        points: PriceSeriesSerializer.call(snapshots)
      }
    end
  end
end
```

Add the association in `app/models/market.rb` (after `has_many :lmsr_positions`):

```ruby
  has_many :price_snapshots, dependent: :destroy
```

> Note: `Web::BaseController` already permits optional/auth reads for `/web/markets`; confirm the `price_history` path is reachable for guests (it is — it is under `/web/markets`). If `BaseController` requires auth for nested routes, add `skip_before_action :authenticate_request!, only: :index` mirroring how `order_books_controller` is reached.

- [ ] **Step 2.5: Run test to verify it passes**

```bash
bin/rails test test/integration/web_price_history_test.rb -v
```
Expected: PASS

- [ ] **Step 2.6: Commit**

```bash
git add app/controllers/web/price_history_controller.rb config/routes.rb app/models/market.rb test/integration/web_price_history_test.rb
git commit -m "feat(price-history): add /web/markets/:id/price_history JSON endpoint"
```

---

## Task 3: Wire snapshot recording into the four mutating services

Each mutating service currently never records a snapshot. Enqueue `RecordPriceSnapshotJob.perform_later(market.id)` **after** the service's DB transaction commits (so a failed trade records nothing and recording never rolls back the trade).

**Files:**
- Modify: `app/services/bet_placement_service.rb`, `app/services/clob/order_matching_service.rb`, `app/services/lmsr/lmsr_trade_service.rb`, `app/services/parimutuel/parimutuel_pool_service.rb`
- Test: `test/services/price_snapshot_wiring_test.rb`

- [ ] **Step 3.1: Write the failing test**

```ruby
# test/services/price_snapshot_wiring_test.rb
require 'test_helper'

class PriceSnapshotWiringTest < ActiveJob::TestCase
  test 'placing a fixed-odds bet enqueues a snapshot job for the market' do
    market = markets(:open_market)
    leg = market.market_legs.find_by!(label: 'YES')
    user = users(:player)
    user.wallet.update!(available_minor: 100_000)

    assert_enqueued_with(job: RecordPriceSnapshotJob, args: [market.id]) do
      BetPlacementService.place!(user: user, market: market, market_leg: leg, stake_minor: 1000)
    end
  end
end
```

- [ ] **Step 3.2: Run test to verify it fails**

```bash
bin/rails test test/services/price_snapshot_wiring_test.rb -v
```
Expected: FAIL — `No enqueued job found with {job: RecordPriceSnapshotJob, args: [<id>]}`

- [ ] **Step 3.3: Enqueue after commit in `BetPlacementService`**

In `app/services/bet_placement_service.rb`, the method returns the bet from inside the `ApplicationRecord.transaction do … end` block. Capture the bet, then enqueue after the block:

```ruby
    bet = ApplicationRecord.transaction do
      wallet = user.wallet.lock!
      raise InvalidBet, 'Insufficient wallet balance' if wallet.available_minor < stake_minor.to_i

      wallet.update!(available_minor: wallet.available_minor - stake_minor.to_i)
      # … existing Bet.create!, LedgerEntry.create!, AuditEvent.create! …
      bet
    end

    RecordPriceSnapshotJob.perform_later(market.id)
    bet
```

- [ ] **Step 3.4: Apply the same after-commit enqueue to the other three services**

- `app/services/clob/order_matching_service.rb`: in `call`, after the `ApplicationRecord.transaction do … end` returns its `Result` (assign it to `result`, then `RecordPriceSnapshotJob.perform_later(@market.id) if result.success?`, then `result`). Place it in the `call` method body, **not** inside the `rescue`.
- `app/services/lmsr/lmsr_trade_service.rb`: after the transaction commits successfully, `RecordPriceSnapshotJob.perform_later(@market.id)`.
- `app/services/parimutuel/parimutuel_pool_service.rb`: after the stake transaction commits, `RecordPriceSnapshotJob.perform_later(@market.id)`.

(Read each service first; enqueue on the success path only, after the transaction block.)

- [ ] **Step 3.5: Run the wiring test + the four service test suites**

```bash
bin/rails test test/services/price_snapshot_wiring_test.rb test/services/bet_placement_service_test.rb test/services/clob/order_matching_service_test.rb test/services/lmsr/lmsr_trade_service_test.rb test/services/parimutuel -v
```
Expected: PASS (no regressions; the wiring test passes)

- [ ] **Step 3.6: Commit**

```bash
git add app/services/bet_placement_service.rb app/services/clob/order_matching_service.rb app/services/lmsr/lmsr_trade_service.rb app/services/parimutuel/parimutuel_pool_service.rb test/services/price_snapshot_wiring_test.rb
git commit -m "feat(price-history): record a price snapshot after each market-mutating trade"
```

---

## Task 4: Server-side SVG chart on the market detail page

**Files:**
- Create: `app/views/web/markets/_price_history.html.erb`
- Modify: `app/views/web/markets/show.html.erb`, `app/controllers/web/markets_controller.rb` (load `@price_points`)
- Test: `test/integration/web_price_history_chart_test.rb`

- [ ] **Step 4.1: Write the failing test**

```ruby
# test/integration/web_price_history_chart_test.rb
require 'test_helper'

class WebPriceHistoryChartTest < ActionDispatch::IntegrationTest
  setup { @market = markets(:clob_market) }

  test 'renders the chart svg when at least two points exist' do
    PriceSnapshot.create!(market: @market, mechanism_type: 'clob', snapshot_data: { bid: 40 }, recorded_at: 2.minutes.ago)
    PriceSnapshot.create!(market: @market, mechanism_type: 'clob', snapshot_data: { bid: 45 }, recorded_at: 1.minute.ago)

    get "/web/markets/#{@market.id}"

    assert_response :success
    assert_select '[data-testid="price-history"] svg polyline'
  end

  test 'renders empty state when fewer than two points' do
    get "/web/markets/#{@market.id}"

    assert_select '[data-testid="price-history"]', text: /Not enough price history/
  end
end
```

- [ ] **Step 4.2: Run test to verify it fails**

```bash
bin/rails test test/integration/web_price_history_chart_test.rb -v
```
Expected: FAIL — no `[data-testid="price-history"]` element

- [ ] **Step 4.3: Load points in the controller**

In `app/controllers/web/markets_controller.rb#show`, add:

```ruby
      @price_points = PriceSeriesSerializer.call(@market.price_snapshots.order(recorded_at: :asc).last(500))
```

- [ ] **Step 4.4: Create the partial (inline SVG, scales points to a 600×120 viewbox)**

```erb
<%# app/views/web/markets/_price_history.html.erb %>
<section data-testid="price-history">
  <h3>Price history</h3>
  <% if @price_points.size < 2 %>
    <p class="muted">Not enough price history yet.</p>
  <% else %>
    <%
      w = 600.0; h = 120.0
      n = @price_points.size
      coords = @price_points.each_with_index.map do |p, i|
        x = (i.to_f / (n - 1)) * w
        y = h - (p[:yes].to_f / 100.0) * h
        "#{x.round(1)},#{y.round(1)}"
      end.join(' ')
    %>
    <svg viewBox="0 0 600 120" width="100%" height="120" role="img" aria-label="YES price over time">
      <polyline fill="none" stroke="#0e7c66" stroke-width="2" points="<%= coords %>" />
    </svg>
    <p class="muted">YES probability/price over the last <%= @price_points.size %> updates.</p>
  <% end %>
</section>
```

- [ ] **Step 4.5: Render the partial in `markets/show.html.erb`**

Add near the price/trust panels (after the market summary, before the bet form):

```erb
<%= render 'price_history' %>
```

- [ ] **Step 4.6: Run test to verify it passes**

```bash
bin/rails test test/integration/web_price_history_chart_test.rb -v
```
Expected: PASS

- [ ] **Step 4.7: Commit**

```bash
git add app/views/web/markets/_price_history.html.erb app/views/web/markets/show.html.erb app/controllers/web/markets_controller.rb test/integration/web_price_history_chart_test.rb
git commit -m "feat(price-history): render server-side SVG price chart on market detail"
```

---

## Task 5: Retention follow-up + docs

- [ ] **Step 5.1: Add TD-035 to `docs/wiki/tech-debt-backlog.md`**

```markdown
### TD-035 · price_snapshots retention / pruning

**Status:** Open. Deferred from D6 price-history (2026-05-30).
**Problem:** Snapshots are now recorded on every market-mutating trade and never pruned; `price_snapshots` grows unbounded. `snapshot_data` is also `json` not `jsonb`.
**Fix:** Add a `PrunePriceSnapshotsJob` (retain last N per market or older-than policy) and migrate `snapshot_data` to `jsonb` (folds into TD-024). Decide downsampling for long ranges when the time-range selector lands.
**Impact:** Low near-term (POC volumes), Medium at scale.
```

- [ ] **Step 5.2: Update `docs/WORK_LOG.md` and `docs/INDEX.md`** (price-history endpoint + chart done; recording wired).

- [ ] **Step 5.3: Commit**

```bash
git commit -am "docs: update INDEX and WORK_LOG after price-history (D6); track TD-035"
```

---

## Self-Review Checklist
- [ ] Endpoint returns ascending points, empty-200 for no data, respects `limit` (Task 2).
- [ ] Every mechanism's snapshot normalizes correctly; unresolvable points skipped (Task 1).
- [ ] Snapshot recording is wired and enqueues after commit only on success (Task 3) — does not roll back trades.
- [ ] Chart renders for ≥2 points, empty state otherwise (Task 4).
- [ ] Retention explicitly deferred to TD-035 (Task 5).
- [ ] Full suite passes: `bin/rails test`; RuboCop clean.
- [ ] No placeholder steps remain.
