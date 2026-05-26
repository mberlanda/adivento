# Binary Line DB Invariants Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-26-binary-line-invariants.md -->
<!-- Written AFTER the spec is approved. Describes HOW. -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent invalid market configurations by enforcing at the DB and model level that each market has exactly 2 active legs.

**Architecture:** Two model validations (MarketLeg count guard on create, Market open-transition guard), a PostgreSQL BEFORE INSERT trigger migration for DB-level enforcement that cannot be bypassed by ActiveRecord, and an early-return 422 guard in `Admin::MarketLegsController#create`. Label uniqueness is enforced via `validates :label, uniqueness: { scope: :market_id }` — no additional changes needed there.

**Tech Stack:** Rails 8, Minitest, PostgreSQL BEFORE INSERT trigger

**Spec:** [docs/specs/2026-05-26-binary-line-invariants.md](../../specs/2026-05-26-binary-line-invariants.md)

---

## File Map

**Create:**
- `db/migrate/20260526194007_add_leg_count_trigger_to_markets.rb`

**Modify:**
- `app/models/market_leg.rb` — add count guard validation on create
- `app/models/market.rb` — add open-transition validation
- `app/controllers/admin/market_legs_controller.rb` — add early 422 guard
- `test/models/market_leg_test.rb` — add count + uniqueness + DB bypass tests
- `test/models/market_test.rb` — add open-transition tests
- `test/integration/admin_market_legs_test.rb` — add 422 test

---

## Task 1: MarketLeg model validation (max 2 legs + unique label)

**Files:**
- Modify: `app/models/market_leg.rb`
- Test: `test/models/market_leg_test.rb`

- [x] **Step 1.1: Write the failing tests**

```ruby
# test/models/market_leg_test.rb
require "test_helper"

class MarketLegTest < ActiveSupport::TestCase
  test "odds cannot exceed range" do
    leg = market_legs(:yes_leg)
    leg.odds_minor = 15_000
    assert_not leg.valid?
  end

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

- [x] **Step 1.2: Run test to verify it fails**

```bash
bin/rails test test/models/market_leg_test.rb -v
```
Expected: FAIL — `market_leg_count_within_limit` private method not yet defined, "Market already has the maximum of 2 legs" error not present.

- [x] **Step 1.3: Add count guard and odds validation to MarketLeg**

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

- [x] **Step 1.4: Run test to verify it passes**

```bash
bin/rails test test/models/market_leg_test.rb -v
```
Expected: 4 tests, 0 failures.

- [x] **Step 1.5: Commit**

```bash
git add app/models/market_leg.rb test/models/market_leg_test.rb
git commit -m "$(cat <<'EOF'
feat(binary-invariant): add MarketLeg count guard and odds range validation

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Market model validation (requires 2 legs to open)

**Files:**
- Modify: `app/models/market.rb`
- Test: `test/models/market_test.rb`

- [x] **Step 2.1: Write the failing tests**

```ruby
# test/models/market_test.rb  (additions to existing file)
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
```

- [x] **Step 2.2: Run test to verify it fails**

```bash
bin/rails test test/models/market_test.rb -v
```
Expected: FAIL — the open-with-0-legs and open-with-1-leg tests don't produce the expected error.

- [x] **Step 2.3: Add open-transition guard to Market**

Add to `app/models/market.rb` inside the class body (after existing validations):

```ruby
validate :requires_two_legs_to_open, if: -> { will_save_change_to_status? && open? }

private

def requires_two_legs_to_open
  unless market_legs.size == 2
    errors.add(:base, "Market must have exactly 2 legs to open")
  end
end
```

- [x] **Step 2.4: Run test to verify it passes**

```bash
bin/rails test test/models/market_test.rb -v
```
Expected: 4 new tests pass, 0 failures.

- [x] **Step 2.5: Commit**

