# Plan: Add RuboCop with Pinned Version

## Steps

- [ ] **Step 1: Add RuboCop gems to Gemfile**
  - Versions pinned as of 2026-05-27 (patch-pessimistic — allows only bug-fix patches):
    ```ruby
    group :development, :test do
      gem 'rubocop', '~> 1.86.2', require: false
      gem 'rubocop-rails', '~> 2.35.3', require: false
      gem 'rubocop-minitest', '~> 0.39.1', require: false
    end
    ```
  - Run `bundle install` and verify no conflicts
  - Expected: `Gemfile.lock` updated with pinned rubocop gems (1.86.2 / 2.35.3 / 0.39.1)

- [ ] **Step 2: Create `.rubocop.yml`**
  - Inherit from `rubocop-rails` and `rubocop-minitest`
  - Set `AllCops` config:
    ```yaml
    require:
      - rubocop-rails
      - rubocop-minitest

    AllCops:
      TargetRubyVersion: 3.3
      NewCops: enable
      Exclude:
        - 'db/migrate/**/*'
        - 'db/schema.rb'
        - 'vendor/**/*'
        - 'node_modules/**/*'
        - 'bin/**/*'
    ```
  - Expected: `.rubocop.yml` created at repo root

- [ ] **Step 3: Run autocorrect**
  - Run: `bundle exec rubocop --autocorrect-all`
  - Review the diff to ensure no unintended rewrites (check indentation changes especially in `db/seeds.rb`)
  - Expected: many auto-correctable offenses fixed; remaining offenses listed

- [ ] **Step 4: Handle remaining offenses**
  - For each remaining offense, either:
    - Fix manually if straightforward
    - Add `# rubocop:disable CopName # reason` inline if the violation is intentional or too disruptive to fix now
  - Run `bundle exec rubocop` (no flags) and confirm zero offenses
  - Expected: clean rubocop run with exit code 0

- [x] **Step 5: CI and pre-commit — already wired**
  - `scripts/validate.sh` already contains: `if [ -f .rubocop.yml ]; then bundle exec rubocop; fi`
  - CI runs `scripts/validate.sh` in the `test` job — no separate rubocop job needed
  - Pre-commit hook also calls `validate.sh` — creating `.rubocop.yml` automatically activates rubocop in both

- [ ] **Step 7: Commit**
  - Stage: `Gemfile`, `Gemfile.lock`, `.rubocop.yml`, `.github/workflows/ci.yml`, and all source files changed by autocorrect
  - Message: `feat(ci): add rubocop with pinned version`
  - Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
  - Expected: single clean commit, tests still pass after the style fixes
