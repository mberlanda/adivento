# DevOps / Operability Deep Review

## Scope

Reviewed the requested operational surfaces in this checkout: `CLAUDE.md`, `docs/INDEX.md`, `docs/wiki/architecture.md`, `Dockerfile`, `docker-compose.yml`, `docker-compose.e2e.yml`, `scripts/validate.sh`, `scripts/e2e.sh`, `scripts/install-hooks.sh`, `.github/workflows/ci.yml`, `config/recurring.yml`, `config/environments/*.rb`, `config/database.yml`, `config/cable.yml`, `config/puma.rb`, `config/routes.rb`, `bin/docker-entrypoint`, and the app code nearest Redis/SSE/background jobs (`app/services/hot_storage/*`, `app/controllers/sse/*`, `app/jobs/*`, and the services/controllers that project hot snapshots).

Focus areas: local setup, production-mode E2E, Docker, CI gates, health checks, recurring jobs, Redis/SSE dependencies, logging/auditability, deployment assumptions, and operational failure modes. I did not modify app code.

## Top Findings

| Priority | Finding | Evidence | Recommended next task |
|---|---|---|---|
| P0 | Redis is documented as an active cache/stream dependency, but the runnable stack and CI never start Redis, never set `REDIS_URL`, and the Redis gem is commented out, so hot storage silently degrades to `NullRedis`. | `docs/INDEX.md:12-18` lists Redis for cache/stream; `docs/wiki/architecture.md:17-18` shows Redis in topology; `Gemfile:13-14` comments out `gem 'redis'`; `docker-compose.yml:1-52` has only `db` and `web`; `docker-compose.e2e.yml:13-51` adds only `playwright`; `app/services/hot_storage/store.rb:35-55` falls back to `NullRedis` on missing gem/URL/error. | Add Redis as an explicit local/CI dependency, un-comment/add the client gem, set `REDIS_URL`, and add at least one E2E or integration check proving hot snapshots/events use real Redis. |
| P0 | Recurring jobs are configured but there is no observable production job adapter, scheduler, worker process, or Compose/CI process to run them. Automated market close is likely manual-only outside direct `perform_now` tests. | `config/recurring.yml:1-4` schedules `CloseExpiredMarketsJob`; `app/jobs/close_expired_markets_job.rb:1-4` uses Active Job default queue; production job adapter remains commented in `config/environments/production.rb:54-56`; repo search found no `solid_queue` gem/config/tables/bin/jobs; Compose runs only `rails server` in `docker-compose.yml:20-27` and E2E does the same in `docker-compose.e2e.yml:17-22`. | Choose and wire the queue backend (likely Solid Queue for Rails 8), add worker/scheduler process definitions, migrate queue tables if needed, and make CI/E2E assert the recurring close path runs through the configured backend. |
| P1 | Health checks only prove the Rails process can answer `/up`; they do not detect database readiness after boot, Redis disablement, queue worker absence, or recurring scheduler failure. | `config/routes.rb:1-2` maps `/up` to `rails/health#show`; `docker-compose.yml:44-49` and `docker-compose.e2e.yml:31-36` use only `curl -f http://localhost:3000/up`; Redis can be absent without failing boot via `app/services/hot_storage/store.rb:42-55`; background jobs are not represented in Compose. | Add readiness checks for DB, Redis when enabled, queue worker/scheduler heartbeat, and keep `/up` as a shallow liveness probe if desired. |
| P1 | SSE documentation promises snapshot-first plus incremental updates and resume support, but the controllers render one plain event and do not consume Redis streams or `Last-Event-ID`. | `docs/wiki/architecture.md:67-69` says SSE serves hot snapshots, then incremental updates, with `Last-Event-ID` resume; `HotStorage::Store#append_market_event!` writes Redis streams at `app/services/hot_storage/store.rb:82-92`; `app/controllers/sse/markets_controller.rb:7-16` renders one `market.snapshot.v1`; `app/controllers/sse/settlements_controller.rb:3-9` renders one settlement event. | Either implement true stream consumption/resume with operational tests, or update the docs/product surface to describe the current single-snapshot behavior. |
| P1 | Production-mode E2E is valuable, but it does not exercise Redis or workers and repeatedly runs `db:prepare` plus `db:seed` under `RAILS_ENV=production`, which can mask deployment assumptions and normalize seeding a production database. | E2E overlay sets `RAILS_ENV=production` and hardcoded `SECRET_KEY_BASE` at `docker-compose.e2e.yml:23-30`; web command runs `db:prepare`, `db:seed`, and server at `docker-compose.e2e.yml:17-22`; base entrypoint also runs `db:prepare` at `bin/docker-entrypoint:4-5`; overlay warning acknowledges seeded hardcoded credentials at `docker-compose.e2e.yml:9-11`. | Split E2E bootstrapping from production boot assumptions: add an explicit test setup command/service, avoid unconditional seed-on-server-start patterns, and add a CI mode that includes Redis and worker processes. |

