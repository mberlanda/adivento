# Plan: Add RuboCop with Pinned Version

## Steps

- [ ] **Step 1: Choose RuboCop version**
  - Check rubygems.org (or `gem search rubocop`) for the latest stable versions of `rubocop`, `rubocop-rails`, and `rubocop-minitest`
  - Pin all three in Gemfile as exact pessimistic constraints:
    ```ruby
    gem 'rubocop', '~> X.Y', require: false
    gem 'rubocop-rails', '~> X.Y', require: false
    gem 'rubocop-minitest', '~> X.Y', require: false
    ```
    (Replace X.Y with actual current stable versions at implementation time)
  - Run `bundle install` and verify no conflicts
  - Expected: `Gemfile.lock` updated with pinned rubocop gems

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

- [ ] **Step 5: Add rubocop job to `.github/workflows/ci.yml`**
  - Add a `rubocop` job (can run in parallel with `test`):
    ```yaml
    rubocop:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true
        - run: bundle exec rubocop
    ```
  - Expected: CI runs rubocop on every push/PR

- [ ] **Step 6: Add rubocop to pre-commit hook (if applicable)**
  - Check whether `scripts/validate.sh` or any pre-commit hook script exists
  - If it does, append: `bundle exec rubocop --force-exclusion "$@"` (or equivalent)
  - If no hook script exists, skip this step (note in FINDINGS.md)
  - Expected: local pre-commit runs rubocop, or step skipped with note

- [ ] **Step 7: Commit**
  - Stage: `Gemfile`, `Gemfile.lock`, `.rubocop.yml`, `.github/workflows/ci.yml`, and all source files changed by autocorrect
  - Message: `feat(ci): add rubocop with pinned version`
  - Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
  - Expected: single clean commit, tests still pass after the style fixes
