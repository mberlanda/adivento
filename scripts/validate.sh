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

# check 2: apply test schema
echo "--- DB schema ---"
bin/rails db:schema:load RAILS_ENV=test

# check 3: test suite
echo "--- Test suite ---"
bin/rails test

echo ""
echo "✓ All checks passed"
