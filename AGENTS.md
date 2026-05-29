# Adivento Codex Guide

This file is the lightweight Codex entrypoint. Keep `CLAUDE.md` in place for ClaudeCode; do not migrate or rename either agent setup.

## Load Only What You Need
- Start with the user's request and the nearest source files.
- Do not read `docs/INDEX.md`, `docs/WORK_LOG.md`, `.claude/tasks/`, or broad docs folders unless the task needs project history, architecture context, backlog status, or a handoff artifact.
- Prefer `rg` / `rg --files` to discover exact files before opening them.
- When docs are needed, read `docs/INDEX.md` first, then follow only the specific links relevant to the task.

## Project Snapshot
- Rails 8 monolith with PostgreSQL and Redis.
- Main surfaces: `app/controllers/web/`, `app/controllers/backoffice/`, and `app/controllers/admin/`.
- Core business logic lives in `app/services/`; data models live in `app/models/`.
- Tests are Minitest under `test/`; Playwright E2E lives under `e2e/playwright/`.

## Working Rules
- Keep changes surgical and aligned with existing style.
- Do not modify ClaudeCode files unless the request explicitly asks for ClaudeCode behavior.
- Do not touch unrelated dirty worktree changes.
- Run the narrowest useful verification for code changes; for docs-only changes, a review/read-through is enough.
- Use existing documentation templates only when creating ADRs, specs, plans, or plan reviews.

## Useful Commands
```bash
bin/rails test
bin/rails test path/to/file_test.rb
docker compose up -d db
scripts/validate.sh
```
