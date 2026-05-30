# D8 Watchlists And Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add player watchlists and an in-app notification feed backed by dedicated product tables.

**Architecture:** Keep product notifications separate from `AuditEvent`. `MarketWatchlist` owns the user-market relationship, `Notification` owns player-visible messages, and small services create notifications for watched-market events. Web controllers render simple server-side HTML.

**Tech Stack:** Rails 8, PostgreSQL jsonb metadata, Minitest integration/model tests, existing session auth for `web/`.

**Spec:** `docs/specs/2026-05-30-watchlists-notifications.md`

---

## File Map

- Create: `db/migrate/YYYYMMDDHHMMSS_create_market_watchlists.rb`
- Create: `db/migrate/YYYYMMDDHHMMSS_create_notifications.rb`
- Create: `app/models/market_watchlist.rb`
- Create: `app/models/notification.rb`
- Create: `app/services/notifications/watched_market_notifier.rb`
- Create: `app/controllers/web/watchlists_controller.rb`
- Create: `app/controllers/web/notifications_controller.rb`
- Create: `app/views/web/watchlists/index.html.erb`
- Create: `app/views/web/notifications/index.html.erb`
- Modify: `app/models/user.rb`
- Modify: `app/models/market.rb`
- Modify: `app/services/settlement_service.rb`
- Modify: `app/jobs/close_expired_markets_job.rb`
- Modify: `app/controllers/backoffice/markets_controller.rb`
- Modify: `app/controllers/admin/markets_controller.rb`
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/web/markets/show.html.erb`
- Modify: `config/routes.rb`
- Tests: model, service, and integration tests listed below.
- Update after implementation: `docs/product/BACKLOG.md`, `docs/wiki/tech-debt-backlog.md`, `.claude/tasks/ATTENTION.md`, `docs/WORK_LOG.md`

## Task 1: Data model

- [ ] **Step 1: Generate migrations**

Run:

```bash
bin/rails generate model MarketWatchlist user:references market:references
bin/rails generate model Notification user:references market:references notification_type:string title:string body:text read_at:datetime metadata:jsonb
```

- [ ] **Step 2: Edit migrations**

In both migrations, ensure references are `null: false` and have `foreign_key: true`.

In the watchlist migration add:

```ruby
add_index :market_watchlists, %i[user_id market_id], unique: true
```

In the notifications migration ensure:

```ruby
t.jsonb :metadata, null: false, default: {}
add_index :notifications, %i[user_id created_at]
add_index :notifications, :user_id, where: 'read_at IS NULL', name: 'index_notifications_on_user_id_unread'
add_index :notifications, %i[market_id notification_type]
```

- [ ] **Step 3: Migrate dev + prepare test DB**

Run:

```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:prepare
```

Expected: `db/structure.sql` contains `market_watchlists`, `notifications`, the unique watchlist index, the feed index, and the partial unread notification index.

- [ ] **Step 4: Add model associations**

In `app/models/user.rb`:

```ruby
has_many :market_watchlists, dependent: :destroy
has_many :watched_markets, through: :market_watchlists, source: :market
has_many :notifications, dependent: :destroy
```

In `app/models/market.rb`:

```ruby
has_many :market_watchlists, dependent: :destroy
has_many :watching_users, through: :market_watchlists, source: :user
has_many :notifications, dependent: :nullify
```

In `app/models/market_watchlist.rb`:

```ruby
class MarketWatchlist < ApplicationRecord
  belongs_to :user
  belongs_to :market

  validates :user_id, uniqueness: { scope: :market_id }
end
```

In `app/models/notification.rb`:

```ruby
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :market, optional: true

  validates :notification_type, :title, :body, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(created_at: :desc) }

  def read? = read_at.present?
end
```

- [ ] **Step 5: Add model tests**

Create `test/models/market_watchlist_test.rb` and `test/models/notification_test.rb` with uniqueness, presence, and unread scope assertions.

- [ ] **Step 6: Run model tests**

Run:

```bash
bin/rails test test/models/market_watchlist_test.rb test/models/notification_test.rb
```

Expected: pass after implementation.

## Task 2: Watchlist UI and routes

- [ ] **Step 1: Add routes**

In `config/routes.rb` under `namespace :web`:

```ruby
get :watchlist, to: 'watchlists#index'
post 'markets/:market_id/watchlist', to: 'watchlists#create', as: :market_watchlist
delete 'markets/:market_id/watchlist', to: 'watchlists#destroy'
resources :notifications, only: [:index]
```

- [ ] **Step 2: Add controller**

Create `app/controllers/web/watchlists_controller.rb`:

```ruby
module Web
  class WatchlistsController < BaseController
    def index
      @markets = current_user.watched_markets.order(created_at: :desc)
    end

    def create
      market = Market.find(params.expect(:market_id))
      current_user.market_watchlists.find_or_create_by!(market: market)
      redirect_to web_market_path(market), notice: 'Market added to watchlist'
    end

    def destroy
      market = Market.find(params.expect(:market_id))
      current_user.market_watchlists.where(market: market).destroy_all
      redirect_to web_market_path(market), notice: 'Market removed from watchlist'
    end
  end
