# F-009: Automated Market Close Enforcement — Implementation Plan

**Goal:** Make the existing `close_at` timestamp field behaviorally enforceable: `BetPlacementService` rejects bets on markets past their close date, a `closed` status halts trading automatically, and a background job (`CloseExpiredMarketsJob`) transitions open markets every 5 minutes.

**Architecture:** Three coordinated changes. (1) A migration adds `closed: 4` to the `markets.status` integer enum with a DB check-constraint ensuring `closed` markets have a non-null `close_at`. (2) `BetPlacementService` gains a guard that raises `InvalidBet` when `market.close_at` is set and in the past (fires even before the job runs). (3) `CloseExpiredMarketsJob` queries `Market.open.where("close_at <= ?", Time.current)` and transitions each to `closed` with an `AuditEvent`. Scheduled every 5 minutes via `config/recurring.yml` (Rails 8 solid-queue built-in scheduler). Backoffice and customer views add appropriate banners.

---

## File Map

**Create:**
- `app/jobs/close_expired_markets_job.rb`
- `test/jobs/close_expired_markets_job_test.rb`
- `db/migrate/YYYYMMDDHHMMSS_add_closed_status_to_markets.rb` (timestamp from generator)

**Modify:**
- `app/models/market.rb` — add `closed: 4` to enum
- `app/services/bet_placement_service.rb` — add `close_at` guard
- `app/services/settlement_service.rb` — accept `open || closed`
- `app/controllers/backoffice/markets_controller.rb` — settle guard accepts `closed`
- `app/views/backoffice/markets/show.html.erb` — "Closed" banner + settle form for closed state
- `app/views/web/markets/show.html.erb` — "Closed for new bets" notice
- `config/recurring.yml` — schedule job every 5 minutes
- `test/services/bet_placement_service_test.rb` — close_at guard tests
- `test/integration/admin_market_settle_test.rb` — settling a closed market

---

## Task 1: Migration — add `closed` status

- [ ] **Step 1.1:** Generate migration:
  ```bash
  bin/rails generate migration AddClosedStatusToMarkets
  ```
  Note the timestamp in the generated filename (e.g. `20260528120000`).

- [ ] **Step 1.2:** Replace the generated migration body:
  ```ruby
  class AddClosedStatusToMarkets < ActiveRecord::Migration[8.1]
    def up
      # Rails integer enum: draft=0, open=1, settled=2, cancelled=3, closed=4
      # Integer column already accepts value 4 — no column type change needed.
      execute <<~SQL
        ALTER TABLE markets
          ADD CONSTRAINT markets_closed_requires_close_at
          CHECK (status != 4 OR close_at IS NOT NULL);
      SQL
    end

    def down
      execute <<~SQL
        ALTER TABLE markets
          DROP CONSTRAINT IF EXISTS markets_closed_requires_close_at;
      SQL
    end
  end
  ```

- [ ] **Step 1.3:** Run migration:
  ```bash
  bin/rails db:migrate
  ```
  Expected: `== AddClosedStatusToMarkets: migrated`

- [ ] **Step 1.4:** Commit:
  ```bash
  git add db/migrate db/schema.rb
  git commit -m "feat(f009): migration — add closed status check constraint to markets"
  ```

---

## Task 2: Market model — add `closed` to enum

**File:** `app/models/market.rb`

- [ ] **Step 2.1:** Find the enum declaration (currently `draft: 0, open: 1, settled: 2, cancelled: 3`). Change to:
  ```ruby
  enum :status, { draft: 0, open: 1, settled: 2, cancelled: 3, closed: 4 }, default: :draft
  ```

- [ ] **Step 2.2:** Run model tests to confirm no regression:
  ```bash
  bin/rails test test/models/market_test.rb -v
  ```
  Expected: all existing tests pass.

- [ ] **Step 2.3:** Commit:
  ```bash
  git add app/models/market.rb
  git commit -m "feat(f009): add closed:4 to Market status enum"
  ```

---

## Task 3: BetPlacementService — `close_at` guard (TDD)

