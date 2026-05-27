#!/usr/bin/env bash
# Run the full E2E stack locally or in CI.
# Usage: scripts/e2e.sh [--no-build]
#
# Exit codes mirror the Playwright exit code.
# On failure, web + db logs are printed automatically.
#
# Timeouts:
#   Health wait  : HEALTH_TIMEOUT_S  (default 180s / 3 min)
#   Playwright   : controlled by playwright.config.js timeout (60s/test)

set -euo pipefail

BUILD_FLAG="--build"
if [[ "${1:-}" == "--no-build" ]]; then
  BUILD_FLAG=""
fi

HEALTH_TIMEOUT_S="${HEALTH_TIMEOUT_S:-180}"

teardown() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo "=== docker compose logs (web) ==="
    docker compose logs web --tail=60 || true
    echo ""
    echo "=== docker compose logs (db) ==="
    docker compose logs db --tail=20 || true
    echo ""
    echo "E2E run FAILED (exit $exit_code)"
  fi
  docker compose down -v --remove-orphans 2>/dev/null || true
}
trap teardown EXIT

echo "=== Starting main stack (db + web) ==="
docker compose up -d $BUILD_FLAG

echo "=== Waiting for web service to be healthy (timeout ${HEALTH_TIMEOUT_S}s) ==="
deadline=$(( $(date +%s) + HEALTH_TIMEOUT_S ))
attempt=0
until docker compose ps web --format "{{.Status}}" 2>/dev/null | grep -q "(healthy)"; do
  if [[ $(date +%s) -ge $deadline ]]; then
    echo "Web service did not become healthy within ${HEALTH_TIMEOUT_S}s."
    exit 1
  fi
  attempt=$((attempt + 1))
  echo "  attempt $attempt — $(( deadline - $(date +%s) ))s remaining..."
  sleep 5
done
echo "  Web service is healthy."

echo "=== Building ui-tests image ==="
docker compose -f docker-compose.yml -f e2e/playwright/docker-compose.e2e.yml build ui-tests

echo "=== Running Playwright E2E tests ==="
# --no-deps: do NOT touch web/db — they are already running and healthy
docker compose \
  -f docker-compose.yml \
  -f e2e/playwright/docker-compose.e2e.yml \
  run --rm --no-deps ui-tests
