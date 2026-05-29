# Adivento Wireframes — v2 (alternative direction)

A **dark, high-contrast "Terminal"** alternative to the v1 light card-stack. Diverges on all three axes so you can compare and mix-and-match.

## Open
Open `Alternatives.html` (same pan/zoom canvas controls as v1).

## What it explores
**A · Navigation / IA** — three home models:
- **A1 Feed-first** — live activity feed + trending movers + portfolio/watchlist rail.
- **A2 Category hub** — left category + community nav, featured grids per topic.
- **A3 Terminal dashboard** — watchlist sidebar + sortable market table + portfolio strip.

**B · Market detail & betting** — same market, three structures:
- **B1 Trading terminal** — chart + order book + buy/sell ticket rail (best for CLOB).
- **B2 Chart-dominant compact** — big chart + simple bet bar, collapsible details (best for fixed-odds/casual).
- **B3 Mobile terminal** — chart + bottom-sheet buy/sell.

**C · Visual structure** — Portfolio (with equity curve) + Leaderboard rendered in the dark terminal language to show the system holds.

## Palette (high-contrast slate — not black)
Defined in `wireframe-dark.jsx` as a `.wf-dark` variable scope that re-skins the shared primitives:
```
ink #eef2f9 · paper #1b2130 · fill #232c3e · line #4a566f · faint #2c3447
accent #5b9dd9 · warn #e3aa54 · pos #5cc491 · neg #e58178
```
This is the seed for **Theme B** in PR3's themeable stylesheet.

## Files
`Alternatives.html` · `design-canvas.jsx` · `wireframe-kit.jsx` (shared) · `wireframe-dark.jsx` (dark scope + chrome) · `wireframes-alt.jsx` (screens).