**Files:** `app/services/bet_placement_service.rb`, `test/services/bet_placement_service_test.rb`

- [ ] **Step 3.1:** Add these 4 tests to `test/services/bet_placement_service_test.rb` (create file if absent):
  ```ruby
  require 'test_helper'

  class BetPlacementServiceTest < ActiveSupport::TestCase
    setup do
      @market  = markets(:open_market)
      @yes_leg = market_legs(:yes_leg)
      @player  = users(:player)
      @market.bets.delete_all
      @player.wallet.update!(available_minor: 50_000)
    end

    test 'raises InvalidBet when close_at is in the past' do
      @market.update_columns(close_at: 1.hour.ago)
      err = assert_raises(BetPlacementService::InvalidBet) do
        BetPlacementService.place!(user: @player, market: @market,
                                   market_leg: @yes_leg, stake_minor: 100)
      end
      assert_match 'closed for new bets', err.message
    end

    test 'allows placement when close_at is nil' do
      @market.update_columns(close_at: nil)
      assert_nothing_raised do
        BetPlacementService.place!(user: @player, market: @market,
                                   market_leg: @yes_leg, stake_minor: 100)
      end
    end

    test 'allows placement when close_at is in the future' do
      @market.update_columns(close_at: 1.hour.from_now)
      assert_nothing_raised do
        BetPlacementService.place!(user: @player, market: @market,
                                   market_leg: @yes_leg, stake_minor: 100)
      end
    end

    test 'raises InvalidBet when market status is closed' do
      @market.update_columns(status: Market.statuses[:closed], close_at: 1.hour.ago)
      err = assert_raises(BetPlacementService::InvalidBet) do
        BetPlacementService.place!(user: @player, market: @market,
                                   market_leg: @yes_leg, stake_minor: 100)
      end
      assert_match 'Market is not open', err.message
    end
  end
  ```

- [ ] **Step 3.2:** Confirm tests fail (expected):
  ```bash
  bin/rails test test/services/bet_placement_service_test.rb -v
  ```
  Expected: `test_raises_InvalidBet_when_close_at_is_in_the_past` FAILS.

- [ ] **Step 3.3:** In `app/services/bet_placement_service.rb`, after the `'Market is not open'` guard, insert exactly one line:
  ```ruby
  raise InvalidBet, 'Market is closed for new bets' if market.close_at.present? && market.close_at <= Time.current
  ```

- [ ] **Step 3.4:** Confirm all 4 tests pass:
  ```bash
  bin/rails test test/services/bet_placement_service_test.rb -v
  ```
  Expected: 4 tests, 0 failures.

- [ ] **Step 3.5:** Commit:
  ```bash
  git add app/services/bet_placement_service.rb test/services/bet_placement_service_test.rb
  git commit -m "feat(f009): BetPlacementService rejects bets when close_at is past"
  ```

---

## Task 4: CloseExpiredMarketsJob (TDD)

**Files:** `app/jobs/close_expired_markets_job.rb`, `test/jobs/close_expired_markets_job_test.rb`

- [ ] **Step 4.1:** Create test file:
  ```ruby
  # test/jobs/close_expired_markets_job_test.rb
  require 'test_helper'

  class CloseExpiredMarketsJobTest < ActiveJob::TestCase
    setup do
      @market = markets(:open_market)
      @market.bets.delete_all
    end

    test 'transitions open market with past close_at to closed' do
      @market.update_columns(close_at: 1.minute.ago, status: Market.statuses[:open])
      CloseExpiredMarketsJob.perform_now
      assert_predicate @market.reload, :closed?
    end

    test 'does not transition market whose close_at is in the future' do
      @market.update_columns(close_at: 1.hour.from_now, status: Market.statuses[:open])
      CloseExpiredMarketsJob.perform_now
      assert_predicate @market.reload, :open?
    end

    test 'does not transition market with nil close_at' do
      @market.update_columns(close_at: nil, status: Market.statuses[:open])
      CloseExpiredMarketsJob.perform_now
      assert_predicate @market.reload, :open?
    end

    test 'creates AuditEvent for each closed market' do
      @market.update_columns(close_at: 1.minute.ago, status: Market.statuses[:open])
      assert_difference('AuditEvent.count', 1) do
        CloseExpiredMarketsJob.perform_now
      end
      event = AuditEvent.last
      assert_equal 'market.close', event.action
      assert_equal @market.id, event.target_id
    end

    test 'does not close already-settled markets' do
      @market.update_columns(
        close_at: 1.minute.ago,
        status: Market.statuses[:settled],
        settled_outcome: 'YES',
        settled_by_id: users(:admin).id
      )
      CloseExpiredMarketsJob.perform_now
      assert_predicate @market.reload, :settled?
    end
  end
  ```