## Detailed Notes

### Local Setup and Docker

Local setup is easy to start for the DB-backed Rails path: `CLAUDE.md:86-92` and `docs/INDEX.md:280-287` document `docker compose up -d db`, `bin/rails db:prepare`, and `bin/rails test`. The base Compose file gives Postgres a healthcheck (`docker-compose.yml:14-18`) and makes web wait for it (`docker-compose.yml:32-34`).

The stack is incomplete for the documented system topology. Redis is part of the public project description (`docs/INDEX.md:5-18`) and architecture topology (`docs/wiki/architecture.md:17-18`), but Docker starts no Redis service and exports no `REDIS_URL` (`docker-compose.yml:35-43`). Because `HotStorage::Store.build_default_redis` returns `NullRedis` when `REDIS_URL` is blank (`app/services/hot_storage/store.rb:42-43`), a local developer can believe they are running the full stack while never exercising Redis.

The Docker image is a workable development image, not a hardened production artifact. It installs build tools and all bundle groups without deployment flags (`Dockerfile:5-14`), runs as root by default, and does not precompile assets. That is acceptable for the current POC if documented as dev/E2E-only, but it is not enough for a production deployment baseline.

There is a duplicate boot concern: `bin/docker-entrypoint:4-5` runs `db:prepare`, while Compose web commands also run `db:prepare` and `db:seed` (`docker-compose.yml:22-27`, `docker-compose.e2e.yml:17-22`). This is operationally noisy and makes it easy to cargo-cult migration/seeding behavior into environments where server startup should not mutate data except through an explicit release phase.

### CI Gates and Validation

CI has a good baseline: unit validation runs on push and PR, uses PostgreSQL 17, uploads coverage, and then runs production-mode Playwright after unit tests (`.github/workflows/ci.yml:1-82`). The E2E wrapper is also operator-friendly: it builds the stack, waits for health, runs Playwright, prints web/db logs on failure, and cleans volumes (`scripts/e2e.sh:17-53`).

The gaps are dependency coverage and redundancy. CI only provisions Postgres (`.github/workflows/ci.yml:13-26`). The E2E job delegates to Compose, but Compose likewise lacks Redis and workers. `scripts/validate.sh` loads the schema and then runs tests (`scripts/validate.sh:14-20`), while CI has already loaded the test schema one step earlier (`.github/workflows/ci.yml:51-55`). That redundancy is not severe, but it does slow the critical path and can obscure which step actually failed schema loading.

The pre-commit hook runs the full validation script (`scripts/install-hooks.sh:1-8`). That is strict and useful for correctness, but `scripts/validate.sh:14-16` requires a reachable PostgreSQL test database and destructively drops/recreates it. The script correctly pins `RAILS_ENV=test`, but the local operator experience should call out that Postgres must be running and that the test DB is disposable.

### Redis and SSE

The hot/cold design is resilient in the narrow sense: when Redis is unavailable or misconfigured, reads fall back to PostgreSQL and projection errors are logged instead of breaking writes (`app/services/hot_storage/market_snapshot_reader.rb:3-15`, `app/services/hot_storage/market_snapshot_projector.rb:7-19`). That is a good failure mode for user-facing availability.

