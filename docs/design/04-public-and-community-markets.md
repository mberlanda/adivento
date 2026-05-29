# 04 · Public & Community-Restricted Markets

Adds a **visibility / access** dimension to markets, grounded in `PRIVATE_PREDICTION_MARKETS.md` (Identity & Access §2.1, Market-level security §8.3). Wireframes: `extra/x-scope`, `extra/x-community`, `extra/x-visibility`.

## Visibility model

| Visibility | Who can view & bet | Listed in global index |
|------------|--------------------|------------------------|
| 🌐 **Public** | anyone on Adivento | yes |
| 👥 **Community** | members of a chosen group | only inside that community |
| 🔒 **Invite-only** | people invited to that single market | no (hidden) |

Backed by `markets.group_id` (null = public) + RBAC. Visibility is **locked once the market opens**; membership is enforced at **bet time**, not just view time.

## Groups, memberships, invites (from the spec)
```
Group        (id, name, slug, created_by)
Membership   (group_id, user_id, role, status)   role ∈ Owner·Admin·Resolver·Member·Read-only
Invite       (group_id, email, token_hash, status, expires_at)
```
Permission matrix (per group) — invite/create/open/resolve/adjust scoped by role (spec §8.2).

## Screens
1. **Browse with scope** (`extra/x-scope`) — `All · 🌐 Public · 👥 My communities` toggle + community picker. Non-member community/invite cards render **locked** with a "Request invite" affordance; details hidden.
2. **Community hub** (`extra/x-community`) — group header (name, private badge, member count, your role), Invite/Create actions, market list filtered to the group, member list with roles, pending invites, community leaderboard.
3. **Create · visibility & access** (`extra/x-visibility`) — three-way selector (Public / Community+picker / Invite-only) with a lock warning; embeds in both customer "Create market" and the backoffice create form.

## Security rules to enforce (spec §8.3)
- Only members of a group can view that group's markets.
- Users cannot bet after close or in resolved/cancelled markets.
- Community markets check membership at order placement.
- Market creator cannot resolve their own market (configurable).
- Every invite/join/role change writes an audit event.

## Acceptance criteria
- [ ] Markets gain a visibility field (`public | community | invite_only`) + optional `group_id`.
- [ ] Global index hides non-public markets the viewer can't access; community markets appear only in-context.
- [ ] Scope filter on `/web` and the community hub at `/web/communities/:slug`.
- [ ] Create flow exposes the visibility selector; choice locks on open.
- [ ] Membership enforced at bet time with a clear "request invite" path for non-members.