- [ ] **Step 4.2:** Confirm tests fail (`uninitialized constant CloseExpiredMarketsJob`):
  ```bash
  bin/rails test test/jobs/close_expired_markets_job_test.rb -v
  ```

- [ ] **Step 4.3:** Create the job:
  ```ruby
  # app/jobs/close_expired_markets_job.rb
  class CloseExpiredMarketsJob < ApplicationJob
    queue_as :default

    def perform
      expired = Market.open.where.not(close_at: nil).where('close_at <= ?', Time.current)

      expired.find_each do |market|
        market.update_columns(status: Market.statuses[:closed])
        AuditEvent.create!(
          action: 'market.close',
          actor: system_actor,
          target_type: 'Market',
          target_id: market.id,
          metadata: { close_at: market.close_at.iso8601, triggered_by: 'CloseExpiredMarketsJob' }
        )
      rescue StandardError => e
        Rails.logger.error("[CloseExpiredMarketsJob] Failed to close market #{market.id}: #{e.message}")
      end
    end

    private

    def system_actor
      @system_actor ||= User.where(role: User.roles[:admin]).first || User.first
    end
  end
  ```
  **Note:** `AuditEvent` requires a non-null `actor`. The `system_actor` fallback prevents the job from crashing if no admin exists — do not remove it.

- [ ] **Step 4.4:** Confirm 5 tests pass:
  ```bash
  bin/rails test test/jobs/close_expired_markets_job_test.rb -v
  ```
  Expected: 5 tests, 0 failures.

- [ ] **Step 4.5:** Commit:
  ```bash
  git add app/jobs/close_expired_markets_job.rb test/jobs/close_expired_markets_job_test.rb
  git commit -m "feat(f009): CloseExpiredMarketsJob closes markets whose close_at has passed"
  ```

---

## Task 5: Schedule via solid-queue recurring

**File:** `config/recurring.yml` (create if absent)

- [ ] **Step 5.1:** Check if file exists:
  ```bash
  ls config/recurring.yml 2>/dev/null || echo NOT_FOUND
  ```

- [ ] **Step 5.2:** If NOT_FOUND, create:
  ```yaml
  # config/recurring.yml
  close_expired_markets:
    class: CloseExpiredMarketsJob
    schedule: every 5 minutes
    queue: default
  ```
  If the file exists, append the `close_expired_markets` block, preserving existing entries.

- [ ] **Step 5.3:** Validate YAML:
  ```bash
  ruby -ryaml -e "YAML.load_file('config/recurring.yml'); puts 'OK'"
  ```
  Expected: `OK`

- [ ] **Step 5.4:** Commit:
  ```bash
  git add config/recurring.yml
  git commit -m "feat(f009): schedule CloseExpiredMarketsJob every 5 minutes via solid-queue"
  ```

---

## Task 6: SettlementService + backoffice — accept `closed` markets

**Files:** `app/services/settlement_service.rb`, `app/controllers/backoffice/markets_controller.rb`, `test/integration/admin_market_settle_test.rb`

- [ ] **Step 6.1:** In `app/services/settlement_service.rb`, find:
  ```ruby
  raise InvalidSettlement, 'Market must be open to settle' unless market.open?
  ```
  Change to:
  ```ruby
  raise InvalidSettlement, 'Market must be open or closed to settle' unless market.open? || market.closed?
  ```

