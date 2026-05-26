# Binary Line Invariants Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-26-binary-line-invariants.md -->
<!-- Written AFTER the spec is approved. Describes HOW. -->

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use `- [ ]` for tracking.

**Goal:** Enforce at model and DB level that each market has at most 2 legs and cannot open with fewer than 2 legs.

**Architecture:** Two model validations (MarketLeg count guard, Market open-transition guard), a PostgreSQL trigger migration for DB-level enforcement, and an API-level early return in `Admin::MarketLegsController`. Note: label uniqueness per market is already enforced at both the model (`validates :label, uniqueness: { scope: :market_id }`) and DB (`UNIQUE INDEX on (market_id, label)`) levels — those require no changes.

**Tech Stack:** Rails 8, Minitest, PostgreSQL 16 (trigger via `execute`)

**Spec:** [docs/specs/2026-05-26-binary-line-invariants.md](../../specs/2026-05-26-binary-line-invariants.md)

---

## File Map

**Modify:**
- `app/models/market_leg.rb` — add count guard validation
- `app/models/market.rb` — add open-transition validation
- `app/controllers/admin/market_legs_controller.rb` — add early 422 for leg count
- `config/routes.rb` — no changes needed
- `test/models/market_leg_test.rb` — add count tests
- `test/models/market_test.rb` — add open-transition tests
- `test/integration/admin_market_legs_test.rb` — add 422 test

**Create:**
- `db/migrate/<timestamp>_add_leg_count_trigger_to_markets.rb`

---

## Task 1: MarketLeg count guard validation

**Files:**
- Modify: `app/models/market_leg.rb`
- Modify: `test/models/market_leg_test.rb`

- [ ] **Step 1.1: Write the failing tests**

```ruby
# test/models/market_leg_test.rb
require "test_helper"

class MarketLegTest < ActiveSupport::TestCase
  setup do
    @market = markets(:open_market)
  end

  test "cannot add a 3rd leg to a market that already has 2" do
    assert_equal 2, @market.market_legs.count

    third_leg = MarketLeg.new(market: @market, label: "MAYBE", odds_minor: 5000)
    assert_not third_leg.valid?
    assert_includes third_leg.errors[:base], "Market already has the maximum of 2 legs"
  end

  test "duplicate label in the same market is invalid" do
    dup = MarketLeg.new(market: @market, label: @market.market_legs.first.label, odds_minor: 5000)
    assert_not dup.valid?
  end

  test "can create a leg on a draft market with 0 legs" do
    draft = markets(:draft_market)
    leg = MarketLeg.new(market: draft, label: "YES", odds_minor: 5000)
    assert leg.valid?
  end
end
```

- [ ] **Step 1.2: Run tests to verify they fail**

```bash
bin/rails test test/models/market_leg_test.rb -v
```
Expected: FAIL — "Market already has the maximum of 2 legs" error not present.

- [ ] **Step 1.3: Add count guard to MarketLeg**

```ruby
# app/models/market_leg.rb
class MarketLeg < ApplicationRecord
  belongs_to :market
  has_many :bets, dependent: :restrict_with_exception

  validates :label, presence: true, uniqueness: { scope: :market_id }
  validates :odds_minor, numericality: { greater_than: 0, less_than_or_equal_to: 10_000 }

  validate :market_leg_count_within_limit, on: :create

  private

  def market_leg_count_within_limit
    return unless market
    if market.market_legs.count >= 2
      errors.add(:base, "Market already has the maximum of 2 legs")
    end
  end
end
```

- [ ] **Step 1.4: Run tests to verify they pass**

```bash
bin/rails test test/models/market_leg_test.rb -v
```
Expected: 3 tests, 0 failures.

- [ ] **Step 1.5: Commit**

