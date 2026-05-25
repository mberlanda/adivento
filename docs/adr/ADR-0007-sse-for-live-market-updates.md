# ADR-0007: SSE for Market and Settlement Live Updates

## Status
Accepted

## Context
Users and operators need low-latency updates for market status and settlements. WebSockets are heavier than required for first web iteration.

## Decision
Implement Server-Sent Events endpoints with versioned event names and Last-Event-ID handling.

## Consequences
- Minimal dependency realtime channel for web clients.
- Simpler operations than a websocket stack.
- Event envelopes can be reused by future event bus consumers.