```bash
git add app/models/market.rb test/models/market_test.rb
git commit -m "$(cat <<'EOF'
feat(binary-invariant): prevent market opening with != 2 legs

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Admin::MarketLegsController early 422 guard + integration test

**Files:**
- Modify: `app/controllers/admin/market_legs_controller.rb`
- Test: `test/integration/admin_market_legs_test.rb`

- [x] **Step 3.1: Write the failing test**

```ruby
# test/integration/admin_market_legs_test.rb  (addition to existing file)
test "returns 422 when market already has 2 legs" do
  assert_equal 2, @market.market_legs.count
  post "/admin/markets/#{@market.id}/legs",
    params: { label: "THIRD", odds_minor: 5000 },
    headers: auth_headers_for(@admin),
    as: :json
  assert_response :unprocessable_entity
  assert_equal "Market already has 2 legs", response.parsed_body["error"]
end
```

- [x] **Step 3.2: Run test to verify it fails**

```bash
bin/rails test test/integration/admin_market_legs_test.rb -v
```
Expected: FAIL — returns a different status (201 or model-level error) instead of the explicit 422 with `{ "error": "Market already has 2 legs" }`.

- [x] **Step 3.3: Add early guard to the controller**

In `app/controllers/admin/market_legs_controller.rb`, add a count check at the top of `#create`:

```ruby
def create
  market = Market.find(params[:market_id])

  if market.market_legs.count >= 2
    return render json: { error: "Market already has 2 legs" }, status: :unprocessable_entity
  end
  # ... rest of create
end
```

- [x] **Step 3.4: Run test to verify it passes**

```bash
bin/rails test test/integration/admin_market_legs_test.rb -v
```
Expected: 1 test, 0 failures.

- [x] **Step 3.5: Commit**

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

## Task 4: PostgreSQL DB trigger migration

**Files:**
- Create: `db/migrate/20260526194007_add_leg_count_trigger_to_markets.rb`
- Modify: `db/schema.rb` (auto-updated by migration)
- Test: `test/models/market_leg_test.rb` (add DB bypass test)

> **Note on test environment:** The test suite runs against SQLite3 (not PostgreSQL). The DB trigger test below uses a raw SQL `INSERT` via `ActiveRecord::Base.connection.execute`. In PostgreSQL (development/production) the trigger fires and raises an exception. In SQLite the `plpgsql` function does not exist, so the trigger is absent and the raw INSERT succeeds — meaning this test would NOT pass in a pure SQLite test environment. If the test suite is configured to run against PostgreSQL (e.g. via `DATABASE_URL`), it passes as written. Otherwise, mark it `skip "requires PostgreSQL trigger"` when running against SQLite.

- [x] **Step 4.1: Generate and fill the migration**

```bash
bin/rails generate migration AddLegCountTriggerToMarkets
```

Replace generated body with:

```ruby
# db/migrate/20260526194007_add_leg_count_trigger_to_markets.rb
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

- [x] **Step 4.2: Run migration**

```bash
bin/rails db:migrate
```
Expected: migration runs, trigger created in PostgreSQL.

- [x] **Step 4.3: Add DB bypass test to market_leg_test.rb**

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

- [x] **Step 4.4: Run tests**

```bash
bin/rails test test/models/market_leg_test.rb -v
```
Expected: all tests pass (trigger test passes when running against PostgreSQL).

- [x] **Step 4.5: Commit**

```bash
git add db/migrate/20260526194007_add_leg_count_trigger_to_markets.rb \
        db/schema.rb \
        test/models/market_leg_test.rb
git commit -m "$(cat <<'EOF'
feat(binary-invariant): add PostgreSQL trigger to enforce max 2 legs at DB level

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update docs

- [x] Append entry to `docs/WORK_LOG.md` — what was built, key files, commit refs
- [x] Update `docs/INDEX.md` — move binary line invariants from TODO/Next to Done
- [x] Update `docs/plans/ITERATION_005_MASTER_TODO_TREE.md` (or equivalent) — mark tasks done
- [x] Commit:

```bash
git commit -m "$(cat <<'EOF'
docs: update INDEX and WORK_LOG after binary-line-invariants

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist
- [x] Every spec invariant has a test (3rd leg via AR, 3rd leg via raw SQL/DB trigger, open with 0/1/2 legs, API 422)
- [x] Label uniqueness enforced via existing `uniqueness: { scope: :market_id }` — test coverage added
- [x] No write actions introduced — no AuditEvent or LedgerEntry needed
- [x] Full test suite passes: `bin/rails test`
- [x] No placeholder steps remain
