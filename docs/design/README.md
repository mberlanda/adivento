# Adivento — Design Documentation

Design artifacts and specs for the Adivento prediction-market platform. This folder is the design counterpart to the engineering docs in `docs/` — it captures **what the product looks like and how it behaves**, so implementation in `app/views/{web,backoffice}` and the future mobile app can be derived directly.

> Maps to the existing surfaces described in `docs/wiki/product-overview.md` (`/web`, `/backoffice`, `/admin`).

## Delivery (three PRs)

| PR | Scope | Status |
|----|-------|--------|
| **1** | Wireframes (primary direction) + these specs | ← this PR |
| **2** | Alternative wireframes (different IA/layout directions to compare) | next |
| **3** | Themeable stylesheet + interactions (predefined CSS classes, two pickable themes) | after |

## Contents

| File | What |
|------|------|
| [`00-design-brief.md`](00-design-brief.md) | Assumptions, audience, design system DNA, the two theme directions |
| [`01-information-architecture.md`](01-information-architecture.md) | Surfaces, navigation, screen inventory, route map |
| [`02-flows-and-use-cases.md`](02-flows-and-use-cases.md) | Per-screen use cases + numbered design-note legend |
| [`03-settlement-and-resolution.md`](03-settlement-and-resolution.md) | Lifecycle, per-mechanism payout, disputes, trust model |
| [`04-public-and-community-markets.md`](04-public-and-community-markets.md) | Public vs community-restricted bets, groups/roles/invites |
| [`wireframes/v1/`](wireframes/v1/) | The interactive wireframe canvas (open `Wireframes.html`) |

## Viewing the wireframes

`wireframes/v1/Wireframes.html` is a self-contained pan/zoom canvas. Open it in any browser (it loads React + Babel from a CDN). Click a frame's ⤢ to focus it; use ←/→ to flip through a section.

Sections: **Start here** (brief) · **1 Customer Web** · **2 Betting mechanisms** · **3 Native mobile app** · **4 Backoffice** · **5 Stats, settlement & community**.

## Benchmarks

Layout and information decisions were reviewed against **Polymarket** and **Kalshi** for patterns only — implied-probability-forward cards, price-history charts with timeframe toggles, explicit resolution source/criteria on every market, and an activity/holders feed. The visual design is original to Adivento.
