# Findings

## Status: DONE — commit a44e865

## Implemented
- Gems: rubocop 1.86.2, rubocop-rails 2.35.3, rubocop-minitest 0.39.1 (patch-pessimistic pins)
- Use `plugins:` syntax (not `require:`) — these extensions support the new plugin API in rubocop 1.86
- Autocorrected 1696 offenses; 49 remaining resolved via .rubocop.yml config
- Disabled structural/metrics cops (Documentation, Metrics/*) — noise for a POC codebase
- `validate.sh` already gates rubocop when `.rubocop.yml` exists — no CI job change needed
- **Critical:** backoffice/web BaseControllers must stay on `ActionController::Base` (not ApplicationController < ActionController::API) for sessions/views/helpers to work. Added explicit Exclude in .rubocop.yml for `Rails/ApplicationController`

## Notes
- Tabs in db/seeds.rb resolved by autocorrect (converted to spaces) — no manual decision needed
- `db/migrate/` excluded (generated code)
- Pre-existing flaky test ordering issues (SQLite locking under certain seeds) — not introduced by rubocop
