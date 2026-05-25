# ADR-0002: JWT Auth with Role-Based Access Control

## Status
Accepted

## Context
The MVP requires web and future mobile clients, role-based behavior, and lightweight stateless auth.

## Decision
Adopt JWT bearer tokens and role checks (`admin`, `moderator`, `player`) at controller boundary.

## Consequences
- Mobile-friendly token auth path from day one.
- Clear isolation of privileged operations.
- A future permission matrix can replace direct role checks without breaking endpoint contracts.
