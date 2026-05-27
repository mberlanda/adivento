# Findings

## Status: Not started

## Notes
- Project uses Ruby 3.3.6 (set `TargetRubyVersion: 3.3` in .rubocop.yml)
- Project uses Rails 8 — use `rubocop-rails` for Rails-aware cops
- Project uses Minitest — use `rubocop-minitest` for test-specific cops
- Check existing code style before choosing a base config — the codebase may have inconsistent indentation (tabs vs spaces in db/seeds.rb)
- `db/migrate/` should be excluded from Rubocop (generated code)
