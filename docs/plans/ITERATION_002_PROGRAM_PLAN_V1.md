# Iteration 002 Program Plan (V1)

## Objective
Deliver the first full web experience on top of the Rails monolith with:
- customer-facing market exploration web surface
- admin backoffice with moderator/admin separation
- admin-defined RBAC + ad hoc grants
- reusable market templates
- SSE for market price/settlement updates
- modular boundaries ready for microservice extraction
- minimal dependencies and high test coverage

## Plan A - Admin Backoffice
### Scope
- Backoffice web namespace with dashboard and operational modules.
- Permission management UI for:
  - permission catalog
  - role-permission mapping
  - user-specific allow/deny grants
- Moderator/admin behavior divergence enforced at policy layer.

### Deliverables
- Backoffice IA and page map.
- Permission management CRUD.
- Audit trail on all permission and grant changes.
- Feature tests for role and grant overrides.

## Plan B - Customer Web Experience
### Scope
- Public guest landing + market browsing pages.
- Authenticated customer market detail, wallet summary, and activity feed section.
- Responsive layout inspired by Kalshi/Polymarket IA patterns.

### Deliverables
- Home, markets index, market detail, live feed pages.
- Reusable view components for market cards and trust panels.
- Integration tests for guest vs authenticated visibility.

## Plan C - Reusable Market Models
### Scope
- Market templates as first-class domain objects.
- Template parameters and defaults for recurring market types.
- Backoffice flow: create market from template.

### Deliverables
- Template model + schema.
- Template backoffice pages.
- Service object for market instantiation.

## Plan D - SSE Stream Layer
### Scope
- SSE endpoint for market updates.
- SSE endpoint for settlement updates.
- Last-Event-ID resume behavior and event IDs.

### Deliverables
- Event envelope format.
- Controller/service that emits standardized SSE events.
- Integration tests for event stream semantics and payload format.

## Plan E - Modular Monolith Extraction Seams
### Scope
- Domain folders and service interfaces per context.
- Internal event contracts and outbox-ready event types.
- No cross-context write-path coupling.

### Deliverables
- Bounded context map.
- Event contract catalog.
- Extraction roadmap doc updates.

## Dependency Policy (V1)
- Keep current stack: Rails, PostgreSQL, JWT.
- Avoid adding SPA frameworks.
- Use server-rendered HTML + progressive enhancement.

## Sequence (V1)
1. Implement permissions/grants core.
2. Build backoffice web pages.
3. Build customer web pages.
4. Add template management and market generation.
5. Add SSE streams.
6. Add extraction seam refactors.
7. Run full tests and coverage gate.