end
```

- [ ] **Step 3: Add market show toggle**

In `app/views/web/markets/show.html.erb`, add:

```erb
<% if current_user %>
  <% watching = current_user.market_watchlists.exists?(market: @market) %>
  <% if watching %>
    <%= button_to "Watching", web_market_watchlist_path(@market), method: :delete, data: { testid: "watchlist-toggle" } %>
  <% else %>
    <%= button_to "Watch", web_market_watchlist_path(@market), method: :post, data: { testid: "watchlist-toggle" } %>
  <% end %>
<% end %>
```

- [ ] **Step 4: Add watchlist page**

Create `app/views/web/watchlists/index.html.erb` with a simple market list:

```erb
<h1>Your watchlist</h1>
<% if @markets.any? %>
  <div class="market-grid">
    <% @markets.each do |market| %>
      <article class="card">
        <h3><%= link_to market.question, web_market_path(market) %></h3>
        <p><%= market.status %> · <%= market.mechanism_type %></p>
      </article>
    <% end %>
  </div>
<% else %>
  <p class="muted">No watched markets yet.</p>
<% end %>
```

- [ ] **Step 5: Add integration test**

Create `test/integration/web_watchlists_test.rb` that signs in as player, posts watchlist create, asserts row exists, visits `/web/watchlist`, then deletes it.

## Task 3: Notifications feed

- [ ] **Step 1: Add controller**

Create `app/controllers/web/notifications_controller.rb`:

```ruby
module Web
  class NotificationsController < BaseController
    def index
      @notifications = current_user.notifications.includes(:market).newest_first.limit(100)
      current_user.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)
    end
  end
end
```

- [ ] **Step 2: Add view**

Create `app/views/web/notifications/index.html.erb`:

```erb
<h1>Notifications</h1>
<% if @notifications.any? %>
  <% @notifications.each do |notification| %>
    <article class="card" data-testid="notification-row">
      <h3><%= notification.title %></h3>
      <p><%= notification.body %></p>
      <% if notification.market %>
        <%= link_to "View market", web_market_path(notification.market) %>
      <% end %>
    </article>
  <% end %>
<% else %>
  <p class="muted">No notifications yet.</p>
<% end %>
```

- [ ] **Step 3: Add nav links and unread count**

In `app/views/layouts/application.html.erb`, for signed-in users add links to Watchlist and Notifications. Use:

```erb
<% unread_count = current_user.notifications.unread.count if current_user %>
```

Show `Notifications (<%= unread_count %>)` when positive.

- [ ] **Step 4: Add integration test**

Create `test/integration/web_notifications_test.rb` that creates two notifications, visits `/web/notifications`, asserts they render, and asserts unread rows get `read_at`.

## Task 4: Notification service and first triggers

- [ ] **Step 1: Create notifier service**

Create `app/services/notifications/watched_market_notifier.rb`:

```ruby
module Notifications
  class WatchedMarketNotifier
    def self.market_settled!(market:)
      market.watching_users.find_each do |user|
        Notification.create!(
          user: user,
          market: market,
          notification_type: 'market_settled',
          title: 'Market settled',
          body: "#{market.question} settled #{market.settled_outcome}.",
          metadata: { market_id: market.id, outcome: market.settled_outcome }
        )
      end
    end

    def self.market_closed!(market:)
      market.watching_users.find_each do |user|
        Notification.create!(
          user: user,
          market: market,
          notification_type: 'market_closed',
          title: 'Market closed',
          body: "#{market.question} is closed for new trades.",
          metadata: { market_id: market.id }
        )
      end
    end

    def self.market_updated!(market:, changed_fields:)
      return if changed_fields.empty?

      market.watching_users.find_each do |user|
        Notification.create!(
          user: user,
          market: market,
          notification_type: 'market_updated',
          title: 'Market updated',
          body: "#{market.question} had important details updated.",
          metadata: { market_id: market.id, changed_fields: changed_fields }
        )
      end
    end

    def self.market_cancelled!(market:)
      market.watching_users.find_each do |user|
        Notification.create!(
          user: user,
          market: market,
          notification_type: 'market_cancelled',
          title: 'Market cancelled',
          body: "#{market.question} was cancelled.",
          metadata: { market_id: market.id }
        )
      end
    end
  end
