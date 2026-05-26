# Findings

## 2026-05-26 — Plan written

Note: `MarketLeg` already has `validates :label, uniqueness: { scope: :market_id }` and a unique DB index on `(market_id, label)`. Only the count guard and the open-transition guard are missing.

Read `app/controllers/admin/market_legs_controller.rb` before Task 4 — integrate the 422 guard into the existing `create` action rather than replacing the whole method.

## 2026-05-26 — Implementation complete

All 5 tasks implemented. Key decisions:
- DB trigger uses BEFORE INSERT with a count subquery; `UPDATE` on `market_id` not guarded (FK is immutable in practice)
- `market_leg_count_within_limit` uses `.count` (DB query) not `.size` (cached) to be safe against in-memory associations
- `requires_two_legs_to_open` uses `.size` since association is already loaded in the open-transition context
- DB trigger test uses raw SQL INSERT and verifies `ActiveRecord::StatementInvalid` — only runs meaningfully against PostgreSQL dev/prod; SQLite in tests does not have the plpgsql trigger
