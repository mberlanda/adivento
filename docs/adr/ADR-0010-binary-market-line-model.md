# ADR-0010: Binary Market Line Model

## Status
Accepted

## Context
Business scenarios require multiple binary propositions under a common market context, with display-ready metadata and minimal client logic.

## Decision
Represent executable propositions as binary lines with two canonical sides and template-driven display labels. Keep no-hard-delete policy; canceled/voided statuses replace destructive deletion.

## Consequences
- Better support for election candidate and threshold markets.
- Clear path for localization and server-driven UI payloads.
- Requires invariant enforcement in schema and services.
