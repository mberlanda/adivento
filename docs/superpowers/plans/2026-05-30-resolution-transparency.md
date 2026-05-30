# Resolution Transparency Implementation Plan (D7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require a mandatory resolution note and record a settlement timestamp at the single `SettlementService.settle!` entry point, thread it through the backoffice and admin settle actions, and display it to players on the market page.

**Architecture:** Add `resolution_note` (text) and `settled_at` (datetime) columns to `markets`. Enforce the note centrally in `SettlementService.settle!` (the only application-level settlement entry point) inside its existing transaction, set `settled_at`, and add a final canonical `market.settle` audit row carrying the full resolution metadata. Controllers pass the note through; customer and backoffice views render it. Existing CLOB/LMSR handler tests may still exercise handler internals directly, but application code and integration tests should settle through `SettlementService` so the note requirement cannot be bypassed.

**Tech Stack:** Rails 8, PostgreSQL, Minitest, existing patterns (see docs/INDEX.md).

**Spec:** `docs/specs/2026-05-30-resolution-transparency.md`

---

## File Map

**Create:**
- `db/migrate/<ts>_add_resolution_note_and_settled_at_to_markets.rb`
- `test/integration/resolution_transparency_test.rb`

**Modify:**
- `app/services/settlement_service.rb` — require/validate note, persist note + settled_at, audit metadata
- `app/services/settlement/clob_settlement_handler.rb`, `.../lmsr_settlement_handler.rb` — no production logic change if `SettlementService` writes the canonical final `market.settle` audit row; update direct handler tests to cover handler mechanics only and add service-level tests proving no application settlement path bypasses `SettlementService`
- `app/controllers/backoffice/markets_controller.rb#settle` — pass `resolution_note`
- `app/controllers/admin/markets_controller.rb#settle` — require `resolution_note`, return it
- `app/views/backoffice/markets/show.html.erb` — make the reason field `resolution_note` + required
- `app/views/web/markets/show.html.erb` — render note + settled_at in the resolution panel
- `test/services/settlement_service_test.rb` — update existing calls to pass a note
- `docs/wiki/tech-debt-backlog.md` — note F-010 closed by D7; SEC-003 remains the workflow follow-up

---

## Task 1: Migration — `resolution_note` + `settled_at`

**Files:**
- Create: `db/migrate/<ts>_add_resolution_note_and_settled_at_to_markets.rb`

- [ ] **Step 1.1: Generate the migration**

```bash
bin/rails g migration add_resolution_note_and_settled_at_to_markets resolution_note:text settled_at:datetime
```

- [ ] **Step 1.2: Confirm the migration body**

```ruby
class AddResolutionNoteAndSettledAtToMarkets < ActiveRecord::Migration[8.1]
  def change
    add_column :markets, :resolution_note, :text
    add_column :markets, :settled_at, :datetime
  end
end
```

- [ ] **Step 1.3: Migrate dev + regenerate structure.sql; prepare test DB**

```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:prepare
```
Expected: `db/structure.sql` now contains `resolution_note text` and `settled_at timestamp` on `markets`.

- [ ] **Step 1.4: Commit**

```bash
git add db/migrate db/structure.sql
git commit -m "feat(settlement): add resolution_note and settled_at to markets (D7)"
```

---

## Task 2: Enforce + persist the note in `SettlementService.settle!`

**Files:**
- Modify: `app/services/settlement_service.rb`
- Test: `test/services/settlement_service_test.rb`

- [ ] **Step 2.1: Write the failing tests**

