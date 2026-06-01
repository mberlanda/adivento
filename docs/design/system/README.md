# Adivento Design System

Themeable, framework-agnostic component kit for the customer web, mobile web, and
backoffice. **One set of components, two pickable themes** — `light` ("Fantasy",
cream + teal, descends from today's `/web`) and `dark` ("Terminal", high-contrast
slate, descends from `/backoffice` + the PR2 wireframes). Switch with a single
attribute; every component reskins.

```
docs/design/system/
├── demo.html                 ← open this: every component, both themes, live toggle
├── INSTALL.md                ← exact copy-paths for this Rails app (start here to integrate)
├── dist/
│   ├── adivento.css          ← single-file bundle (tokens+application+components)
│   └── adivento.js           ← the interactions, ready to drop in
├── assets/
│   ├── tokens.css            ← the two themes as CSS custom properties
│   ├── application.css       ← base + atoms (buttons, chips, inputs, layout, utils)
│   ├── components.css        ← domain blocks (market card, prices, chart, order book…)
│   └── adivento.js           ← zero-dependency interactions (theme, tabs, sheet, chart, ticket)
├── erb/                      ← Rails styled partials, composable, drop into this app
│   ├── shared/               ← _adv_button, _adv_badge, _adv_mech_chip
│   ├── web/                  ← markets/_card, _price_boxes, _chart, _order_book, _pool,
│   │                            _settlement_explainer, shared/_nav, betslip_executions/_ticket
│   └── backoffice/           ← shared/_sidebar, _stat_cards, markets/_table
└── react/                    ← framework-rewrite kit (ESM .jsx): theme, atoms, charts, market
```

## 1. Themes — how the toggle works
Set the theme by putting `data-theme` on `<html>`:
```html
<html data-theme="light">   <!-- or "dark"; omit = light -->
```
Flip it at runtime with the JS helper (persists to `localStorage`, freezes
transitions during the swap so var-driven backgrounds don't stick):
```js
Adivento.theme.toggle();          // or .set('dark')
```
Any element with `data-ds-theme-toggle` becomes a toggle automatically.

> **Theme-switch gotcha (already handled):** transitioning the `background`
> shorthand across a theme change sticks mid-interpolation in Chromium. We
> suppress transitions for one frame via the `.ds-theming` class during the
> swap — keep that mechanism if you refactor the toggle.

## 2. Using the CSS (Rails / any app)
Load in order — tokens → application → components — then the JS at the end of body:
```erb
<%= stylesheet_link_tag "adivento/tokens", "adivento/application", "adivento/components" %>
<body class="ds-app" data-theme="light">
  ...
  <%= javascript_include_tag "adivento/adivento" %>
```
Put `class="ds-app"` on `<body>` (or the app root). All classes are prefixed
`.ds-` so they won't collide with anything already in the app.

## 3. ERB partials
Composable and local-driven — they map straight onto this repo's `/web` and
`/backoffice` controllers. Examples:
```erb
<%# discovery grid %>
<div class="ds-grid ds-grid--auto">
  <% @markets.each do |market| %>
    <%= render "web/markets/card", market: market %>
  <% end %>
</div>

<%# market detail %>
<%= render "web/markets/chart", points: market.price_history, value: market.yes_pct,
      stats: [["24h volume", market.volume_24h], ["Liquidity", market.liquidity],
              ["Holders", market.holders], ["24h trades", market.trades_24h]] %>
<%= render "web/betslip_executions/ticket", market: market, yes_pct: 62, no_pct: 38, balance: current_user.balance %>

<%# backoffice %>
<div class="ds-shell ds-app">
  <%= render "backoffice/shared/sidebar", current: :markets %>
  <main class="ds-main">
    <%= render "backoffice/shared/stat_cards", stats: @stats %>
    <%= render "backoffice/markets/table", markets: @markets %>
  </main>
</div>
```
Each partial's header comment documents its locals. They expect a few presenter
methods on your models (`#yes_pct`, `#volume_label`, `#closes_label`, …) — thin
helpers or a decorator; see comments. Nothing here changes your schema.

## 4. Interactions (`adivento.js`)
Auto-inits on `DOMContentLoaded`. Declarative hooks:
- `data-ds-theme-toggle` — theme switch button
- `data-ds-segment` / `data-ds-tabs` — segmented controls & tab panels
- `data-ds-sheet-open="id"` / `data-ds-sheet-close` — mobile bottom sheet + scrim
- `svg[data-ds-chart="44,47,…"]` / `svg[data-ds-spark="…"]` — draws the line/sparkline
- `[data-ds-ticket]` with `[data-ticket-stake]`, `.ds-pricebox[data-price]`,
  `[data-ticket-payout]`, `[data-ticket-profit]` — live payout math
- `Adivento.orderbook.render(el, {asks,bids,spread,last})` — order book
- `Adivento.live.start()` — **demo** random-walk price tick

**Wire real-time:** replace `Adivento.live` with your SSE handler. On each market
snapshot, update `[data-live-pct]` text and call `Adivento.chart.line(svg, points)`
+ `Adivento.orderbook.render(...)`. The DS gives you the DOM and the draw
functions; the data contract stays yours.

## 5. React kit (future rewrite)
`react/` is the same component set as ESM `.jsx` for when you move off Rails views
(Next, Remix, Vite, etc.). Import the three CSS files once at the app root, wrap in
`<ThemeProvider>`, then use `<MarketCard>`, `<BetTicket>`, `<OrderBook>`,
`<Chart>`, `<SettlementSteps>`, … (Vue port is mechanical — same classes, same
props; ask if you want it generated.)

## 6. Responsive
Mobile-first breakpoints baked in: grids collapse at 900/640px, the customer nav
hides its links on mobile (pair with the `.ds-tabbar`), the backoffice sidebar
becomes a horizontal scroller, the settlement stepper stacks vertically, and the
bet ticket is `position: fixed` as a sheet on small screens. `.ds-hide-mobile` /
`.ds-only-mobile` utilities for one-offs.

## Component checklist
Buttons · chips · mechanism tags · status/live badges · cards · inputs (+ suffix) ·
selects · segmented control · avatars · top nav · balance chip · backoffice sidebar ·
mobile tab bar · market card · probability bar · YES/NO price boxes · delta ·
price-history chart · sparkline · decision-stat strip · order book (CLOB) ·
bet ticket (live payout) · pool bar (parimutuel) · stat cards · data table ·
settlement stepper · callouts · bottom sheet + scrim · phone frame.