```bash
git add app/models/market_leg.rb test/models/market_leg_test.rb
git commit -m "$(cat <<'EOF'
feat(binary-invariant): add MarketLeg count guard (max 2 legs per market)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Market open-transition guard

**Files:**
- Modify: `app/models/market.rb`
- Modify/Create: `test/models/market_test.rb`

- [ ] **Step 2.1: Write the failing tests**

```ruby
# test/models/market_test.rb
require "test_helper"

class MarketTest < ActiveSupport::TestCase
  def build_draft
    Market.new(
      question: "Q?",
      description: "D",
      mechanism_type: "binary",
      fee_bps: 0,
      liability_cap_minor: 100_000,
      created_by: users(:admin)
    )
  end

  test "draft market with 0 legs is valid" do
    market = build_draft
    assert market.valid?
  end

  test "cannot transition to open with 0 legs" do
    market = build_draft
    market.save!
    market.status = :open
    assert_not market.valid?
    assert_includes market.errors[:base], "Market must have exactly 2 legs to open"
  end

  test "cannot transition to open with 1 leg" do
    market = build_draft
    market.save!
    market.market_legs.create!(label: "YES", odds_minor: 5000)
    market.status = :open
    assert_not market.valid?
    assert_includes market.errors[:base], "Market must have exactly 2 legs to open"
  end

  test "can transition to open with exactly 2 legs" do
    market = build_draft
    market.save!
    market.market_legs.create!(label: "YES", odds_minor: 5000)
    market.market_legs.create!(label: "NO", odds_minor: 5000)
    market.status = :open
    assert market.valid?
  end
end
```

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
bin/rails test test/models/market_test.rb -v
```
Expected: FAIL — the open-with-0-legs and open-with-1-leg tests don't produce the expected error.

- [ ] **Step 2.3: Add open-transition guard to Market**

```ruby
# app/models/market.rb
class Market < ApplicationRecord
  enum :status, { draft: 0, open: 1, settled: 2, cancelled: 3 }, default: :draft

  belongs_to :created_by, class_name: "User", inverse_of: :created_markets
  belongs_to :settled_by, class_name: "User", optional: true, inverse_of: :settled_markets
  has_many :market_legs, dependent: :destroy
  has_many :bets, dependent: :destroy

  validates :question, presence: true
  validates :description, presence: true
  validates :mechanism_type, presence: true
  validates :fee_bps, numericality: { greater_than_or_equal_to: 0 }
  validates :liability_cap_minor, numericality: { greater_than: 0 }

  validate :requires_two_legs_to_open, if: -> { will_save_change_to_status? && open? }

  private

  def requires_two_legs_to_open
    unless market_legs.size == 2
      errors.add(:base, "Market must have exactly 2 legs to open")
    end
  end
end
```

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
bin/rails test test/models/market_test.rb -v
```
Expected: 4 tests, 0 failures.

- [ ] **Step 2.5: Commit**

```bash
git add app/models/market.rb test/models/market_test.rb
git commit -m "$(cat <<'EOF'
feat(binary-invariant): prevent market opening with != 2 legs

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: DB-level trigger migration

**Files:**
- Create: `db/migrate/<timestamp>_add_leg_count_trigger_to_markets.rb`

- [ ] **Step 3.1: Generate migration**

```bash
bin/rails generate migration AddLegCountTriggerToMarkets
```

Replace generated content with:

```ruby
class AddLegCountTriggerToMarkets < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION check_market_leg_count()
      RETURNS TRIGGER AS $$
      BEGIN
        IF (SELECT COUNT(*) FROM market_legs WHERE market_id = NEW.market_id) > 2 THEN
          RAISE EXCEPTION 'Market % already has 2 legs', NEW.market_id;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER enforce_max_two_market_legs
      BEFORE INSERT ON market_legs
      FOR EACH ROW EXECUTE FUNCTION check_market_leg_count();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS enforce_max_two_market_legs ON market_legs;
      DROP FUNCTION IF EXISTS check_market_leg_count();
    SQL
  end
end
```

