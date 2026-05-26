# Q&A

## Q: Docker overlay2 unblock — 2026-05-25
**Context:** Running `docker compose -f docker-compose.yml -f e2e/playwright/docker-compose.e2e.yml run --build --rm ui-tests` fails with overlay2 read-only filesystem error.
**Tried:** Verified docker-compose.e2e.yml syntax is correct; issue is at Docker engine layer.
**Need:** Docker daemon to be restarted or overlay2 storage to be repaired on the host, then re-run the resume command in PLAN.md.