The same resilience creates a silent-operability hazard. Missing `REDIS_URL`, missing gem, or connection failure all lead to `NullRedis` plus a warning (`app/services/hot_storage/store.rb:32-56`). In production this should probably be controlled by explicit policy: optional Redis for dev/test, fail-fast or loud degraded mode for environments that claim Redis-backed realtime.

There is also a contract mismatch. Documentation says the SSE protocol sends a snapshot first, then incremental updates, with `Last-Event-ID` resume (`docs/wiki/architecture.md:67-69`). The store writes stream events (`app/services/hot_storage/store.rb:82-92`), and services append events after settlement/void flows (`app/services/settlement_service.rb:35-41`, `app/services/bet_void_service.rb:36-43`). But both SSE controllers return one rendered event and exit (`app/controllers/sse/markets_controller.rb:7-16`, `app/controllers/sse/settlements_controller.rb:3-9`). Operationally, long-lived SSE connection behavior, proxy buffering, reconnect behavior, Redis stream trimming, and client resume are not currently exercised.

### Background Jobs and Recurring Work

`CloseExpiredMarketsJob` itself is simple and mostly idempotent: it queries open markets past `close_at`, conditionally updates rows still in `open`, and writes an audit event (`app/jobs/close_expired_markets_job.rb:4-18`). It logs failures per market and continues (`app/jobs/close_expired_markets_job.rb:19-21`).

The operational wiring around it is the problem. `config/recurring.yml:1-4` is present, but the repository does not include the Solid Queue or equivalent runtime pieces needed to consume that schedule, and `production.rb` still has only commented queue-adapter examples (`config/environments/production.rb:54-56`). Compose and CI run only web plus DB/Playwright. That means an important market lifecycle state transition can pass unit tests while never happening in the deployed process model.

`RecordPriceSnapshotJob` and `HotStorage::ReconcileMarketHotStateJob` are also queue classes (`app/jobs/record_price_snapshot_job.rb:1-9`, `app/jobs/hot_storage/reconcile_market_hot_state_job.rb:1-34`), but I did not find enqueue sites for `RecordPriceSnapshotJob` or recurring config for hot-state reconciliation. The docs say reconciliation runs periodically (`docs/wiki/architecture.md:67-68`), so this is another docs/runtime mismatch.

### Health Checks and Deployment Assumptions

The only app health endpoint is Rails' default `/up` (`config/routes.rb:1-2`). That is fine as liveness, but using it as the only Compose healthcheck means E2E starts once the web process is responsive, not once the operational dependencies are healthy (`docker-compose.yml:44-49`, `docker-compose.e2e.yml:31-36`).

Production configuration is still mostly scaffold-default. SSL is commented (`config/environments/production.rb:41-42`), `require_master_key` is commented (`config/environments/production.rb:18-20`), static file serving depends on env (`config/environments/production.rb:22-24`), and stdout logging only activates with `RAILS_LOG_TO_STDOUT` (`config/environments/production.rb:84-88`). That can be acceptable for a POC, but it means a real deployment needs an explicit runbook for required env vars, TLS/reverse-proxy assumptions, asset serving, database migration strategy, Redis, queues, and worker processes.

### Logging and Auditability

Auditability is a product strength: the docs highlight ledger-first accounting (`docs/wiki/architecture.md:31`) and there is an `AuditEvent` model with required action/target fields (`app/models/audit_event.rb:1-4`). `CloseExpiredMarketsJob` creates audit events when it closes markets (`app/jobs/close_expired_markets_job.rb:12-18`).

Operational logs are currently unstructured. Production tags request IDs (`config/environments/production.rb:44-49`) and can log to stdout (`config/environments/production.rb:84-88`), but job errors log free-form strings and often only exception message, not structured fields or backtraces (`app/jobs/close_expired_markets_job.rb:20`, `app/jobs/hot_storage/reconcile_market_hot_state_job.rb:32`, `app/services/hot_storage/market_snapshot_projector.rb:16`). For incident response, the next step is not necessarily a full logging platform, but adding consistent structured fields around market id, job name, reason, actor, and exception class would pay off quickly.

