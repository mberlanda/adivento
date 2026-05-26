# Plan: E2E Playwright Test Suite

> BLOCKED — resume after Docker overlay2 filesystem issue is resolved.

## Resume command
```bash
docker compose up -d db web && \
bin/rails db:prepare && \
bin/rails db:seed && \
docker compose -f docker-compose.yml -f e2e/playwright/docker-compose.e2e.yml run --build --rm ui-tests
```

## Tasks

- [x] D1.1 Playwright project scaffold under `e2e/playwright/`
- [x] D1.2 `package.json` + `playwright.config.js` with BASE_URL, 3-browser matrix
- [x] D1.3 Docker Compose overlay `e2e/playwright/docker-compose.e2e.yml`
- [x] D1.4 Auth flow spec: register/login, nav visibility by role
- [x] D1.5 Backoffice flow spec: template → create market → open
- [x] D1.6 Player bet placement spec (uses authenticated API call)
- [x] D1.7 Settlement flow spec: moderator settles, UI reflects outcome
- [ ] D1.8 Wire CI/stage execution docs
- [ ] D1.9 Execute UI suite against running app — **BLOCKED (Docker overlay2)**
- [ ] D1.10 Add `data-testid` attributes to all views referenced by tests
- [ ] D1.11 Fix any failures found during D1.9 run
- [ ] D1.12 Commit passing suite
- [ ] D1.N Update docs (INDEX.md, WORK_LOG.md)
