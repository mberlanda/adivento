# Market Taxonomy and Category Browsing — Implementation Plan

<!-- File location: docs/superpowers/plans/2026-05-27-market-taxonomy.md -->

**Goal:** Add category (enum) and tags (array) to markets; expose a category filter bar on the customer market list; display category badges and tags on market cards and detail pages; allow moderators to set category and tags in the backoffice.

**Architecture:** 3 PRs. PR 1 = DB + model (migration, enum, tags jsonb, fixtures). PR 2 = backoffice (category select + tags field in market form). PR 3 = customer-facing (category filter bar, badges, tags on detail page).

**Spec:** docs/product/BACKLOG.md — F-001

---

## PR 1 — DB + Model

**Files:**
- Create: `db/migrate/20260527200001_add_taxonomy_to_markets.rb`
- Modify: `app/models/market.rb`
- Modify: `test/fixtures/markets.yml`

### Task 1.1: Migration + model

- [ ] **Step 1.1.1:** Create migration

```ruby
class AddTaxonomyToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :category, :string, default: 'other', null: false
    add_column :markets, :tags, :jsonb, default: [], null: false
    add_index :markets, :category
  end
end
```

- [ ] **Step 1.1.2:** Add to Market model

```ruby
CATEGORIES = %w[sports economics politics technology entertainment other].freeze

validates :category, inclusion: { in: CATEGORIES }

def tags=(val)
  super(Array(val).map(&:strip).reject(&:empty?))
end
```

- [ ] **Step 1.1.3:** Update fixtures to add `category: other` (so tests don't break on NOT NULL)

- [ ] **Step 1.1.4:** Run migration and suite

```bash
bin/rails db:migrate && bin/rails test
```
Expected: 0 failures.

- [ ] **Step 1.1.5:** Commit

```bash
git add db/migrate/20260527200001_add_taxonomy_to_markets.rb db/schema.rb \
        app/models/market.rb test/fixtures/markets.yml
git commit -m "feat(taxonomy): add category enum and tags jsonb to markets"
```

---

## PR 2 — Backoffice UI

**Files:**
- Modify: `app/controllers/backoffice/markets_controller.rb`
- Modify: `app/views/backoffice/markets/_form.html.erb` (or equivalent)
- Modify: `test/integration/backoffice_markets_test.rb`

### Task 2.1: Backoffice form fields

- [ ] **Step 2.1.1:** Permit `category` and `tags` in markets controller strong params

- [ ] **Step 2.1.2:** Add category select and tags text input to the backoffice market form

Category:
```erb
<%= form.select :category, Market::CATEGORIES.map { |c| [c.capitalize, c] }, {}, class: 'form-select' %>
```

Tags (comma-separated, parsed in setter):
```erb
<%= form.text_field :tags_input, value: @market.tags.join(', '), placeholder: 'nba, fed, ai' %>
```

Handle `tags_input` param in controller: `market.tags = params[:market][:tags_input].to_s.split(',')`

- [ ] **Step 2.1.3:** Show category and tags on backoffice market show/list pages

- [ ] **Step 2.1.4:** Run suite

```bash
bin/rails test
```

- [ ] **Step 2.1.5:** Commit

```bash
git commit -m "feat(taxonomy): backoffice category select and tags field"
```

---

## PR 3 — Customer-Facing UI

**Files:**
- Modify: `app/controllers/web/markets_controller.rb`
- Modify: `app/views/web/markets/index.html.erb`
- Modify: `app/views/web/markets/show.html.erb`
- Modify: `test/integration/web_markets_test.rb` (or create)
- Modify: `config/routes.rb` (if needed)

### Task 3.1: Category filter bar

- [ ] **Step 3.1.1:** Scope `index` action by `params[:category]` when present

```ruby
def index
  @markets = Market.where(status: :open)
  @markets = @markets.where(category: params[:category]) if params[:category].present?
  @selected_category = params[:category]
end
```

- [ ] **Step 3.1.2:** Render horizontal filter bar above the market list

```erb
<div class="category-filter">
  <%= link_to 'All', web_markets_path, class: (@selected_category.nil? ? 'active' : '') %>
  <% Market::CATEGORIES.each do |cat| %>
    <%= link_to cat.capitalize, web_markets_path(category: cat),
        class: (@selected_category == cat ? 'active' : '') %>
  <% end %>
</div>
```

- [ ] **Step 3.1.3:** Add category badge to market card and tags list on market detail page

- [ ] **Step 3.1.4:** Run suite

```bash
bin/rails test
```

- [ ] **Step 3.1.5:** Commit

```bash
git commit -m "feat(taxonomy): category filter bar, badges, and tags on customer UI"
```

---

## Task N: Update docs

- [ ] Append entry to `docs/WORK_LOG.md`
- [ ] Update `docs/INDEX.md` (move F-001 to Done)
- [ ] Commit: `docs: update INDEX and WORK_LOG after market-taxonomy`

---

## Self-Review Checklist
- [ ] All CATEGORIES values covered in fixture
- [ ] Category filter URL-preserved (link_to with params)
- [ ] Tags setter strips whitespace and empties
- [ ] Full suite passes: `bin/rails test`
