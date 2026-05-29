#!/usr/bin/env bash
set -euo pipefail

echo "=== Adivento Validation ==="

# check 1: rubocop (skip if no config)
if [ -f .rubocop.yml ]; then
  echo "--- Rubocop ---"
  bundle exec rubocop
else
  echo "--- Rubocop: skipped (no .rubocop.yml) ---"
fi

# check 2: load structure.sql into test DB (requires PostgreSQL to be running)
echo "--- DB schema ---"
RAILS_ENV=test bin/rails db:drop db:create db:schema:load

# check 3: test suite
echo "--- Test suite ---"
bin/rails test

echo ""
echo "✓ All checks passed"
