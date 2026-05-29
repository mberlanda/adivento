# FINDINGS — Tier 0 implementation

## Outcome
All four Tier 0 items implemented, TDD, each its own PR, **stacked** in dependency order:

| PR | Item | Base | Local suite |
|----|------|------|-------------|
| #42 | TD-018 CLOB settle by net positions | `main` | 302 runs, 92.51% |
| #43 | TD-019 reserve open sell contracts | #42 | 303 runs, 92.51% |
| #44 | TD-013 wallet locking (8 sites) | #43 | 304 runs, 92.48% |
| #45 | UX-036 web registration | #44 | 307 runs, 92.59% |

Each: full `bin/rails test` green + `bundle exec rubocop` (197 files) clean.

## Decisions / non-obvious notes
- **Stacked PRs**, not 4 independent branches off main: the items share doc files
  (ATTENTION/WORK_LOG/tech-debt) which would conflict, and the user asked for sequential
  work. Each PR's base is the previous branch; GitHub auto-retargets to `main` as earlier
  PRs merge. **Merge in order #42 → #43 → #44 → #45.**
- **Concurrency test gotcha (TD-013):** the first version passed without the fix because
  both threads shared one `@user` object whose cached `wallet` AR instance was mutated by
  thread 1 and seen by thread 2. Fix: each thread does `User.find(@user.id)` for an
  independent read. Also `use_transactional_tests = false` + explicit teardown (committed
  rows aren't visible across connections inside a test transaction). RED then reliable 3/3.
- **TD-018 ⟂ TD-019:** independent in code. TD-018 settlement uses `NetPositionService`
  (filled buys − filled sells); TD-019 is creation-time available-to-sell accounting.
- Pre-existing local `main` divergence (UX plan commits) was illusory — same content already
  on origin/main under different SHAs; cherry-picks were empty. Only a minor `.gitignore`
  tweak is genuinely local and was left alone. Work is based on `origin/main` (incl. merged
  PR #41 reviews/synthesis).

## Remaining follow-ups surfaced (not Tier 0)
- TD-019: per-position fill-time revalidation under lock (concurrency edge).
- TD-021: extract shared `Clob::OrderCancellationService` (admin destroy now locks inline).
- Tier 1+ backlog in `docs/reviews/2026-05-29-deep-review/synthesis.md`.