end
```

- [ ] **Step 2: Call after settlement**

In `SettlementService.settle!`, after the settlement transaction has committed and after `market.reload`, call the notifier outside the financial transaction:

```ruby
begin
  Notifications::WatchedMarketNotifier.market_settled!(market: market.reload)
rescue StandardError => e
  Rails.logger.warn("watched-market settlement notification failed: #{e.class}: #{e.message}")
end
```

Do not call the notifier inside the `ApplicationRecord.transaction` that settles payouts; notification failure must never roll back settlement, ledger, or wallet writes.

- [ ] **Step 3: Call after auto-close**

In `CloseExpiredMarketsJob`, after a market transitions to closed:

```ruby
begin
  Notifications::WatchedMarketNotifier.market_closed!(market: market.reload)
rescue StandardError => e
  Rails.logger.warn("watched-market close notification failed: #{e.class}: #{e.message}")
end
```

- [ ] **Step 4: Call after material market updates**

In `Backoffice::MarketsController#update` and `Admin::MarketsController#update`, capture important changed fields before save and notify after successful update. Use the controller's actual market variable (`@market` in backoffice, local `market` in admin).

Backoffice permits metadata fields but not `question`:

```ruby
watched_fields = %w[description close_at resolution_criteria resolution_source]
@market.assign_attributes(market_update_params)
changed_fields = @market.changes.keys & watched_fields
if @market.save
  notify_market_updated(@market, changed_fields)
end
```

Admin can update `question`:

```ruby
watched_fields = %w[question description close_at resolution_criteria resolution_source]
market.assign_attributes(market_params)
changed_fields = market.changes.keys & watched_fields
if market.save
  notify_market_updated(market, changed_fields)
end
```

Use a small private helper in each controller (or one shared helper) that rescues notifier failures:

```ruby
def notify_market_updated(market, changed_fields)
  Notifications::WatchedMarketNotifier.market_updated!(market: market.reload, changed_fields: changed_fields)
rescue StandardError => e
  Rails.logger.warn("watched-market update notification failed: #{e.class}: #{e.message}")
end
```

- [ ] **Step 5: Leave cancellation trigger as D2 integration follow-up**

D2 owns `MarketCancellationService`. Add a comment to that D2 implementation plan or the D8 docs after both land:

```ruby
Notifications::WatchedMarketNotifier.market_cancelled!(market: market.reload)
```

- [ ] **Step 6: Add service tests**

Create `test/services/notifications/watched_market_notifier_test.rb` that watches a market with two users and asserts two notification rows for settlement, closed, updated, and cancelled events.

## Task 5: Verification and docs

- [ ] **Step 1: Run targeted tests**

Run:

```bash
bin/rails test test/models/market_watchlist_test.rb test/models/notification_test.rb \
  test/integration/web_watchlists_test.rb test/integration/web_notifications_test.rb \
  test/services/notifications/watched_market_notifier_test.rb
```

Expected: all pass.

- [ ] **Step 2: Run full suite**

Run:

```bash
bin/rails test
```

Expected: all tests pass, 0 failures.

- [ ] **Step 3: Update docs and commit**

Update `docs/product/BACKLOG.md`, `docs/wiki/tech-debt-backlog.md`, `.claude/tasks/ATTENTION.md`, and `docs/WORK_LOG.md`.

Commit:

```bash
  git add \
    app/models/market_watchlist.rb app/models/notification.rb \
    app/services/notifications/watched_market_notifier.rb \
    app/controllers/web/watchlists_controller.rb app/controllers/web/notifications_controller.rb \
    app/views/web/watchlists/index.html.erb app/views/web/notifications/index.html.erb \
    app/models/user.rb app/models/market.rb app/services/settlement_service.rb \
    app/jobs/close_expired_markets_job.rb app/controllers/backoffice/markets_controller.rb \
    app/controllers/admin/markets_controller.rb app/views/layouts/application.html.erb \
    app/views/web/markets/show.html.erb config/routes.rb db/migrate db/structure.sql \
    test/models/market_watchlist_test.rb test/models/notification_test.rb \
    test/integration/web_watchlists_test.rb test/integration/web_notifications_test.rb \
    test/services/notifications/watched_market_notifier_test.rb \
    docs/product/BACKLOG.md docs/wiki/tech-debt-backlog.md .claude/tasks/ATTENTION.md docs/WORK_LOG.md
  git commit -m "feat(web): add watchlists and notifications"
```
