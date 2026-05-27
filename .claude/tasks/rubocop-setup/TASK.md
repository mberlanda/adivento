# Task: Add RuboCop with Pinned Version

Add RuboCop to the project with an explicitly pinned version in Gemfile. The goal is consistent style enforcement in CI without surprise version upgrades breaking the build.

## Why
- Style consistency across the codebase
- CI enforcement of code style (rubocop runs in GitHub Actions)
- Pinned version prevents silent behavior changes when RuboCop releases new cops or changes defaults
- Companion to the already-pinned bundler pattern used in .github/workflows/ci.yml
