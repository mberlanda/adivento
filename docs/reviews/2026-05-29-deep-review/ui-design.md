# UI Visual Design Deep Review

**Reviewer:** UI/Visual Design Specialist subagent  
**Date:** 2026-05-29  
**Worktree:** `/private/tmp/adivento-specialist-reviews`

---

## Scope

### Files inspected
- `app/views/layouts/application.html.erb` — web CSS design system (inline `<style>` block)
- `app/views/layouts/backoffice.html.erb` — backoffice CSS design system (inline `<style>` block)
- `app/views/web/markets/index.html.erb` — market browse page
- `app/views/web/markets/show.html.erb` — market detail page
- `app/views/web/leaderboard/index.html.erb` — leaderboard page
- `app/views/web/profile/show.html.erb` — player profile page
- `app/views/web/positions/index.html.erb` — positions page
- `app/views/web/betslip_executions/show.html.erb` — bet confirmation page
- `app/views/web/sessions/new.html.erb` — sign-in page
- `app/views/backoffice/dashboard/index.html.erb` — operations dashboard
- `app/views/backoffice/markets/index.html.erb` — market list + create form
- `app/views/backoffice/markets/show.html.erb` — market detail + settle form
- `app/views/backoffice/faucet_requests/index.html.erb` — faucet approval queue
- `app/views/backoffice/templates/index.html.erb` — template list + create form
- `app/views/backoffice/templates/_form.html.erb` — template form partial
- `app/views/backoffice/permissions/index.html.erb` — permission matrix
- `app/views/backoffice/grants/index.html.erb` — ad-hoc grant management
- `docs/design/00-design-brief.md` — design brief and theme DNA
- `docs/design/01-information-architecture.md` — IA and nav spec
- `docs/design/02-flows-and-use-cases.md` — acceptance criteria per screen
- `docs/design/03-settlement-and-resolution.md` — settlement design spec
- `docs/wiki/UX_BACKLOG.md` — 35-item UX gap inventory
- `docs/design/wireframes/v1/wireframes-web.jsx` — customer web wireframes
- `docs/design/wireframes/v1/wireframes-backoffice.jsx` — backoffice wireframes

### Explicitly out of scope
- Journey/IA (separate review: `ux-research-ia.md`)
- Backend correctness, performance, security
- Mobile native app design (separate review: `mobile-design.md`)
- Wireframe v2 directory content (alternative exploration, not primary direction)

