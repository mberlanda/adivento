# Findings

## 2026-05-26 — Plan written

Note: `MarketLeg` already has `validates :label, uniqueness: { scope: :market_id }` and a unique DB index on `(market_id, label)`. Only the count guard and the open-transition guard are missing.

Read `app/controllers/admin/market_legs_controller.rb` before Task 4 — integrate the 422 guard into the existing `create` action rather than replacing the whole method.
