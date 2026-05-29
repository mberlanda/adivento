# Mobile App Design Deep Review

_Reviewed: 2026-05-29 — Adivento Rails 8 prediction-markets POC_

---

## Scope

### Files and docs inspected

| File | Purpose |
|------|---------|
| `docs/design/00-design-brief.md` | Audience table, design principles, theme DNA |
| `docs/design/01-information-architecture.md` | Navigation structure, screen inventory |
| `docs/design/02-flows-and-use-cases.md` | Per-screen use cases and acceptance criteria |
| `docs/design/wireframes/v1/wireframes-mobile.jsx` | 4 native-app low-fi screens (375px feel) |
| `docs/design/wireframes/v1/wireframe-kit.jsx:151–175` | PhoneStatus + TabBar mobile chrome primitives |
| `docs/design/wireframes/v1/README.md` | Section index; confirms "native mobile app" section |
| `docs/design/wireframes/v2/README.md` | Dark terminal alternative; B3 is a "mobile terminal" variant |
| `docs/wiki/UX_BACKLOG.md:49` | UX-034 — mobile-responsive layouts, deferred |
| `docs/wiki/tech-debt-backlog.md` | Full backlog; no mobile-specific TD items |
| `app/views/layouts/application.html.erb` | Customer web layout; all CSS is inline in `<style>` |
| `app/views/layouts/backoffice.html.erb` | Backoffice layout; fixed 220px sidebar grid |
| `app/views/web/markets/index.html.erb` | Market list (search input: `width:260px` hard-coded) |
| `app/views/web/markets/show.html.erb` | Market detail + bet forms |
| `e2e/playwright/playwright.config.js` | Desktop Chrome/Firefox/WebKit only — no mobile viewport |
| `docs/adr/ADR-0002-jwt-and-role-rbac.md` | "Mobile-friendly token auth path from day one" |
| `docs/adr/ADR-0004-dual-web-surfaces.md` | Two HTML surfaces only; no mobile namespace |
| `docs/adr/ADR-0007-sse-for-live-market-updates.md` | SSE chosen over WebSockets |
| `Gemfile` + `Gemfile.lock` | Ruby 3.3.6, Rails 8.1.3; no Turbo, no Importmap, no Stimulus |

### Explicitly out of scope

- Backoffice mobile ergonomics (operator tool; tablet/desktop is appropriate)
- Auth/JWT internals beyond noting mobile-friendliness already noted in ADR-0002
- Performance benchmarking (no running app in this review)
- App Store / Play Store ASO and submission logistics
- Community features (UX-033, deferred upstream)

---

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|----------------------|
| P0 | No responsive CSS for mobile — header nav overflows on small screens; search input is hard-coded to 260px | `application.html.erb:12–15` (no `@media` rules); `markets/index.html.erb:12` (`width:260px`) | Add CSS breakpoints and a hamburger/collapse for the top-nav; make search full-width below 600px |
| P0 | Backoffice layout is a fixed two-column grid that breaks entirely at narrow widths | `backoffice.html.erb:10` (`.shell { grid-template-columns: 220px 1fr }`) — no fallback | Add `@media (max-width: 768px)` that collapses sidebar into a top drawer or hamburger menu |
| P1 | No bet sheet on mobile — the quick-bet section is an inline block; on a 375px screen it competes for vertical scroll space and is not thumb-reachable | `markets/show.html.erb:131–215`; wireframe annotates "persistent bet sheet — thumb reachable" (`wireframes-mobile.jsx:78`) | Implement a sticky bottom sheet (CSS `position:fixed; bottom:0`) for the bet form on mobile |
| P1 | No bottom tab bar on mobile — the top nav has 5+ items that collapse to one line and have no touch-target sizing | `application.html.erb:49–69`; wireframe defines `TabBar` with Markets · Search · Positions · Profile (`wireframe-kit.jsx:163`) | Add `@media` CSS that hides the horizontal top-nav and shows a bottom tab bar below 640px |
| P1 | No mobile E2E coverage — Playwright runs Desktop Chrome/Firefox/WebKit only; no `devices['iPhone 14']` or equivalent project | `playwright.config.js:39–46` | Add a `mobile-chromium` project with `devices['Pixel 7']` and a `mobile-webkit` project with `devices['iPhone 15']`; add a focused mobile smoke spec (browse → tap card → bet sheet → submit) |
| P2 | No PWA artifacts — no `manifest.webmanifest`, no `<meta name="theme-color">`, no `apple-touch-icon`, no `apple-mobile-web-app-capable` | Confirmed absent in both layout files; no manifest file in worktree | Add a minimal web app manifest and iOS/Android meta tags; this unlocks "Add to Home Screen" for zero native-code cost |
| P2 | SSE (`EventSource`) reconnect behaviour on mobile background tabs is not handled in any view JS | `application.html.erb` has no JS; `sse/markets_controller.rb` exists but no client-side reconnect logic | Add a small vanilla-JS `EventSource` snippet with exponential backoff reconnect; mobile browsers aggressively kill background SSE connections |
| P2 | CLOB bet form has three inline fields side-by-side (`price, qty, submit`); on 375px all three squeeze into one row | `markets/show.html.erb:184–192` (`display:flex` on a single row with no wrap breakpoint for the submit button) | Wrap the three controls to a column below 500px, or move `Place Order` to its own full-width row |
| P3 | No mobile native strategy ADR — the design brief lists "Native mobile app" as a distinct surface (`00-design-brief.md:10`) but there is no ADR, spec, or plan for it; UX-034 is blocked on community features | `UX_BACKLOG.md:49` | Write ADR-0015 recommending Turbo Native (see Detailed Notes); unblock UX-034 from community feature dependency |
| P3 | No Turbo/Hotwire in the stack — Rails 8 ships with `turbo-rails` and `stimulus-rails` by default but the Gemfile omits both; this closes the Turbo Native path | `Gemfile` (no `turbo-rails`); `Gemfile.lock` (confirmed absent) | Decide before adding Turbo: either adopt it now for progressive mobile enhancement, or explicitly reject it in ADR-0015 |

