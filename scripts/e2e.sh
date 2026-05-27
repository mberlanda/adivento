#!/usr/bin/env bash
# Run the full E2E stack locally or in CI.
# Usage: scripts/e2e.sh [--no-build]
#
# Exit codes mirror the Playwright exit code.
# On failure, web + db logs are printed automatically.

set -euo pipefail

BUILD_FLAG="--build"
if [[ "${1:-}" == "--no-build" ]]; then
  BUILD_FLAG=""
fi

teardown() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo "=== docker compose logs (web) ==="
    docker compose logs web || true
    echo ""
    echo "=== docker compose logs (db) ==="
    docker compose logs db || true
    echo ""
    echo "E2E run FAILED (exit $exit_code)"
  fi
  docker compose down -v --remove-orphans 2>/dev/null || true
}
trap teardown EXIT

echo "=== Starting stack ==="
docker compose up -d $BUILD_FLAG

echo "=== Waiting for web service to be healthy ==="
attempt=0
max_attempts=40
until docker compose ps web | grep -q "healthy"; do
  attempt=$((attempt + 1))
  if [[ $attempt -ge $max_attempts ]]; then
    echo "Web service did not become healthy after $max_attempts attempts."
    exit 1
  fi
  echo "  attempt $attempt/$max_attempts — waiting 5s..."
  sleep 5
done
echo "  Web service is healthy."

echo "=== Running Playwright E2E tests ==="
docker compose \
  -f docker-compose.yml \
  -f e2e/playwright/docker-compose.e2e.yml \
  run --build --rm ui-tests
