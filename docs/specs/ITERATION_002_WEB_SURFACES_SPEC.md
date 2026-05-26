<!-- LEGACY FORMAT — audit artifact only. Do NOT imitate this style.
   Current templates: docs/templates/{adr,spec,plan,plan-review}.md
   For implementation: read docs/INDEX.md first. -->

# Iteration 002 Web Surfaces Spec

## 1. Product Surfaces
### 1.1 Customer Surface
- Audience: guest and player users.
- Core capabilities:
  - discover markets
  - inspect market details and status
  - observe live update stream

### 1.2 Backoffice Surface
- Audience: moderator and admin staff.
- Core capabilities:
  - permission governance
  - grant overrides
  - template management
  - market operations and settlement controls

## 2. Authorization
### 2.1 Inputs
- user role (`admin`, `moderator`, `player`)
- role-permission records
- user grant records (`allow`, `deny`)

### 2.2 Resolution Rule
- deny grant overrides allow grant.
- allow grant overrides role permission.
- role permission overrides implicit deny.

### 2.3 Required Permission Keys
- `backoffice.access`
- `permission.manage`
- `grant.manage`
- `market.create`
- `market.update`
- `market.leg.create`
- `market.settle`
- `template.manage`
- `wallet.faucet.review`

## 3. Customer Pages
1. `/` -> market explorer home
2. `/web/markets` -> browse with status/category filters
3. `/web/markets/:id` -> market detail with trust panel

## 4. Backoffice Pages
1. `/backoffice` -> ops dashboard
2. `/backoffice/permissions` -> role-permission matrix
3. `/backoffice/grants` -> user-level ad hoc grants
4. `/backoffice/templates` -> template catalog and creation

## 5. Reusable Market Templates
### 5.1 Template Fields
- key
- name
- description
- default_legs (array)
- default_duration_hours
- active

### 5.2 Creation Flow
- moderator/admin selects template
- parameter inputs (minimal in slice 1)
- service instantiates market + legs
- audit event emitted

## 6. SSE Contracts
### 6.1 Endpoint
- `GET /sse/markets/:id`

### 6.2 Event Types
- `market.snapshot.v1`
- `market.status_changed.v1`
- `market.settlement_changed.v1`

### 6.3 Envelope
- id: monotonic integer or timestamp sequence
- event: versioned event name
- data: JSON payload string

### 6.4 Resume
- accepts `Last-Event-ID` header
- returns latest snapshot and updates after cursor where available

## 7. Audit Requirements
- permission or grant mutations must include actor and reason.
- template and settlement actions must be audited.

## 8. Test Requirements
- unit tests for policy resolution precedence.
- request/integration tests for customer/backoffice access control.
- tests for template instantiation.
- tests for SSE content type and event format.
- maintain global coverage >= 90%.