```ruby
# add to test/services/settlement_service_test.rb
test 'raises when resolution_note is blank' do
  assert_raises(SettlementService::InvalidSettlement) do
    SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor, resolution_note: '   ')
  end
  assert_not @market.reload.settled?
end

test 'raises when resolution_note is shorter than 20 chars' do
  assert_raises(SettlementService::InvalidSettlement) do
    SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor, resolution_note: 'too short for note')
  end
end

test 'persists resolution_note and settled_at on settlement' do
  freeze_time do
    SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor, resolution_note: 'Official source confirmed YES outcome.')
    @market.reload
    assert_equal 'Official source confirmed YES outcome.', @market.resolution_note
    assert_equal Time.current.to_i, @market.settled_at.to_i
  end
end

test 'market.settle audit event includes the resolution note' do
  SettlementService.settle!(market: @market, outcome: 'YES', actor: @actor, resolution_note: 'Resolved per official results.')
  ev = AuditEvent.where(action: 'market.settle', target_type: 'Market', target_id: @market.id).last
  assert_equal 'Resolved per official results.', ev.metadata['resolution_note']
end

test 'persists resolution metadata for every mechanism through SettlementService' do
  {
    fixed_odds: markets(:open_market),
    clob: markets(:clob_market),
    lmsr: markets(:lmsr_market),
    parimutuel: markets(:parimutuel_market)
  }.each do |mechanism, market|
    note = "Official source confirmed #{mechanism} YES outcome."
    SettlementService.settle!(market: market, outcome: 'YES', actor: @actor, resolution_note: note)

    market.reload
    assert_equal note, market.resolution_note
    assert market.settled_at.present?
    ev = AuditEvent.where(action: 'market.settle', target_type: 'Market', target_id: market.id).last
    assert_equal note, ev.metadata['resolution_note']
    assert_equal market.mechanism_type, ev.metadata['mechanism']
  end
end
```

Also update the **existing** passing tests in this file to pass `resolution_note: 'Resolved per official results.'` to every `SettlementService.settle!` call (they currently call it with 3 kwargs and will now fail on the missing required kwarg).

- [ ] **Step 2.2: Run tests to verify the new ones fail**

```bash
bin/rails test test/services/settlement_service_test.rb -v
```
Expected: the four new tests FAIL (note not required/persisted yet).

- [ ] **Step 2.3: Implement in `SettlementService.settle!`**

Change the signature and add validation + persistence. The method already wraps dispatch in `ApplicationRecord.transaction`; set the note/timestamp on the market inside that transaction after the handler runs, and add the note to the final audit metadata for each branch.

```ruby
  def self.settle!(market:, outcome:, actor:, resolution_note:)
    raise InvalidSettlement, 'Market must be open or closed to settle' unless market.open? || market.closed?

    note = resolution_note.to_s.strip
    raise InvalidSettlement, 'Resolution note is required (min 20 characters)' if note.length < 20

    valid_labels = market.market_legs.pluck(:label)
    unless valid_labels.include?(outcome)
      raise InvalidSettlement, "Invalid outcome: #{outcome}. Valid: #{valid_labels.join(', ')}"
    end

    ApplicationRecord.transaction do
      case market.mechanism_type
      when 'clob'       then Settlement::ClobSettlementHandler.new(market, outcome, actor).call
      when 'lmsr'       then Settlement::LmsrSettlementHandler.new(market, outcome, actor).call
      when 'parimutuel'
        result = Parimutuel::ParimutuelSettlementService.call(market: market, winning_side: outcome, settled_by: actor)
        raise InvalidSettlement, result.errors.join(', ') unless result.success?

        market.update_columns(settled_outcome: outcome)
        # (existing parimutuel audit + hot-storage calls stay)
      else
        settle_fixed_odds!(market: market, outcome: outcome, actor: actor)
      end

      # Parimutuel settled the row in its own inner transaction; reload before update!
      # so we don't write over fresher state.
      market.reload if market.parimutuel?

      # Centralized note + timestamp, then a canonical `market.settle` audit event that
      # carries the FULL resolution metadata (spec invariant 4). Using action
      # `market.settle` (not a separate action) keeps the stated audit contract true:
      # the last `market.settle` event for the market contains the note.
      market.update!(resolution_note: note, settled_at: Time.current)
      AuditEvent.create!(
        actor: actor, action: 'market.settle',
        target_type: 'Market', target_id: market.id,
        reason: note,
        metadata: {
          outcome: outcome, mechanism: market.mechanism_type,
          resolution_note: note, resolution_source: market.resolution_source,
          settled_at: market.settled_at
        }
      )
    end

    market.reload
  end
```

> The per-mechanism handlers also emit their own `market.settle` audit event; this adds
> a final canonical `market.settle` row carrying the full resolution metadata, so a test
> querying the **last** `market.settle` event finds the note (invariant 4). This means the
> per-mechanism handler audit events are now *not* the last `market.settle` row — that is
> intentional. **Existing-test impact:** `test/services/settlement_service_test.rb:94-98`
> asserts `assert_difference('AuditEvent.count', 3)`; the extra canonical event makes it 4 —
> update that assertion (and any per-mechanism count assertions) as part of Step 2.1.

- [ ] **Step 2.4: Run the full settlement suite**

