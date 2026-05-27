# Plan: F-006 Backoffice Market Creation UX

**Date:** 2026-05-28  
**Status:** autonomous (user offline)

## Goal

Improve the backoffice market creation form's usability without changing any backend logic:
1. Group fields into three logical sections with headings
2. Add clearer help text on fee/liability fields
3. Add a live question preview box

## Scope

Single file: `app/views/backoffice/markets/index.html.erb`

No new routes, models, controllers, or tests required. The form's existing JavaScript mechanism toggle stays unchanged.

## Changes

### Section 1 — Basic Information
Fields: question, description, legs  
No changes to field HTML, just wrapped in `<fieldset>` with `<legend>`.

### Section 2 — Metadata & Resolution
Fields: category, tags_input, close_at, resolution_criteria, resolution_source  
Same treatment.

### Section 3 — Trading Mechanism
Fields: mechanism_type select + the four conditional divs  
Same treatment.

### Live Preview
A read-only `<div data-testid="market-preview">` below the question field, updated via `input` event:
- Shows: "Preview: {question text}" in muted style
- Empty when question is blank

### Help text additions
- `fee_bps`: hint "100 = 1%"  (already present, keep)
- `liability_cap_minor`: hint "max total payout the house will underwrite"
- `liquidity_subsidy_minor`: hint "ADIV seeded into the LMSR pool at market open"
- `taker_fee_bps`: hint "charged on the taker side of each fill"
- `takeout_bps`: hint "1500 = 15% vig"

## Implementation steps

- [ ] Wrap Basic Information fields in fieldset/legend
- [ ] Add live preview div + inline JS
- [ ] Wrap Metadata & Resolution fields in fieldset/legend
- [ ] Wrap Trading Mechanism fields in fieldset/legend
- [ ] Add help text to mechanism-specific fields
- [ ] Verify: `bin/rails test` passes, rubocop clean
- [ ] Open PR

## Not in scope

- New validation endpoint
- Mechanism preview (showing odds/pool preview) — deferred
- `new.html.erb` separate template — current pattern (inline on index) is fine
