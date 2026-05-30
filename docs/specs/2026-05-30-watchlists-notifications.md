# Watchlists And Notifications Spec

**Decision:** D8-TODO-007 from `docs/superpowers/plans/2026-05-30-decision-planning-dispatch.md`.

**Goal:** Give players a persistent watchlist and an in-app notification feed without overloading `audit_events`.

**Selected option:** Use dedicated `market_watchlists` and `notifications` tables. `audit_events` remains the operator/trust log.

## Data Model

### `market_watchlists`

- `user_id: bigint`, required, FK to users.
- `market_id: bigint`, required, FK to markets.
- Unique index on `[user_id, market_id]`.
- Timestamps.

### `notifications`

- `user_id: bigint`, required, FK to users.
- `market_id: bigint`, optional FK to markets.
- `notification_type: string`, required.
- `title: string`, required.
- `body: text`, required.
- `read_at: datetime`, nullable.
- `metadata: jsonb`, default `{}`.
- Timestamps.
- Indexes on `[user_id, read_at, created_at]` and `[market_id, notification_type]`.

## First Notification Triggers

- Watched market settles.
- Watched market is cancelled, after D2 market cancellation exists.
- Watched market closes to new trading.
- Watched market receives a material metadata update, limited to `question`, `description`, `close_at`, `resolution_criteria`, or `resolution_source`.

## Routes And UI

- `POST /web/markets/:market_id/watchlist` toggles a market onto the current user's watchlist.
- `DELETE /web/markets/:market_id/watchlist` removes it.
- `GET /web/watchlist` shows watched markets.
- `GET /web/notifications` shows notifications and marks unread rows as read.
- Header/nav shows unread notification count for authenticated users.

## Out of Scope

- Email, SMS, push notifications.
- Price-threshold alerts.
- User-configurable notification preferences.
- Notification delivery retries; first implementation writes rows synchronously in the transaction that creates the event.

## Acceptance Checks

- A player can watch and unwatch a market.
- A player's watchlist page shows only that player's watched markets.
- Settling a watched market creates one notification for each watcher.
- Visiting `/web/notifications` marks notifications as read.
- `audit_events` schema and semantics are unchanged.
