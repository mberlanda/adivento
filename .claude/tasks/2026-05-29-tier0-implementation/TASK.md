# Task: Implement Tier 0 backlog from deep-review synthesis

Implement, sequentially and each in its own PR, the four Tier 0 ("must fix before any
credible demo") items from `docs/reviews/2026-05-29-deep-review/synthesis.md`: TD-018 (CLOB
settle by net positions), TD-019 (reserve contracts for open CLOB sell orders), TD-013 (lock
wallet rows across all mutation paths + concurrency test), and UX-036 (web registration form +
session login). TDD throughout; bin/rails test must stay green; update docs per CLAUDE.md.