- [ ] **Step 3.2: Run migration**

```bash
bin/rails db:migrate
```
Expected: migration runs, trigger created.

- [ ] **Step 3.3: Write a test that bypasses ActiveRecord to verify the trigger**

Add to `test/models/market_leg_test.rb`:

```ruby
test "DB trigger prevents 3rd leg even when bypassing ActiveRecord validations" do
  market = markets(:open_market)
  assert_equal 2, market.market_legs.count

  assert_raises ActiveRecord::StatementInvalid do
    ActiveRecord::Base.connection.execute(
      "INSERT INTO market_legs (market_id, label, odds_minor, active, created_at, updated_at) " \
      "VALUES (#{market.id}, 'BYPASS', 5000, true, NOW(), NOW())"
    )
  end
end
```

- [ ] **Step 3.4: Run tests**

```bash
bin/rails test test/models/market_leg_test.rb -v
```
Expected: 4 tests, 0 failures.

- [ ] **Step 3.5: Commit**

```bash
git add db/migrate/*_add_leg_count_trigger_to_markets.rb db/schema.rb \
        test/models/market_leg_test.rb
git commit -m "$(cat <<'EOF'
feat(binary-invariant): add DB trigger to enforce max 2 legs per market

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: API enforcement in Admin::MarketLegsController

**Files:**
- Modify: `app/controllers/admin/market_legs_controller.rb`
- Modify/Create: `test/integration/admin_market_legs_test.rb`

- [ ] **Step 4.1: Write the failing test**

```ruby
# test/integration/admin_market_legs_test.rb
require "test_helper"

class AdminMarketLegsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @market = markets(:open_market)
  end

  test "returns 422 when market already has 2 legs" do
    assert_equal 2, @market.market_legs.count

    post "/admin/markets/#{@market.id}/legs",
      params: { label: "THIRD", odds_minor: 5000 },
      headers: auth_headers_for(@admin),
      as: :json

    assert_response :unprocessable_entity
    assert_equal "Market already has 2 legs", response.parsed_body["error"]
  end
end
```

- [ ] **Step 4.2: Run test to verify it fails**

```bash
bin/rails test test/integration/admin_market_legs_test.rb -v
```
Expected: FAIL — returns 201 or some other status instead of 422.

- [ ] **Step 4.3: Add early guard to the controller**

Read `app/controllers/admin/market_legs_controller.rb` first. Add before the create action:

```ruby
def create
  market = Market.find(params[:market_id])

  if market.market_legs.count >= 2
    return render json: { error: "Market already has 2 legs" }, status: :unprocessable_entity
  end

  leg = market.market_legs.create!(leg_params)
  render json: serialize_leg(leg), status: :created
end
```

- [ ] **Step 4.4: Run test to verify it passes**

```bash
bin/rails test test/integration/admin_market_legs_test.rb -v
```
Expected: 1 test, 0 failures.

- [ ] **Step 4.5: Run full suite**

```bash
bin/rails test
```
Expected: all tests pass, SimpleCov ≥ 90%.

- [ ] **Step 4.6: Commit**

```bash
git add app/controllers/admin/market_legs_controller.rb \
        test/integration/admin_market_legs_test.rb
git commit -m "$(cat <<'EOF'
feat(binary-invariant): enforce 2-leg limit in Admin::MarketLegsController

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update docs

- [ ] Append entry to `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` — move binary line invariants from ⏳ Next to ✅ Done
- [ ] Commit: `docs: update INDEX and WORK_LOG after binary-line-invariants`

---

## Self-Review Checklist
- [ ] Every spec invariant has a test (3rd leg via AR, 3rd leg via raw SQL, open with 0/1/2 legs, API 422)
- [ ] No write actions introduced — no AuditEvent or LedgerEntry needed
- [ ] Full test suite passes: `bin/rails test`
- [ ] No placeholder steps remain
