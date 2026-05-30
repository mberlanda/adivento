# Design Docs PR Checkpoint

Date: 2026-05-30

Goal: publish ZIP-provided design documentation as two separate PRs.

Inputs:
- `adivento-design-system.zip`
- `adivento-desing-quick-start.zip`

Plan:
1. Create `codex/docs-design-system` from `main`.
2. Import `adivento-design-system.zip` into `docs/design/system`, excluding `docs/design/system/dist/*` so the quick-start PR owns the distributable files.
3. Commit, push, and open a PR for the design system.
4. Create `codex/docs-design-quick-start` after the design-system branch/PR exists.
5. Import `adivento-desing-quick-start.zip` distributable files into `docs/design/system/dist`.
6. Commit, push, and open a PR for quick-start assets.

Current status:
- On branch `codex/docs-design-system`.
- Imported `adivento-design-system.zip` excluding `docs/design/system/dist/*`.
- Next: verify the diff, commit, push, and open the design-system PR.