```bash
bin/rails test test/services/settlement_service_test.rb test/services/settlement test/services/parimutuel -v
```
Expected: PASS (new + updated tests green).

- [ ] **Step 2.5: Commit**

```bash
git add app/services/settlement_service.rb test/services/settlement_service_test.rb
git commit -m "feat(settlement): require resolution note, record settled_at + audit (D7)"
```

---

## Task 3: Thread the note through controllers

**Files:**
- Modify: `app/controllers/backoffice/markets_controller.rb`, `app/controllers/admin/markets_controller.rb`, `app/views/backoffice/markets/show.html.erb`
- Test: `test/integration/resolution_transparency_test.rb`

- [ ] **Step 3.1: Write the failing integration tests**

```ruby
# test/integration/resolution_transparency_test.rb
require 'test_helper'

class ResolutionTransparencyTest < ActionDispatch::IntegrationTest
  setup do
    @market = markets(:open_market)
    @admin = users(:admin)
    # Backoffice auth is a session cookie — sign in the way existing backoffice tests do
    # (no `sign_in_backoffice` helper exists).
    post '/signin', params: { email: @admin.email, password: 'password123' }
  end

  test 'backoffice settle persists and shows the resolution note' do
    post settle_backoffice_market_path(@market), params: { outcome: 'YES', resolution_note: 'Resolved per official source X.' }
    assert_equal 'Resolved per official source X.', @market.reload.resolution_note
  end

  test 'backoffice settle with a blank note does not settle' do
    post settle_backoffice_market_path(@market), params: { outcome: 'YES', resolution_note: '' }
    assert_not @market.reload.settled?
  end

  test 'admin settle requires a note (422) and returns it on success' do
    post settle_admin_market_path(@market), params: { outcome: 'YES' }, headers: auth_headers_for(@admin), as: :json
    assert_response :unprocessable_content

    post settle_admin_market_path(@market), params: { outcome: 'YES', resolution_note: 'Resolved per official source.' }, headers: auth_headers_for(@admin), as: :json
    assert_response :success
    assert_equal 'Resolved per official source.', JSON.parse(response.body)['resolution_note']
  end
end
```

> Auth helpers verified in this repo: backoffice tests sign in via `post '/signin', params: { email:, password: 'password123' }` (session cookie); admin API tests use `auth_headers_for(user)` from `test/test_helper.rb:29`. The `sign_in_backoffice`/`admin_auth_headers` helpers do **not** exist — do not invent them.

- [ ] **Step 3.2: Run to verify failure**

```bash
bin/rails test test/integration/resolution_transparency_test.rb -v
```
Expected: FAIL (controllers ignore the note; settle without note still works).

- [ ] **Step 3.3: Backoffice controller — pass the note, handle the error**

In `app/controllers/backoffice/markets_controller.rb#settle`:

```ruby
    def settle
      require_permission!('market.settle')
      return if performed?

      outcome = params[:outcome].to_s.upcase
      unless @market.open? || @market.closed?
        return redirect_to backoffice_market_path(@market), alert: 'Market must be open or closed to settle'
      end

      SettlementService.settle!(market: @market, outcome: outcome, actor: current_user,
                                resolution_note: params[:resolution_note])
      redirect_to backoffice_market_path(@market), notice: "Market settled: #{outcome}"
    rescue SettlementService::InvalidSettlement => e
      redirect_to backoffice_market_path(@market), alert: e.message
    end
```

- [ ] **Step 3.4: Backoffice view — rename field to `resolution_note`, mark required**

In `app/views/backoffice/markets/show.html.erb` (the settle form, ~line 86):

```erb
        <p><label>Resolution note <span style="color:#f44336;">*</span></label><br>
          <%= text_field_tag :resolution_note, nil, required: true, minlength: 20,
                data: { testid: "settle-reason" } %></p>
```

- [ ] **Step 3.5: Admin controller — require the note**

In `app/controllers/admin/markets_controller.rb#settle`:

```ruby
    def settle
      require_permission!('market.settle')
      return if performed?

      market = Market.find(params.expect(:id))
      outcome = params[:outcome].to_s.upcase
      market = SettlementService.settle!(market: market, outcome: outcome, actor: current_user,
                                         resolution_note: params[:resolution_note])
      render json: { id: market.id, status: market.status, settled_outcome: market.settled_outcome,
                     resolution_note: market.resolution_note, settled_at: market.settled_at }
    rescue SettlementService::InvalidSettlement => e
      render json: { error: e.message }, status: :unprocessable_content
    end
```