---

## Detailed Notes

### 1. Responsive web is already partially there — it just needs media queries

The customer web layout uses `flex-wrap:wrap` throughout the view files and `grid-template-columns: repeat(auto-fill, minmax(300px, 1fr))` for market cards, which will reflow correctly on mobile. The blocking gap is the **fixed top-nav** and the **260px search input**. A single CSS block of four or five `@media` rules would make the index and list pages genuinely usable on a phone. The market detail page will also need the bet panel to become sticky.

**Hypothesis:** the current layout probably looks acceptable on a 768px tablet but collapses to a crowded one-liner on a 375px phone.

### 2. Recommendation: Turbo Native is the correct first mobile play, but it requires adding Turbo first

Given the constraints of a Rails 8 POC with one primary engineer and no existing native code, the mobile surface hierarchy should be:

**Phase 1 (lowest effort, highest demo impact):** Responsive web.
- Adds zero dependencies.
- Unlocks mobile browsers for the demo.
- Work: ~1–2 days CSS + one E2E mobile project.

**Phase 2 (credible native demo, ~1 week):** Progressive Web App.
- Add `manifest.webmanifest`, `theme-color`, `apple-touch-icon`, a service worker caching the shell.
- Installable from Safari and Chrome; gets a home-screen icon and standalone display mode.
- No App Store, no review process.
- Requires no additional Ruby code.

**Phase 3 (if a native feel is required for investor demo, ~2–4 weeks):** Turbo Native wrapper.
- Turbo Native (iOS Swift + Android Kotlin thin shells) wraps the existing HTML surfaces with native navigation chrome. The Rails server sends Turbo Frames; the native app renders them with native transitions.
- This is the exact architecture Rails 8 + Hotwire is designed for. Basecamp and HEY use it in production.
- Requires adding `turbo-rails` to the Gemfile, annotating key controllers with `turbo_stream` responses, and building a minimal native shell (~300 LOC Swift/Kotlin each).
- Does NOT require rewriting any business logic or bet flows.
- Unlocks push notifications via APNs/FCM through the native shell.
- Unlocks biometric login (Face ID/Touch ID) in the native shell wrapping the session cookie.

**Why not React Native/Expo or Flutter?**
- Both require rewriting all views and wiring a REST or GraphQL API. The admin JSON API exists (JWT, ADR-0002) but is internal/CI-only and not shaped for a consumer mobile client.
- The team would maintain two separate frontends (Rails HTML + RN/Flutter) in perpetuity.
- For a POC the payoff is negative: weeks of infra work to replicate what a Turbo Native shell gives in days.
- Flutter adds Dart as a third language; Expo/RN adds a Node.js/JS build pipeline with EAS — both are engineering overhead disproportionate to a fantasy-money POC.

**Why not fully native (Swift/Kotlin)?**
- Same argument as RN/Flutter, amplified. Requires full API surface design before a single screen works.
- Only appropriate if the product reaches product-market fit and needs native-only capabilities (live widgets, ARKit, complex animations).

### 3. SSE on mobile requires explicit reconnect handling

Mobile browsers (especially iOS Safari) terminate background `EventSource` connections aggressively. The existing SSE controllers (`sse/markets_controller.rb`) send versioned events with `Last-Event-ID` support, which is correct. But there is no client-side JS in any view that consumes SSE — the current views are server-rendered HTML with no live-update wiring. Any future mobile web implementation must add a reconnect loop. A vanilla `EventSource` with exponential backoff is ~30 lines of JS; a Stimulus controller wrapping it would fit the Hotwire model.

### 4. Auth is already mobile-ready

ADR-0002 explicitly notes "Mobile-friendly token auth path from day one." JWT bearer tokens are issued by `POST /auth/sessions`. A Turbo Native shell can store the token in Keychain (iOS) or Android Keystore and inject it on each request. A PWA can store it in `localStorage` or `sessionStorage`. No auth rework needed.

