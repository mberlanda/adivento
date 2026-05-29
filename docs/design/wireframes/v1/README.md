# Adivento Wireframes — v1 (primary direction)

Low-fidelity, grayscale wireframes for all four surfaces. Structure & flow only — theming happens in PR 3.

## Open
Open `Wireframes.html` in a browser. It's a self-contained pan/zoom **design canvas** (loads React + Babel from a CDN — needs network on first open).

- **Pan:** drag the background / two-finger scroll. **Zoom:** pinch / ctrl+wheel.
- **Focus a frame:** click its ⤢ button (top-right on hover), then use ←/→ to flip through a section, Esc to exit.
- **Export a frame:** ⋯ menu → Download PNG / HTML.

## Files
| File | Contents |
|------|----------|
| `Wireframes.html` | Canvas shell + section/artboard composition |
| `design-canvas.jsx` | Pan/zoom canvas component (starter) |
| `wireframe-kit.jsx` | Shared low-fi primitives (boxes, charts, chrome) |
| `wireframes-web.jsx` | Customer web screens |
| `wireframes-mechanisms.jsx` | The four betting-mechanism panels |
| `wireframes-mobile.jsx` | Native mobile app screens |
| `wireframes-backoffice.jsx` | Operator console screens |
| `wireframes-additions.jsx` | Settlement explainer + public/community markets |

## Sections
1. **Start here** — brief, assumptions, legend
2. **Customer Web** — browse · detail+chart/stats · profile · leaderboard · auth
3. **Betting mechanisms** — fixed-odds · CLOB · LMSR · parimutuel
4. **Native mobile app** — markets · detail+sheet · profile · leaderboard
5. **Backoffice** — dashboard · create+config · settle · faucet
6. **Stats, settlement & community** — how settlement works · public-vs-community browse · community hub · visibility selector

See `../../02-flows-and-use-cases.md` for the numbered design-note legend.
