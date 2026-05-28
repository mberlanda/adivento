#!/usr/bin/env bash
# Run the full E2E stack.
# Usage: scripts/e2e.sh [--no-build]
#
# Exit code mirrors the Playwright exit code.
# On failure, web + db logs are printed automatically.

set -euo pipefail

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.e2e.yml"

BUILD_FLAG="--build"
if [[ "${1:-}" == "--no-build" ]]; then
  BUILD_FLAG=""
fi

teardown() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo "=== docker compose logs (web) ==="
    $COMPOSE logs web --tail=80 || true
    echo ""
    echo "=== docker compose logs (db) ==="
    $COMPOSE logs db --tail=20 || true
    echo ""
    echo "E2E run FAILED (exit $exit_code)"
  fi
  $COMPOSE down -v --remove-orphans 2>/dev/null || true
}
trap teardown EXIT

echo "=== Building and starting db + web ==="
$COMPOSE up -d $BUILD_FLAG db web

echo "=== Waiting for web to be healthy ==="
HEALTH_TIMEOUT_S="${HEALTH_TIMEOUT_S:-180}"
deadline=$(( $(date +%s) + HEALTH_TIMEOUT_S ))
attempt=0
until $COMPOSE ps web --format "{{.Status}}" 2>/dev/null | grep -q "(healthy)"; do
  if [[ $(date +%s) -ge $deadline ]]; then
    echo "Web did not become healthy within ${HEALTH_TIMEOUT_S}s."
    exit 1
  fi
  attempt=$((attempt + 1))
  echo "  attempt $attempt — $(( deadline - $(date +%s) ))s remaining..."
  sleep 5
done
echo "  Web is healthy."

echo "=== Running Playwright E2E tests ==="
# --no-deps: db and web are already running; don't touch them.
$COMPOSE run --rm --no-deps playwright