### 5. The wireframe design is complete and precise — it just needs to be implemented

`wireframes-mobile.jsx` has four production-ready low-fi screens: Markets list, Market detail + sticky bet sheet, Profile/wallet, and Leaderboard. The `wireframe-kit.jsx` defines `PhoneStatus` and `TabBar` primitives. The design intent is unambiguous: **bottom tab bar with 4 tabs, persistent bet sheet anchored above the tab bar, thumb-reachable**. This is exactly what a responsive CSS implementation + Turbo Native navigation chrome would deliver.

### 6. E2E mobile coverage gap

`playwright.config.js` defines only Desktop Chrome in Docker CI. Firefox and WebKit are skipped in Docker. There is no mobile device viewport project at all. Adding `{ name: 'mobile-chromium', use: { ...devices['Pixel 7'] } }` and a focused 5-step mobile smoke test (navigate to market → tap bet → submit → check balance) would close the most critical mobile regression risk.

---

## Open Questions

1. **Timeline and demo audience.** Is the next demo to investors who will test on their phones? Or is this a developer-facing POC? The answer determines whether Phase 1 (responsive CSS) is sufficient or whether Phase 2/3 (PWA or Turbo Native) is needed.

2. **Will Turbo/Hotwire be adopted?** The Gemfile explicitly omits `turbo-rails` and `stimulus-rails` (uncommented default Rails 8 lines). This was presumably a deliberate choice to keep the codebase minimal. Turbo Native depends on `turbo-rails`. Before writing ADR-0015, confirm whether the project will adopt the Hotwire stack.

3. **Push notification requirement.** Is settlement push notification (e.g., "Your YES bet on 'Will the proposal pass?' settled — you won 800 ADIV") a demo requirement? A PWA can use the Web Push API (works on Android Chrome; iOS Safari 16.4+ supports it). Turbo Native can use APNs/FCM through the native shell. This changes the Phase 2/3 recommendation.

4. **Biometric login.** Is Face ID / Touch ID a demo requirement? Only Turbo Native or a fully native app can deliver this. A PWA cannot.

5. **UX-034 unblocking.** The backlog entry says UX-034 (mobile-responsive layouts) is "blocked by community features." This is not the right dependency — responsive CSS is orthogonal to community features. Should UX-034 be rescheduled independently?

---

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|---------------|------|------|-------------|-----------------|
| MOB-001 | Add CSS media queries for mobile responsive layout: collapse top-nav, fix search input width, ensure market cards reflow on 375px | S (1–2 days) | None | Playwright `devices['Pixel 7']` smoke test passes; manual check in Chrome DevTools mobile emulation |
| MOB-002 | Implement sticky bottom bet sheet for market detail on mobile (position:fixed above tab-bar stand-in) | S (1 day) | MOB-001 | Bet form is visible without scrolling on 375×812 viewport; submit works |
| MOB-003 | Add mobile bottom tab bar: Markets · Search · Positions · Profile via CSS `@media (max-width: 640px)` | S (1 day) | MOB-001 | Tab bar renders at bottom on mobile; top-nav is hidden on mobile |
| MOB-004 | Add PWA web app manifest + iOS/Android meta tags (`theme-color`, `apple-touch-icon`, `display: standalone`) | XS (2–4h) | None | Chrome DevTools Lighthouse PWA audit: installable; "Add to Home Screen" triggers on Android Chrome |
| MOB-005 | Add mobile E2E projects to `playwright.config.js`: `devices['Pixel 7']` + `devices['iPhone 15']`; write mobile smoke spec (browse → detail → bet) | S (1 day) | MOB-001 through MOB-003 | CI passes with mobile projects; smoke spec covers bet submission |
| MOB-006 | Write ADR-0015 for mobile native strategy — formalise Turbo Native as the recommended native path; reject React Native/Flutter/fully-native for POC stage; define trigger criteria for re-evaluation | XS (2–4h, writing only) | Answer to Open Question 2 | ADR accepted; UX-034 unblocked from community-feature dependency |
| MOB-007 | Add `turbo-rails` + `stimulus-rails` to Gemfile; wire SSE market updates as a Stimulus controller with exponential-backoff EventSource reconnect | M (2–3 days) | Decision in ADR-0015 | Live dot pulses on market card on mobile without page refresh; SSE reconnects after tab background |
| MOB-008 | Turbo Native iOS shell (Swift): ~300-LOC WKWebView wrapper with native tab bar navigation chrome, Keychain token storage, and a push notification registration endpoint stub | L (2–4 weeks) | MOB-007 + ADR-0015; iOS developer account | App runs in iOS Simulator; navigation feels native; bet flow completes end-to-end |
| MOB-009 | Turbo Native Android shell (Kotlin): equivalent to MOB-008 for Android | L (2–4 weeks) | MOB-007 + ADR-0015; Android developer account | App runs in Android emulator; feature-parity with MOB-008 |