- [ ] **Step 6.2:** In `app/controllers/backoffice/markets_controller.rb`, find the settle action guard (look for `'Market must be open to settle'` or `unless @market.open?` near the settle action). Change the guard condition from `@market.open?` to `@market.open? || @market.closed?` and update any associated flash message.

- [ ] **Step 6.3:** Add integration test — in `test/integration/admin_market_settle_test.rb`, append:
  ```ruby
  test 'admin can settle a closed market via API' do
    @market.update_columns(status: Market.statuses[:closed], close_at: 1.hour.ago)

    post "/admin/markets/#{@market.id}/settle",
         params: { outcome: 'YES' },
         headers: auth_headers_for(users(:admin)), as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal 'settled', body['status']
    assert_equal 'YES', body['settled_outcome']
  end
  ```

- [ ] **Step 6.4:** Run settlement tests:
  ```bash
  bin/rails test test/integration/admin_market_settle_test.rb -v
  ```
  Expected: all tests pass (including the new one).

- [ ] **Step 6.5:** Commit:
  ```bash
  git add app/services/settlement_service.rb \
          app/controllers/backoffice/markets_controller.rb \
          test/integration/admin_market_settle_test.rb
  git commit -m "feat(f009): allow settling closed markets in SettlementService and backoffice"
  ```

---

## Task 7: Backoffice view — "Closed" banner + settle form

**File:** `app/views/backoffice/markets/show.html.erb`

- [ ] **Step 7.1:** After the closing `<% end %>` of the existing `<% if @market.open? %>` settle form block, insert:
  ```erb
  <% if @market.closed? %>
    <div style="margin-top:16px;padding:14px;background:#2a1f0a;border:1px solid #f0bc5c;border-radius:8px;" data-testid="market-closed-banner">
      <strong style="color:#f0bc5c;">Closed — awaiting settlement</strong>
      <span style="color:#9fb2b8;font-size:0.88em;margin-left:8px;">
        Market closed for new bets on <%= @market.close_at.strftime('%b %d, %Y at %H:%M UTC') %>
      </span>
    </div>
    <div style="margin-top:16px;border-top:1px solid #33434c;padding-top:14px;">
      <h4>Settle market</h4>
      <%= form_with url: settle_backoffice_market_path(@market), method: :post,
            html: { data: { testid: "settle-market-form" } } do |f| %>
        <p>
          <label>Winning outcome</label>
          <select name="outcome" data-testid="settle-outcome" style="margin-left:8px;">
            <% @market.market_legs.each do |leg| %>
              <option value="<%= leg.label %>"><%= leg.label %></option>
            <% end %>
          </select>
        </p>
        <p><label>Reason</label><br><%= text_field_tag :reason, nil, data: { testid: "settle-reason" } %></p>
        <%= f.submit "Settle market", style: "background:#4a2222;",
              data: { testid: "settle-market-submit",
                      confirm: "This will settle all bets. Proceed?" } %>
      <% end %>
    </div>
  <% end %>
  ```

- [ ] **Step 7.2:** Commit:
  ```bash
  git add app/views/backoffice/markets/show.html.erb
  git commit -m "feat(f009): backoffice market show — closed banner and settle form"
  ```

---

## Task 8: Customer view — "Closed for new bets" notice

**File:** `app/views/web/markets/show.html.erb`

- [ ] **Step 8.1:** Locate the section that shows the quick-bet panel (look for `<% if @market.open? %>`). Immediately before that block (or after the closing price panel `</section>`), insert:
  ```erb
  <% if @market.closed? %>
    <div style="background:#2a1f0a;border:1px solid #f0bc5c;border-radius:8px;padding:12px 16px;margin-bottom:16px;"
         data-testid="market-closed-notice">
      <strong style="color:#f0bc5c;">This market is closed for new bets.</strong>
      <span style="color:#9fb2b8;font-size:0.88em;margin-left:6px;">Awaiting settlement by a moderator.</span>
    </div>
  <% end %>
  ```

- [ ] **Step 8.2:** Confirm the existing `<% if @market.open? %>` guard already hides the bet form for `closed` markets — no change needed there.