One audit nuance: `CloseExpiredMarketsJob#system_actor` attributes system work to the first admin or first user (`app/jobs/close_expired_markets_job.rb:26-28`). That preserves a non-null actor but weakens audit semantics. A dedicated system actor or nullable/system actor model would be clearer for operations.

## Open Questions

- Is Redis intentionally optional in all environments, or only in development/test? The docs say optional fallback exists, but the architecture also treats Redis as the cache/stream layer.
- Should this Rails 8 app use Solid Queue, a different Active Job backend, or no async backend until the product needs it? `config/recurring.yml` implies a scheduler decision has already been made, but the runtime pieces are missing.
- Is the current SSE endpoint intended to be a single snapshot endpoint using SSE formatting, or should it be a true long-lived event stream with Redis stream replay?
- Are Docker and Compose meant only for local/E2E, or are they a deployment baseline? The current Dockerfile and boot commands are much safer if labeled dev/E2E-only.
- What is the intended production release flow for migrations and seeds? Server startup currently runs database preparation in Docker entrypoint and Compose commands.

## Backlog Candidates

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|---|---|---:|---|---|
| OPS-001 | Make Redis an explicit runtime dependency for the full stack: add Redis service, client gem, `REDIS_URL`, healthcheck, and docs/runbook updates. | M | Docker/Compose, Gemfile, CI | `docker compose up -d` starts Redis; app logs show real Redis client; an integration/E2E check proves a snapshot key or stream entry is written to Redis. |
| OPS-002 | Wire the background job backend and recurring scheduler for `CloseExpiredMarketsJob`. | M | Queue backend decision, migrations if Solid Queue | Production-mode Compose/CI starts a worker/scheduler; a market past `close_at` closes without direct `perform_now`; job failure logs are visible. |
| OPS-003 | Convert SSE market updates from single rendered event to documented stream behavior, or deliberately rename/document it as snapshot-only. | L | OPS-001 if true Redis stream replay is used | Test opens `/sse/markets/:id`, receives snapshot, triggers trade/update, receives second event on same connection, and reconnects with `Last-Event-ID`. |
| OPS-004 | Add readiness endpoints/checks for DB, Redis, and queue/scheduler while keeping `/up` as liveness. | M | OPS-001, OPS-002 | Compose healthcheck fails when required Redis or worker heartbeat is absent; `/up` remains fast and shallow. |
| OPS-005 | Split production boot, E2E setup, migrations, and seed data into separate commands/services. | M | Docker/Compose ownership decision | Web server command no longer runs seeds; E2E still provisions deterministic data through an explicit setup step; docs explain local vs E2E vs production boot. |
| OPS-006 | Harden production image/runtime baseline: deployment bundle flags, non-root user, asset precompile strategy, required env var documentation, and TLS/reverse-proxy assumptions. | M | Deployment target decision | Built image runs as non-root, boots with documented env vars, serves/preloads assets according to the chosen deployment model, and CI validates image build. |
| OPS-007 | Add structured operational logging for jobs and hot-storage degraded mode. | S | None | Job and hot-storage logs include job/service name, market id, reason/action, exception class, and request/job correlation where available. |
| OPS-008 | Introduce a dedicated system actor or system-audit representation for automated jobs. | S | Audit model decision | `CloseExpiredMarketsJob` audit events no longer attribute automated actions to an arbitrary first admin/user; tests cover the actor semantics. |
| OPS-009 | Add a local validation preflight for PostgreSQL and clarify destructive test DB behavior. | S | None | `scripts/validate.sh` fails early with an actionable message if Postgres is unavailable; docs state that `adivento_test` is dropped/recreated. |
| OPS-010 | Remove CI schema-load duplication or make the split intentional. | S | None | CI has one canonical schema-load path, or comments explain why both `.github/workflows/ci.yml` and `scripts/validate.sh` load schema. |
