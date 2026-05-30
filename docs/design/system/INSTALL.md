# Installing the Adivento Design System

Two ways to include it. **Quick start** = one CSS + one JS file. **Source** =
the split files + ERB partials wired into your existing views.

---

## Option A — Quick start (single bundle)

Copy two files out of `dist/`:

```
docs/design/system/dist/adivento.css   →  app/assets/stylesheets/adivento.css
docs/design/system/dist/adivento.js    →  app/javascript/adivento.js   (or app/assets/javascripts/)
```

### Rails 8 — Propshaft + importmap (this app's stack)
In `app/views/layouts/application.html.erb` (and `backoffice.html.erb`):
```erb
<%= stylesheet_link_tag "adivento", "data-turbo-track": "reload" %>
...
<body class="adv-app" data-theme="light">
  <%= yield %>
  <%= javascript_include_tag "adivento", defer: true %>
</body>
```
If you prefer importmap for the JS, it's a plain IIFE that sets `window.Adivento`,
so a classic `javascript_include_tag` is simplest — no `import` needed.

Add the asset to the precompile list if your setup needs it
(`config/initializers/assets.rb`):
```ruby
Rails.application.config.assets.precompile += %w[adivento.css adivento.js]
```

That's the whole install. Everything below is optional structure.

---

## Option B — Source files + ERB partials

### 1. Styles (split, easier to theme)
```
assets/tokens.css       →  app/assets/stylesheets/adivento/tokens.css
assets/application.css   →  app/assets/stylesheets/adivento/application.css
assets/components.css    →  app/assets/stylesheets/adivento/components.css
```
```erb
<%= stylesheet_link_tag "adivento/tokens", "adivento/application", "adivento/components" %>
```

### 2. JS
```
assets/adivento.js  →  app/javascript/adivento.js
```

### 3. ERB partials — they already mirror your view tree
The `erb/` folder uses the **same paths as `app/views/`**, so it's a near-direct copy:
```
erb/shared/_adv_button.html.erb                  →  app/views/shared/_adv_button.html.erb
erb/shared/_adv_badge.html.erb                   →  app/views/shared/_adv_badge.html.erb
erb/shared/_adv_mech_chip.html.erb               →  app/views/shared/_adv_mech_chip.html.erb

erb/web/shared/_nav.html.erb                     →  app/views/web/shared/_nav.html.erb
erb/web/markets/_card.html.erb                   →  app/views/web/markets/_card.html.erb
erb/web/markets/_price_boxes.html.erb            →  app/views/web/markets/_price_boxes.html.erb
erb/web/markets/_chart.html.erb                  →  app/views/web/markets/_chart.html.erb
erb/web/markets/_order_book.html.erb             →  app/views/web/markets/_order_book.html.erb
erb/web/markets/_pool.html.erb                   →  app/views/web/markets/_pool.html.erb
erb/web/markets/_settlement_explainer.html.erb   →  app/views/web/markets/_settlement_explainer.html.erb
erb/web/betslip_executions/_ticket.html.erb      →  app/views/web/betslip_executions/_ticket.html.erb

erb/backoffice/shared/_sidebar.html.erb          →  app/views/backoffice/shared/_sidebar.html.erb
erb/backoffice/shared/_stat_cards.html.erb       →  app/views/backoffice/shared/_stat_cards.html.erb
erb/backoffice/markets/_table.html.erb           →  app/views/backoffice/markets/_table.html.erb
```

### 4. Presenter glue (the only code you write)
The partials expect a handful of read methods on your `Market`. Add a presenter
or decorator — nothing touches the schema:

```ruby
# app/presenters/market_presenter.rb
class MarketPresenter < SimpleDelegator
  def yes_pct       = (yes_price * 100).round        # 0..100 (or cents for CLOB)
  def volume_label  = "Vol #{number_to_human(volume)}"
  def closes_label  = "Closes #{time_ago_in_words(closes_at)}"
  def spark         = price_history_points           # Array<0..100>, optional
  def delta         = price_change_24h               # optional
  def live?         = status == "open"
end
```
```erb
<% market = MarketPresenter.new(@market) %>
<%= render "web/markets/card", market: market %>
```

---

## Theme switching
- Default theme: `data-theme="light"` on `<html>` or `<body class="adv-app">`.
- Any element with `data-adv-theme-toggle` toggles + persists to `localStorage`.
- Programmatic: `Adivento.theme.set("dark")` / `Adivento.theme.toggle()`.

## Real-time (SSE) wiring
The DS draws; you feed data. On each market snapshot:
```js
Adivento.chart.line(svgEl, points);                 // redraw price history
Adivento.orderbook.render(bookEl, { asks, bids, spread, last });
document.querySelector('[data-live-pct]').textContent = pct + '%';
```
Remove the demo-only `Adivento.live.start()` call when you connect the real stream.

## React (future rewrite)
`react/` is the same kit as ESM modules — see `system/README.md` §5. Import the
three CSS files once at the app root, wrap in `<ThemeProvider>`, use the components.