- [ ] **Step 3.6: Run to verify passing**

```bash
bin/rails test test/integration/resolution_transparency_test.rb -v
```
Expected: PASS

- [ ] **Step 3.7: Commit**

```bash
git add app/controllers/backoffice/markets_controller.rb app/controllers/admin/markets_controller.rb app/views/backoffice/markets/show.html.erb test/integration/resolution_transparency_test.rb
git commit -m "feat(settlement): thread resolution note through backoffice + admin settle (D7)"
```

---

## Task 4: Display the note + settled-at on the customer market page

**Files:**
- Modify: `app/views/web/markets/show.html.erb`, `app/views/backoffice/markets/show.html.erb`
- Test: add to `test/integration/resolution_transparency_test.rb`

- [ ] **Step 4.1: Write the failing test**

```ruby
test 'customer market page shows the resolution note and settled-at' do
  SettlementService.settle!(market: @market, outcome: 'YES', actor: @admin,
                            resolution_note: 'Resolved per official source X.')
  get "/web/markets/#{@market.id}"
  assert_select '[data-testid="market-resolution-note"]', text: /official source X/
  assert_select '[data-testid="market-settled-at"]'
end
```

- [ ] **Step 4.2: Run to verify failure**

```bash
bin/rails test test/integration/resolution_transparency_test.rb -n "/resolution note and settled-at/" -v
```
Expected: FAIL (no such elements).

- [ ] **Step 4.2b: Add backoffice display test**

Extend the integration test to assert the backoffice market page also shows the note and settled timestamp after settlement. Spec invariant 5 requires both customer and backoffice surfaces.

- [ ] **Step 4.3: Render in the resolution panel**

In `app/views/web/markets/show.html.erb`, inside the existing `market-resolution-panel` (after the `settled_outcome` block, ~line 247):

```erb
      <% if @market.resolution_note.present? %>
        <p style="margin:8px 0 0;" data-testid="market-resolution-note"><%= @market.resolution_note %></p>
      <% end %>
      <% if @market.settled_at.present? %>
        <p class="muted" style="font-size:0.82rem;margin:4px 0 0;" data-testid="market-settled-at">
          Settled <%= @market.settled_at.strftime('%Y-%m-%d %H:%M UTC') %>
        </p>
      <% end %>
```

Also render the same fields in the settled-market panel in `app/views/backoffice/markets/show.html.erb`, near the settled outcome display.

- [ ] **Step 4.4: Run to verify passing**

```bash
bin/rails test test/integration/resolution_transparency_test.rb -v
```
Expected: PASS

- [ ] **Step 4.5: Commit**

```bash
git add app/views/web/markets/show.html.erb app/views/backoffice/markets/show.html.erb test/integration/resolution_transparency_test.rb
git commit -m "feat(settlement): show resolution note + settled-at on market page (D7)"
```

---

## Task 5: Docs

- [ ] **Step 5.1:** In `docs/wiki/tech-debt-backlog.md`, mark product item **F-010 (resolution transparency)** as delivered by D7 for the mandatory-note path, and add a one-line pointer that the propose/approve/execute workflow remains **SEC-003** (synthesis).
- [ ] **Step 5.2:** Update `db/seeds.rb` so any `SettlementService.settle!` calls pass a valid `resolution_note:`; otherwise `db:seed`/`db:prepare` fails once the keyword becomes required.
- [ ] **Step 5.3:** Update `docs/WORK_LOG.md` + `docs/INDEX.md`.
- [ ] **Step 5.4:** Commit `docs: update INDEX and WORK_LOG after resolution transparency (D7)`.

---

## Self-Review Checklist
- [ ] Note required + length-validated at the single `settle!` entry point (Task 2) — every mechanism covered.
- [ ] `resolution_note` + `settled_at` persisted; audit metadata carries the note (Task 2).
- [ ] Backoffice + admin pass the note; blank/short note blocks settlement (Task 3).
- [ ] Customer and backoffice pages show note + settled-at (Task 4).
- [ ] `db/seeds.rb` still runs after the required `resolution_note:` keyword is added (Task 5).
- [ ] Existing settlement tests updated for the new required kwarg (Task 2).
- [ ] Full suite passes: `bin/rails test`; RuboCop clean.
- [ ] No placeholder steps remain.