---

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|
| P0 | **No `lang` attribute on `<html>`** — screen readers cannot determine document language | `application.html.erb:1`, `backoffice.html.erb:1` — both are `<html>` with no `lang="en"` | Add `lang="en"` to both layout `<html>` tags |
| P0 | **Buttons and nav links have no `:focus-visible` style** in either layout — keyboard users cannot see which element is active | `application.html.erb:30` — focus style only covers `input, select, textarea`, not `button` or `a`; `backoffice.html.erb` has zero focus rules | Add `button:focus-visible, a:focus-visible { outline: 2px solid var(--accent); }` to both layouts |
| P0 | **Form labels not programmatically associated** with their controls throughout the backoffice — labels are adjacent siblings with no `for`/`id` pairing and no wrapping | `backoffice/markets/show.html.erb:49,57,79,86` (settle, buyback), `backoffice/markets/index.html.erb:11,21,37` (create form), `backoffice/templates/_form.html.erb:4-12` — all use bare `<label>Text</label><br><input>` pattern | Use `f.label` (which generates `for` via Rails helpers) or add explicit `for`/`id` pairs |
| P0 | **Backoffice theme colors leak into two web-surface views** causing `--muted` value `#9fb2b8` (dark-theme muted, ~3.8:1 on white) to appear in light-mode web pages, failing WCAG AA (4.5:1) | `web/positions/index.html.erb:5,26,54` — `color:#9fb2b8` on white background; `web/betslip_executions/show.html.erb:8,29,38` — same color including on `color:#4caf7d` success text on `#0d2a1a` dark card background (dark-mode card hard-coded in a light-mode layout) | Replace `#9fb2b8` with `var(--muted)` in web views; remove the hardcoded dark card from `betslip_executions/show.html.erb` |
| P1 | **All market cards on the browse index display CLOB/LMSR/parimutuel odds as `%` using `leg.odds_minor / 100.0` formula**, which is only semantically valid for fixed-odds markets (e.g. CLOB contracts should show `¢`, LMSR shows probability) | `web/markets/index.html.erb:65` — single formula applied to all mechanisms | Detect `market.mechanism_type` in the card and format the price accordingly, matching the `show` page logic |
| P1 | **No responsive breakpoints exist in either layout** — the backoffice uses a rigid `220px + 1fr` sidebar grid (`backoffice.html.erb:10`) that will collapse on tablet/mobile; the web layout has no `@media` queries at all | `application.html.erb` — 0 `@media` rules; `backoffice.html.erb` — 0 `@media` rules; `index.html.erb:18` — card grid uses `minmax(300px, 1fr)` which works only above ~600px | Add at least one mobile breakpoint (≤768px) that collapses the backoffice sidebar and stacks the web card grid to 1 column |
| P1 | **Backoffice dashboard is nearly empty** — renders only 3 plain `<p>` text stats with no visual grouping, no stat boxes, no attention table, no faucet card | `backoffice/dashboard/index.html.erb:1-6` — 6 lines total; wireframe `WFBo.Dashboard` specifies a 4-stat KPI grid, markets-needing-attention table, pending-faucet card, recent-audit card | Implement UX-027 through UX-029 per `docs/superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md` |
| P1 | **Market detail page is single-column** — no sticky bet rail in right column as specified in the wireframe | `web/markets/show.html.erb` — linear vertical stack; `wireframes-web.jsx:86` specifies `gridTemplateColumns: '1fr 320px'` with sticky bet card | Implement UX-003 sticky bet rail per `docs/superpowers/plans/2026-05-29-ux-market-browse-detail.md` |
| P1 | **Backoffice settle action uses a browser `data-confirm` dialog** instead of the two-step confirmation with payout preview specified in the design | `backoffice/markets/show.html.erb:88` — `data: { confirm: "This will settle all bets. Proceed?" }` on submit button; wireframe `WFBo.Settle` shows payout preview box (`Will pay N winning bets · credit X ADIV`) before irreversible action | Implement UX-030 per `docs/superpowers/plans/2026-05-29-ux-backoffice-dashboard-settle.md` |
| P2 | **All CSS lives in two `<style>` blocks in layout files** — no external stylesheet, no partial, no design-token file. Design tokens (`--bg`, `--panel`, `--ink`, `--accent`, `--muted`, `--border`) are defined in the `:root` block but ~60 hardcoded hex values bypass them across views | `application.html.erb:7-41`; hardcoded colors in `web/markets/show.html.erb` (12 unique hex values), `web/profile/show.html.erb`, `web/leaderboard/index.html.erb`, `backoffice/markets/index.html.erb`, `backoffice/markets/show.html.erb` | Extract CSS to `app/assets/stylesheets/` and add semantic tokens: `--color-negative`, `--color-positive`, `--color-warning`, `--color-no-outcome`, `--color-settled-bg` |
| P2 | **No dark mode support** — neither `prefers-color-scheme: dark` media query nor a theme toggle class exists; the system-preference default for users with OS dark mode enabled would render the cream web theme with system inverted colors | `application.html.erb` — 0 dark mode rules; `00-design-brief.md:43` acknowledges Theme B is "dark + gold" but it is deployed only to `/backoffice`, not the web surface | Define `@media (prefers-color-scheme: dark)` overrides for the web layout or document this as a deliberate deferral |
| P2 | **Backoffice sidebar nav has no active state, no hover style, and no visual affordance** — links are bare `<a>` tags with single color `#d8e5e8` and `display:block` margin only | `backoffice.html.erb:31-37` — no `:hover`, no `aria-current`, no background highlight on active page | Add hover background + `aria-current="page"` to the active link, matching design brief "serious terminal" theme |
| P2 | **No `aria-label` or accessible name on icon-only affordances** — the balance chip (`balance-chip`), pagination arrows (`← Previous`, `Next →`), and close/settle submit buttons have no supplemental ARIA | `application.html.erb:15` — `.balance-chip` has no ARIA; `web/markets/index.html.erb:80,85` — pagination text is visible but `← Previous` / `Next →` arrows have no `aria-label`; profile bet-history filter pills missing `aria-pressed` | Add `aria-label` to balance chip; add `aria-label="Next page"` / `aria-label="Previous page"` to pagination links |
| P2 | **Developer artifact exposed to all visitors on the web market detail page** — a raw SSE stream URL is rendered in the "About this market" card for every visitor | `web/markets/show.html.erb:293` — `Live SSE stream: /sse/markets/<id>` inside `market-trust-panel` | Remove or gate behind moderator session; if intentional, move to a developer tools panel hidden behind an env flag |
| P3 | **Required-field asterisks (&#42;) are color-only** — `color:#f44336` red asterisk marks required fields in the backoffice create form, but there is no text or title label ("required") visible to screen readers | `backoffice/markets/index.html.erb:11,21,74` — `<span style="color:#f44336;">*</span>` | Wrap as `<span aria-hidden="true">*</span><span class="sr-only"> (required)</span>` and add `.sr-only` utility class |
| P3 | **Profile page P&L summary uses mixed display patterns** — "Won" count uses CSS var color (`#0e7c66`), "Lost" uses hardcoded `#c0392b`, Net P&L toggles between `#0e7c66` and `#c0392b` inline, while the wireframe specifies a 4-stat grid (Net P&L, Total bets, Win rate, Volume) as a unified stat-card row | `web/profile/show.html.erb:44-58` — ad-hoc color toggling mixed with stat-grid cards | Consolidate to stat-grid pattern (UX-020); replace hardcoded colors with semantic tokens |
| P3 | **CLOB order form labels `YES (Buy)` / `NO (Sell)`** are conceptually inaccurate — in a CLOB binary market, both sides are "buy" orders on a contract; "NO (Sell)" implies selling short which is a different operation from the `direction: buy` order being placed | `web/markets/show.html.erb:177` | Relabel to `YES contract` / `NO contract` or provide a tooltip clarifying the semantics |

---

## Detailed Notes

### Design system structure

The entire design system is implemented as two inline `<style>` blocks — one per layout. There is no external stylesheet, no Tailwind config, no SCSS, and no design-token file. This means every view file applies incremental styling via `style="..."` attributes, making the inline style count across views very high: `web/markets/show.html.erb` has 108 inline style attributes across 296 lines. This is the root cause of most of the consistency and maintainability findings below.

The defined CSS custom properties (`:root` in `application.html.erb:7`) are:
```
--bg: #f6f4ec   --panel: #ffffff   --ink: #18252f
--accent: #0e7c66   --muted: #5f6f79   --border: #d9e2df
```

These six tokens are partially used but many views bypass them with hardcoded hex values. A semantic layer is missing entirely (no `--color-negative`, `--color-positive`, `--color-no-outcome`, `--surface-warning`, etc.) — meaning "red for bad/loss" is implemented 5 different ways: `#d9534f`, `#c0392b`, `#f44336`, `#7a1f1a`, and inline color conditionals.

### Accessibility

**Critical issues:**

1. **`lang` attribute absent** (`application.html.erb:1`, `backoffice.html.erb:1`). WCAG 3.1.1 (Level A). Screen readers default to the OS language, causing incorrect pronunciation of English content for non-English OS users.

2. **Focus indicator scope** (`application.html.erb:30`). Focus ring is defined for `input, select, textarea` only. Buttons and anchor tags have no visible focus indicator when keyboard-navigated. WCAG 2.4.7 (Level AA). The backoffice layout has zero focus rules.

3. **Form label association** (`backoffice/markets/show.html.erb`, `backoffice/markets/index.html.erb`, `backoffice/templates/_form.html.erb`). Pattern throughout backoffice is bare `<label>Text</label><br><input>` — labels are adjacent siblings, not wrapping elements and not linked via `for`/`id`. Screen readers cannot announce the label when the input is focused. The web surface uses `form_with` helpers which in some cases auto-generate `for` attributes (when using `f.text_field :field_name`), but the backoffice forms extensively use `text_field_tag` / `number_field_tag` without explicit `id` params, breaking the association. WCAG 1.3.1 and 4.1.2 (Level A).

4. **Color contrast failures** from backoffice theme bleed:
   - `#9fb2b8` (backoffice `--muted`) on `#ffffff` panel background: contrast ratio ~3.8:1, failing WCAG AA (4.5:1 for normal text).
   - This color appears in `web/positions/index.html.erb:5,26,54` and `web/betslip_executions/show.html.erb:8,29,38`.
   - The betslip execution confirmation also hard-codes a dark card (`background:#0d2a1a; border-color:#2e7d52`) inside the web light layout — the text `#9fb2b8` on `#0d2a1a` passes, but the card itself creates a jarring "dark island" in a light-mode page, breaking visual coherence.

5. **Required field indicators** use color alone (`color:#f44336` red asterisk) with no text label, violating WCAG 1.4.1 (Level A) which prohibits using color as the sole conveying mechanism.

**Moderate issues:**

6. **No skip-to-content link** in either layout. Users who navigate via keyboard must tab through the entire header/nav on every page load before reaching main content. WCAG 2.4.1 (Level A).

7. **Table accessibility**: `web/positions/index.html.erb` and `backoffice/` tables lack `scope` attributes on `<th>` elements and have no `<caption>`. Screen readers may misassociate data cells to headers. WCAG 1.3.1.

8. **`aria-current` absent from nav**: Neither layout marks the active navigation item with `aria-current="page"`. Users navigating via screen reader receive no current-location signal.

### Responsive design

Neither layout file contains any `@media` query. The web layout relies entirely on CSS grid's `auto-fill / minmax` for the card grid, which degrades gracefully down to ~300px column width, but below 600px viewport width the stat-grids (`minmax(140px, 1fr)`) collapse in a non-optimal way. The backoffice layout is hardcoded at `grid-template-columns: 220px 1fr` (`backoffice.html.erb:10`) — on viewports narrower than ~600px the sidebar competes with the content area and makes the UI unusable.

The wireframe design brief explicitly calls out mobile as a target surface (`docs/design/00-design-brief.md:9` — "Customer web (desktop + mobile web)"). The design brief also acknowledges UX-034 (mobile responsive layouts + bottom-tab nav) is deferred, but zero breakpoints means even a user on an iPad will see the backoffice break.

### Theme consistency

The web surface ("Playful Fantasy" — cream, teal, rounded) and backoffice surface ("Serious Terminal" — dark, gold, dense) are well-differentiated in concept. The `00-design-brief.md` correctly documents both themes. However, the implementation boundary is leaking in two web-surface views that import dark-theme colors:

- `web/positions/index.html.erb` — `color:#9fb2b8` on table links and empty state text (backoffice muted color).
- `web/betslip_executions/show.html.erb` — entire dark confirmation card with `background:#0d2a1a`, border `#2e7d52`, and text `#9fb2b8` / `#4caf7d` rendered inside the light web layout.

These pages were likely written while looking at backoffice templates and the color constants were copied verbatim.

The backoffice header link to "Customer site" (`backoffice.html.erb:26`) uses `color:#d8e5e8` inline, a third unnamed color that appears nowhere else.

### Backoffice visual density and completeness

The dashboard (`backoffice/dashboard/index.html.erb`) is the most underdeveloped surface — 6 lines of markup, 3 plain-text stats, no visual grouping. The wireframe (`wireframes-backoffice.jsx:21-59`) specifies:
- A 4-column KPI stat grid (Open markets, House liability, Pending faucets, 24h volume)
- A "Markets needing attention" table with status chips and settle-now CTAs
- A "Pending faucet requests" summary card with inline approve/reject
- A "Recent audit events" panel

This gap (UX-027 through UX-029) means an operator opening `/backoffice` sees nothing actionable — they must navigate to individual sections to know what needs attention.

The faucet requests table (`backoffice/faucet_requests/index.html.erb`) shows "Amount (minor)" as a raw integer — `10000` instead of `1,000 ADIV` or `10,000 minor` — which lacks a unit label and is hard to parse. The wireframe table column is labeled "AMOUNT" with formatted values.

The settle form (`backoffice/markets/show.html.erb:76-91`) uses a browser native `data-confirm` dialog for an irreversible action. The design spec (`03-settlement-and-resolution.md`, wireframe `WFBo.Settle`) requires a two-step confirmation showing the number of winning bets and total payout credit before the operator commits.

### Component reuse and ad-hoc styles

No component abstraction layer exists (no `app/components/`, no view partials beyond `backoffice/templates/_form.html.erb`). Every view implements its own inline price panel, stat card, and badge. Notable inconsistencies:

- **Stat cards**: the `stat-card` CSS class is defined in the web layout and used in `web/profile/show.html.erb` and `web/markets/show.html.erb`, but `web/positions/index.html.erb` does not use it — positions renders a plain table with no stat summary.

- **Badges**: the web layout defines `.badge`, `.badge-status`, `.badge-tag`. The backoffice has no badge CSS class and uses inline styles (`background:#1a2e38; padding:2px 6px; border-radius:3px`) for the tags display in `backoffice/markets/show.html.erb:12`.

- **Price panels**: each mechanism type (fixed-odds, CLOB, LMSR, parimutuel) is implemented identically in both `show.html.erb` (rich) and `index.html.erb` (compact), but they are not extracted to shared partials. A change to the fixed-odds layout requires editing two places.

- **Flash messages**: the web layout and backoffice layout both define `.flash .notice .alert` rules, but with different values — backoffice `.notice` is `background:#1e3a2f` (dark green) and `.alert` is `background:#4a2222` (dark red) with no text color rule (`backoffice.html.erb:19-21`), meaning the alert text inherits the global `--ink: #ecf4f6` — a light text on dark-red background which works, but `.notice` light text on dark green may fail contrast at the border of AA.

### Semantic CLOB label issue

`web/markets/show.html.erb:177` labels CLOB sides as `YES (Buy)` / `NO (Sell)`. In binary prediction market CLOBs, both operations are "buy" orders for different contract types. The `NO (Sell)` label conflates a YES-short / NO-long with a sell action. While technically a player "selling" the NO position from someone else's perspective, the current order form places a `direction: buy` order for the NO leg. This label will confuse players familiar with standard CLOB semantics.

---

## Open Questions

1. **Dark mode scope**: is the OS `prefers-color-scheme: dark` case intentionally unhandled for the web surface (cream theme only), or is it a gap to address alongside Theme B? The design brief describes Theme B as backoffice-only, but doesn't explicitly state that OS dark mode should be ignored for the web surface.

2. **CSS architecture**: the team has not chosen Tailwind, SCSS, or any CSS preprocessor — everything lives in layout `<style>` blocks. Is this intentional for a POC (keeping dependencies minimal), or is there a plan to migrate to an external stylesheet or Tailwind during the next UX sprint? This decision affects how the backlog items below should be implemented.

3. **Accessibility target**: the design brief does not state a WCAG conformance level target. P0 findings above target WCAG 2.1 AA. Should WCAG 2.2 AA be the explicit target for the product, given the fintech/gaming context?

4. **Faucet amount display**: should `amount_minor` be displayed as-is (raw integer) throughout the backoffice UI, or should it be formatted with `number_with_delimiter` and a unit suffix? It is formatted on the web profile page but not in the faucet review table.

5. **SSE developer link**: is the `Live SSE stream:` link on `web/markets/show.html.erb:293` intentional (developer transparency feature) or a leftover from development? If intentional, what is the intended audience — players or developers?

---

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|---------------|------|------|--------------|-----------------|
| DS-001 | Add `lang="en"` to both layout `<html>` tags | XS | None | Both layouts render `<html lang="en">` |
| DS-002 | Add `:focus-visible` ring to `button` and `a` elements in both layouts | XS | None | Keyboard tab through nav and forms shows visible focus ring on every interactive element |
| DS-003 | Fix form `label`/`for` associations in all backoffice forms | S | None | Each backoffice form label is linked to its input via `for`/`id` or wraps the input element; screen reader announces label on focus |
| DS-004 | Replace backoffice dark-theme color constants in web surface views | XS | None | `web/positions/index.html.erb` and `web/betslip_executions/show.html.erb` use only `var(--*)` variables; `#9fb2b8`, `#4caf7d`, `#0d2a1a`, `#2e7d52` absent from web views |
| DS-005 | Fix market-card odds display per mechanism on `web/markets/index.html.erb` | S | None | CLOB cards show `¢` price or order-book mid; LMSR/parimutuel cards show probability %; fixed-odds shows `%` as before |
| DS-006 | Add skip-to-main-content link as first focusable element in both layouts | XS | None | Tab once from browser chrome lands on "Skip to content" link |
| DS-007 | Add `aria-current="page"` to active nav items in both layouts | XS | None | Screen reader announces "current" on the active nav link |
| DS-008 | Add at least one mobile breakpoint to backoffice layout — collapse sidebar at ≤768px | S | None | On 375px viewport, sidebar collapses to a hamburger or top bar; content fills width |
| DS-009 | Extract shared price-panel partials for the four mechanisms | M | None | `show.html.erb` and `index.html.erb` render the same partial; changing once updates both |
| DS-010 | Add semantic color tokens (`--color-positive`, `--color-negative`, `--color-settled`, `--color-no-outcome`) to both layout `:root` blocks and migrate hardcoded hex usages | M | None | Zero `#c0392b`, `#d9534f`, `#8a5c10`, `#4caf7d`, `#f44336` in `app/views/`; each replaced by a named token |
| DS-011 | Backoffice dashboard — implement stat-grid KPI + attention table + faucet card (UX-027–029) | M | UX backlog plan (`2026-05-29-ux-backoffice-dashboard-settle.md`) | Dashboard shows 4 stat boxes, markets-needing-attention table, pending-faucet summary card |
| DS-012 | Backoffice settle — replace `data-confirm` with two-step payout-preview confirmation (UX-030) | M | UX backlog plan | Moderator sees winning bet count + total credit before committing; action is irreversible only after explicit second confirm |
| DS-013 | Faucet requests table — display `amount_minor` with `number_with_delimiter` + "ADIV" suffix | XS | None | Faucet table shows "10,000 ADIV" not "10000" |
| DS-014 | Remove or gate the `Live SSE stream:` developer link from `web/markets/show.html.erb` | XS | None | Link absent from production renders or behind `if Rails.env.development?` guard |
| DS-015 | Required-field asterisks — add `.sr-only` text alongside color-only `*` indicators | XS | None | `<abbr title="required">*</abbr>` or SR-only "required" text accompanies each asterisk |
| DS-016 | Relabel CLOB bet form sides from `YES (Buy)` / `NO (Sell)` to semantically accurate labels | XS | None | Labels reflect that both are buy orders on their respective contract; tooltip explains |
| DS-017 | Add `scope="col"` to `<th>` elements in all data tables | XS | None | All tables in `positions`, `profile`, `leaderboard`, `backoffice/*` have scoped headers |
| DS-018 | Implement `@media (prefers-color-scheme: dark)` variable overrides for web layout, or document this as deferred | S | Design decision on Q1 above | Web layout either supports system dark mode or has explicit "not supported in v1" comment |