- [ ] **Step 8.3:** Commit:
  ```bash
  git add app/views/web/markets/show.html.erb
  git commit -m "feat(f009): customer market show — closed-for-new-bets notice"
  ```

---

## Task 9: Full suite verification

- [ ] **Step 9.1:** Run full test suite:
  ```bash
  bin/rails test
  ```
  Expected final lines:
  ```
  ... tests, 0 failures, 0 errors, 0 skips
  Coverage report generated ... (XX.XX% covered)
  ```
  Coverage **must be ≥ 90.00%**. If it drops below 90%, add tests for uncovered branches in `CloseExpiredMarketsJob` or `BetPlacementService` until coverage recovers.

- [ ] **Step 9.2:** If any previously-passing test now fails, diagnose:
  ```bash
  bin/rails test path/to/failing_test.rb -v
  ```
  Most likely regression: `BetPlacementService` tests that use fixtures with `close_at` set to a past date. Fix by adding `@market.update_columns(close_at: nil)` to those tests' `setup` blocks.

---

## Task 10: Update docs

- [ ] Prepend to `docs/WORK_LOG.md`:
  ```
  ## 2026-05-28 — F-009: Automated Market Close Enforcement

  - Migration: DB check constraint `markets_closed_requires_close_at`
  - Market enum: `closed: 4` added
  - `BetPlacementService`: rejects bets when `close_at <= Time.current`
  - `CloseExpiredMarketsJob`: transitions expired open markets → closed, writes AuditEvent per market
  - `config/recurring.yml`: job scheduled every 5 minutes via solid-queue
  - `SettlementService` + backoffice controller: accept `open || closed` for settlement
  - Backoffice + customer views: "Closed" banners
  - Key files: app/jobs/close_expired_markets_job.rb, app/services/bet_placement_service.rb,
    app/services/settlement_service.rb, config/recurring.yml
  ```

- [ ] Update `docs/INDEX.md`: move F-009 from ⏳ Next to ✅ Done; add row to Plans + Reviews table.

- [ ] Commit:
  ```bash
  git add docs/WORK_LOG.md docs/INDEX.md
  git commit -m "docs: update INDEX and WORK_LOG after F-009 automated market close"
  ```

---

## Self-Review Checklist
- [ ] `BetPlacementService` raises `InvalidBet` for both past `close_at` AND `closed` status
- [ ] `CloseExpiredMarketsJob` writes one `AuditEvent` per closed market with `action: 'market.close'`
- [ ] `SettlementService` accepts `closed` markets (`open? || closed?`)
- [ ] Full test suite passes: `bin/rails test`
- [ ] Coverage ≥ 90%
- [ ] No placeholder steps remain (no TODO comments in committed code)

---

## Guardrails

1. **DO NOT** change the `close_at` column type or name — it already exists as a datetime on `markets`.
2. **DO NOT** auto-settle markets in the job — `CloseExpiredMarketsJob` only transitions to `closed`; settlement always requires a human moderator decision.
3. **DO NOT** change the `open?` guard in `BetPlacementService` to accept `closed` — a `closed` market must fail the `'Market is not open'` guard; the `close_at` guard is an *additional* check that fires while the market is still `open` but past its close time (i.e. between `close_at` and when the job next runs).
4. **DO NOT** add `closed` as a valid settled outcome — `closed` is a pre-settlement state; valid outcomes remain the market leg labels (YES/NO).
5. **DO NOT** modify `db/schema.rb` directly — it is auto-generated by `bin/rails db:migrate`.
6. **DO NOT** remove the `system_actor` fallback in `CloseExpiredMarketsJob` — `AuditEvent` requires a non-null `actor_id`; if no admin exists the job crashes without the fallback.
7. **DO NOT** change the `profiles` or `queue_as` for the job without verifying solid-queue is configured to process the `:default` queue in `config/queue.yml`.
8. **DO NOT** add `close_at` past-date validation to the create/update forms — the DB allows it and enforcement is out of scope for this feature.
