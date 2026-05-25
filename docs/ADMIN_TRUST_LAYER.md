Below is an implementation-oriented spec for the **admin and trust layer** of a private prediction market platform using invite-only users, binary markets, private points/play money, manual/admin resolution, and auditable operations.

---

# Admin and Trust Layer Specification

## 0. Design principles

The admin layer must optimize for:

1. **Integrity**: admins should not be able to silently manipulate markets, balances, or outcomes.
2. **Auditability**: every privileged action must leave a durable audit trail.
3. **Separation of duties**: the person creating a market should not always be able to resolve it unilaterally.
4. **User trust**: market rules, edits, evidence, and disputes should be visible where appropriate.
5. **Operational simplicity**: v1 can be manual, but must not create untraceable manual workflows.
6. **Reversibility where possible**: bad actions should be correctable through explicit adjustments, not database edits.

---

# 1. Admin roles and permissions

## 1.1 Role model

Use role-based access control with explicit permissions.

Recommended v1 roles:

| Role             | Purpose                                                |
| ---------------- | ------------------------------------------------------ |
| `OWNER`          | Full control over the private group/platform instance  |
| `ADMIN`          | Operational admin; can manage users, markets, disputes |
| `MARKET_MANAGER` | Can create, edit, close, and prepare markets           |
| `RESOLVER`       | Can resolve markets and attach evidence                |
| `MODERATOR`      | Can handle abuse reports and suspend users             |
| `AUDITOR`        | Read-only access to admin data and audit logs          |
| `USER`           | Normal participant                                     |

Avoid hardcoding role checks directly into business logic. Use permission checks.

## 1.2 Permission catalog

Core permissions:

```text
admin.users.read
admin.users.suspend
admin.users.unsuspend
admin.users.adjust_balance

admin.markets.create
admin.markets.read
admin.markets.edit_draft
admin.markets.edit_live_metadata
admin.markets.close
admin.markets.cancel
admin.markets.reopen

admin.resolution.propose
admin.resolution.approve
admin.resolution.reject
admin.resolution.execute

admin.disputes.read
admin.disputes.respond
admin.disputes.resolve
admin.disputes.escalate

admin.evidence.attach
admin.evidence.remove
admin.evidence.mark_primary

admin.adjustments.create
admin.adjustments.approve
admin.adjustments.execute

admin.audit.read

admin.settings.manage
```

## 1.3 Recommended role-permission mapping

| Permission                | Owner | Admin | Market Manager | Resolver | Moderator |   Auditor |
| ------------------------- | ----: | ----: | -------------: | -------: | --------: | --------: |
| Create market             |   Yes |   Yes |            Yes |       No |        No |        No |
| Edit draft market         |   Yes |   Yes |            Yes |       No |        No |        No |
| Edit live market metadata |   Yes |   Yes |        Limited |       No |        No |        No |
| Close market              |   Yes |   Yes |            Yes |       No |        No |        No |
| Cancel market             |   Yes |   Yes |             No |       No |        No |        No |
| Propose resolution        |   Yes |   Yes |             No |      Yes |        No |        No |
| Approve resolution        |   Yes |   Yes |             No |      Yes |        No |        No |
| Execute settlement        |   Yes |   Yes |             No |  Limited |        No |        No |
| Handle disputes           |   Yes |   Yes |             No |  Limited |       Yes | Read-only |
| Suspend users             |   Yes |   Yes |             No |       No |       Yes |        No |
| Manual adjustments        |   Yes |   Yes |             No |       No |        No |        No |
| Read audit log            |   Yes |   Yes |             No |       No |        No |       Yes |

## 1.4 Separation-of-duties rules

Recommended:

```text
A market creator cannot be the sole resolver of that market once bets exist.

A resolution proposal should require either:
- one admin if no bets were placed;
- one resolver plus one admin approval if bets exist;
- two distinct admins/resolvers for high-impact markets.

A manual balance adjustment above a configured threshold requires approval by a second admin.

An admin cannot approve their own manual adjustment.

An admin cannot resolve their own dispute if they are a participant in the disputed market.
```

For friends-and-family MVP, you may start with “single admin can do everything,” but the data model should support approvals from day one.

---

# 2. Market creation flow

## 2.1 Market states relevant to admin flow

```text
DRAFT
PENDING_REVIEW
SCHEDULED
OPEN
CLOSED
RESOLUTION_PENDING
RESOLVED
SETTLED
CANCELLED
VOIDED
```

## 2.2 Creation flow

### Step 1: Create draft

Admin enters:

```text
title
description
market_type
outcomes
close_time
resolution_time
resolution_rule
source_of_truth
visibility
tags
group_id
liquidity/mechanism config
limits
```

For binary v1:

```text
outcomes:
  - YES
  - NO
```

Example market:

```text
Title:
Will Team A beat Team B on 2026-06-05?

Resolution rule:
Resolve YES if Team A is officially recorded as winner after regulation and extra time. Penalty shootout counts. If the match is abandoned and not completed within 72 hours, market is void.

Source of truth:
Official league match report.
```

### Step 2: Validation

System validates:

```text
title is non-empty
description is non-empty
exactly two outcomes for binary markets
close_time is before or equal to event start
resolution rule is present
source of truth is present
market category is allowed
market does not violate house rules
```

### Step 3: Review

For v1, review can be optional.

Possible modes:

```text
self_publish_allowed = true
requires_review = false
```

Later:

```text
requires_review = true for politics, finance, personal events, or high-limit markets
```

### Step 4: Publish

Publishing transitions:

```text
DRAFT -> SCHEDULED if open_time is in the future
DRAFT -> OPEN if open_time <= now and close_time > now
```

### Step 5: Notify users

Optional event:

```text
MarketPublished
```

Used for feed updates, notifications, and audit.

---

# 3. Market editing restrictions

Editing rules are critical for trust.

## 3.1 Editable fields by state

| Field                  | Draft | Scheduled | Open, no bets | Open, with bets |     Closed | Resolved |
| ---------------------- | ----: | --------: | ------------: | --------------: | ---------: | -------: |
| Title                  |   Yes |       Yes |           Yes |         Limited |         No |       No |
| Description            |   Yes |       Yes |           Yes |         Limited |         No |       No |
| Resolution rule        |   Yes |       Yes |           Yes |      Restricted |         No |       No |
| Source of truth        |   Yes |       Yes |           Yes |      Restricted | Restricted |       No |
| Close time             |   Yes |       Yes |           Yes |      Restricted |         No |       No |
| Outcomes               |   Yes |   Limited |            No |              No |         No |       No |
| Market category        |   Yes |       Yes |           Yes |         Limited |         No |       No |
| Visibility             |   Yes |       Yes |           Yes |             Yes |        Yes |      Yes |
| Limits                 |   Yes |       Yes |           Yes | Yes, lower only |         No |       No |
| Price/liquidity config |   Yes |       Yes |    Restricted |              No |         No |       No |

## 3.2 Safe edits

Safe edits are cosmetic or clarifying:

```text
fix typo
improve description clarity
add supporting link
add evidence
change tags
change image
change visibility from public-within-group to hidden-from-feed
```

## 3.3 Dangerous edits

Dangerous edits require stronger controls:

```text
changing resolution rule
changing source of truth
changing close time after bets exist
changing outcome names
changing market mechanism
changing settlement behavior
```

## 3.4 Editing live markets with bets

Once a market has bets, edits should be append-only.

Instead of replacing the original terms, create a new market version.

```text
market_versions:
  v1 original
  v2 amended
```

Users should see:

```text
This market was edited after bets were placed.
Changed by: Admin Name
Changed at: timestamp
Reason: Clarified official source of truth
Diff: previous text -> new text
```

## 3.5 Rule for material changes

If a change materially affects existing bettors, use one of:

```text
1. Cancel and void market.
2. Close market immediately and settle under original rules.
3. Keep market open but require explicit approval by second admin.
4. Allow affected users to cancel positions during a grace period.
```

For v1, the simplest trust-preserving rule is:

```text
Material changes after bets exist are not allowed.
Create a new market instead.
```

---

# 4. Market closing

## 4.1 Closing types

```text
AUTO_CLOSE
ADMIN_CLOSE
EARLY_CLOSE
CANCEL
VOID
```

## 4.2 Normal close

Market closes automatically at `close_time`.

Transition:

```text
OPEN -> CLOSED
```

Effects:

```text
No new bets accepted.
Existing positions remain active.
Market waits for resolution.
```

## 4.3 Manual early close

Admins may close early when:

```text
event has started earlier than expected
market terms became stale
source of truth is unavailable
suspicious activity is detected
admin error requires freezing the market
```

Transition:

```text
OPEN -> CLOSED
```

Required admin input:

```text
reason
visibility of reason
whether users should be notified
```

## 4.4 Cancel vs void

Use distinct concepts.

### Cancel market

Cancel means the market is abandoned before valid settlement.

```text
OPEN/CLOSED -> CANCELLED
```

Typical impact:

```text
All unmatched/open bets cancelled.
All reserved points released.
All matched positions voided.
No winners or losers.
```

### Void market

Void means the event occurred or nearly occurred, but the resolution rule requires refunding.

```text
CLOSED/RESOLUTION_PENDING -> VOIDED
```

Typical impact:

```text
All stakes refunded.
Positions settled at neutral outcome.
Audit event recorded.
```

For v1, both may result in refunding users, but keep separate states for clarity.

---

# 5. Resolution workflow

## 5.1 Resolution outcomes

For binary markets:

```text
YES
NO
VOID
CANCELLED
```

Optional future outcomes:

```text
PARTIAL
PUSH
AMBIGUOUS
MULTI_OUTCOME
```

## 5.2 Workflow states

```text
CLOSED
RESOLUTION_PENDING
RESOLUTION_PROPOSED
RESOLUTION_APPROVED
RESOLVED
SETTLEMENT_RUNNING
SETTLED
DISPUTED
REOPENED_FOR_REVIEW
```

## 5.3 Resolution flow

### Step 1: Market becomes eligible

A market is eligible for resolution when:

```text
state = CLOSED
resolution_time <= now
```

or an admin manually marks it ready.

### Step 2: Admin proposes resolution

Resolver submits:

```text
outcome
summary
evidence attachments
source_of_truth_url
confidence
notes
```

Example:

```text
Outcome: YES
Summary: Official league report lists Team A as winner, 2-1.
Evidence: official match report URL, screenshot
```

Transition:

```text
CLOSED -> RESOLUTION_PROPOSED
```

### Step 3: Approval

Depending on policy:

```text
low-impact market: auto-approve
normal market: one admin approval
high-impact market: two approvals
```

Transition:

```text
RESOLUTION_PROPOSED -> RESOLUTION_APPROVED
```

### Step 4: Execute resolution

System records immutable result:

```text
market_result.outcome = YES
resolved_at
resolved_by
resolution_version
```

Transition:

```text
RESOLUTION_APPROVED -> RESOLVED
```

### Step 5: Settlement

Settlement system pays out positions.

Transition:

```text
RESOLVED -> SETTLEMENT_RUNNING -> SETTLED
```

## 5.4 Dispute window

After resolution, allow a configured dispute window.

Example:

```text
dispute_window_minutes = 60
```

Possible model:

```text
RESOLVED -> SETTLED after dispute window
```

or:

```text
Resolve immediately, settle immediately, but allow corrective adjustment if dispute succeeds.
```

For v1, safest approach:

```text
Resolve first.
Display pending result.
Wait dispute window.
Then settle.
```

For friends-and-family MVP, you can also settle immediately but keep manual correction capability.

---

# 6. Evidence and source-of-truth attachment

## 6.1 Evidence types

```text
URL
TEXT_NOTE
FILE_UPLOAD
IMAGE_UPLOAD
SCREENSHOT
ADMIN_STATEMENT
EXTERNAL_API_RESULT
```

## 6.2 Source of truth

Each market should have a declared source of truth before publication.

Examples:

```text
Official league website
Company earnings release
Election commission result
Specific public URL
Admin consensus
Manual observation by named admin
```

For personal/friends markets, source of truth may be informal, but it must be explicit:

```text
Source of truth:
The birthday host confirms whether Alex arrived before 8pm.
```

## 6.3 Evidence visibility

Evidence can be:

```text
PUBLIC_TO_GROUP
ADMIN_ONLY
PARTICIPANTS_ONLY
PRIVATE_REDACTED
```

Default:

```text
Resolution evidence should be visible to all market participants unless it contains personal/private information.
```

## 6.4 Evidence immutability

Evidence records should be append-only.

Do not delete evidence physically. Instead:

```text
status = ACTIVE
status = RETRACTED
status = SUPERSEDED
```

Fields:

```text
retracted_by
retracted_at
retraction_reason
```

## 6.5 Required evidence on resolution

A resolution proposal should require at least one of:

```text
source_of_truth_url
evidence attachment
admin explanation
```

For sensitive personal events, use admin explanation rather than uploading private material.

---

# 7. Dispute workflow

## 7.1 Who can dispute?

Allowed disputers:

```text
participants with exposure in the market
admins
auditors
optionally any group member
```

Recommended v1:

```text
Only participants and admins can dispute.
```

## 7.2 Dispute reasons

```text
INCORRECT_OUTCOME
AMBIGUOUS_RULE
BAD_SOURCE
EVENT_CANCELLED
MARKET_TERMS_CHANGED_UNFAIRLY
ADMIN_ERROR
SUSPICIOUS_ACTIVITY
OTHER
```

## 7.3 Dispute states

```text
OPEN
UNDER_REVIEW
AWAITING_EVIDENCE
ACCEPTED
REJECTED
ESCALATED
CLOSED
```

## 7.4 Dispute flow

### Step 1: User opens dispute

Required:

```text
market_id
reason
description
optional evidence
```

Transition:

```text
OPEN
```

### Step 2: Admin review

Admin can:

```text
request more evidence
reject dispute
accept dispute
escalate to owner
reopen market resolution
```

Transition:

```text
OPEN -> UNDER_REVIEW
```

### Step 3: Decision

Outcomes:

```text
REJECTED: original result stands
ACCEPTED_CORRECT_OUTCOME: result changes
ACCEPTED_VOID: market voided
ACCEPTED_MANUAL_ADJUSTMENT: targeted correction
ESCALATED: requires owner decision
```

### Step 4: Correction

Possible corrections:

```text
update resolution before settlement
reverse settlement and re-settle
issue manual adjustment
void market and refund
```

In v1, avoid complex settlement reversal unless ledger supports it cleanly.

Recommended:

```text
All settlement transactions must be reversible by explicit compensating ledger entries.
```

Do not mutate existing ledger entries.

## 7.5 Dispute SLA

For private MVP:

```text
Admin should resolve disputes within 24-72 hours.
```

System can show:

```text
Dispute opened
Under review
Decision made
Final outcome
```

## 7.6 Dispute visibility

Participants should see:

```text
dispute opened
reason category
admin decision
summary
effect on settlement
```

Admins see full details.

---

# 8. Manual adjustments

Manual adjustments are powerful and dangerous.

## 8.1 Adjustment types

```text
BALANCE_CREDIT
BALANCE_DEBIT
RESERVATION_RELEASE
SETTLEMENT_CORRECTION
GOODWILL_CREDIT
PENALTY_DEBIT
VOID_REFUND
ADMIN_ERROR_CORRECTION
```

## 8.2 Principles

Manual adjustments must:

```text
never modify balances directly
always create ledger entries
always require reason
always reference an actor
optionally reference a market, bet, dispute, or incident
be visible in audit logs
```

## 8.3 Approval rules

Suggested thresholds:

```text
small adjustment: one admin
large adjustment: two admins
debit user balance: two admins
admin adjusting own balance: forbidden
```

For v1 private points, thresholds can be simple:

```text
Any manual debit requires OWNER approval.
Any adjustment above 1,000 points requires second approval.
```

## 8.4 Adjustment lifecycle

```text
DRAFT
PENDING_APPROVAL
APPROVED
EXECUTED
REJECTED
CANCELLED
```

## 8.5 Adjustment fields

```json
{
  "id": "adj_123",
  "user_id": "usr_123",
  "type": "GOODWILL_CREDIT",
  "amount": 100,
  "currency": "POINTS",
  "reason": "Compensation for incorrectly voided market",
  "reference_type": "DISPUTE",
  "reference_id": "disp_123",
  "status": "PENDING_APPROVAL",
  "created_by": "admin_1",
  "approved_by": null,
  "executed_at": null
}
```

---

# 9. User suspension

## 9.1 Suspension types

```text
LOGIN_SUSPENSION
BETTING_SUSPENSION
MARKET_CREATION_SUSPENSION
COMMENTING_SUSPENSION
WITHDRAWAL_SUSPENSION
FULL_ACCOUNT_SUSPENSION
```

For private points MVP:

```text
BETTING_SUSPENSION
LOGIN_SUSPENSION
FULL_ACCOUNT_SUSPENSION
```

## 9.2 Suspension reasons

```text
ABUSE
MULTI_ACCOUNTING
COLLUSION
MARKET_MANIPULATION
HARASSMENT
UNDERAGE_USER
INVITE_ABUSE
TERMS_VIOLATION
ADMIN_INVESTIGATION
OTHER
```

## 9.3 Effects

### Betting suspension

```text
User can log in.
User can view markets.
User cannot place new bets.
Existing bets remain unless admin cancels separately.
```

### Login suspension

```text
User cannot access the app.
Existing positions remain.
User still appears in settlement.
```

### Full account suspension

```text
User cannot log in.
User cannot place bets.
User cannot receive new invites.
Admins must decide what to do with open positions.
```

## 9.4 Suspension lifecycle

```text
ACTIVE
EXPIRED
REVOKED
REPLACED
```

Fields:

```text
starts_at
ends_at nullable
reason
internal_notes
user_visible_reason
created_by
revoked_by
revoked_reason
```

## 9.5 Open positions of suspended users

Default rule:

```text
Suspension does not cancel existing valid positions.
```

Admin options:

```text
leave positions active
cancel unmatched orders
freeze open bets
void positions only if abuse is proven
```

Any punitive balance action should go through manual adjustment workflow.

---

# 10. Audit log

## 10.1 Audit principles

The audit log should be:

```text
append-only
queryable
immutable at application level
linked to actor, action, target, and before/after state
safe to expose partially to users
retained indefinitely for v1
```

Do not rely only on application logs. Store business audit events in the database.

## 10.2 Events to audit

Audit all privileged actions:

```text
ADMIN_LOGIN
ROLE_GRANTED
ROLE_REVOKED

MARKET_CREATED
MARKET_EDITED
MARKET_PUBLISHED
MARKET_CLOSED
MARKET_CANCELLED
MARKET_VOIDED
MARKET_REOPENED

EVIDENCE_ATTACHED
EVIDENCE_RETRACTED

RESOLUTION_PROPOSED
RESOLUTION_APPROVED
RESOLUTION_REJECTED
MARKET_RESOLVED
SETTLEMENT_STARTED
SETTLEMENT_COMPLETED
SETTLEMENT_FAILED

DISPUTE_OPENED
DISPUTE_UPDATED
DISPUTE_RESOLVED
DISPUTE_ESCALATED

USER_SUSPENDED
USER_UNSUSPENDED

ADJUSTMENT_CREATED
ADJUSTMENT_APPROVED
ADJUSTMENT_EXECUTED
ADJUSTMENT_REJECTED

ADMIN_NOTE_CREATED
SETTINGS_CHANGED
```

## 10.3 Audit event schema

```sql
CREATE TABLE audit_events (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL,
    actor_user_id UUID,
    actor_role TEXT,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    reason TEXT,
    before_json JSONB,
    after_json JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}',
    ip_address TEXT,
    user_agent TEXT,
    request_id TEXT,
    idempotency_key TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 10.4 User-visible changelog

For markets, expose a simplified audit log:

```text
Market created
Market published
Market edited
Market closed
Resolution proposed
Resolution finalized
Dispute opened
Dispute resolved
```

Hide:

```text
internal notes
IP addresses
admin-only abuse signals
private user data
```

---

# 11. Admin dashboard

## 11.1 Dashboard sections

Recommended admin dashboard:

```text
Overview
Markets
Resolution Queue
Disputes
Users
Manual Adjustments
Audit Log
Abuse & Risk
Settings
```

## 11.2 Overview page

Show:

```text
open markets
markets closing soon
markets awaiting resolution
open disputes
pending manual adjustments
recent admin actions
suspended users
settlement failures
```

Useful cards:

```text
Markets needing attention
Disputes older than 24h
Failed settlements
High exposure markets
Recently edited live markets
```

## 11.3 Markets admin page

Capabilities:

```text
search markets
filter by state
filter by category
filter by creator
filter by close time
filter by unresolved
view exposure
view bet count
view participants
view audit trail
```

Market row:

```text
title
state
close_time
resolution_time
total_volume
admin flags
disputes_count
actions
```

Actions:

```text
Edit draft
Publish
Close
Cancel
Resolve
Attach evidence
View audit
```

## 11.4 Resolution queue

Filters:

```text
closed and awaiting resolution
resolution proposed
disputed
settlement failed
```

Each item shows:

```text
market title
close time
declared source of truth
current exposure
number of participants
suggested outcome if available
evidence status
action buttons
```

## 11.5 Disputes page

Shows:

```text
dispute id
market
opened by
reason
state
age
assigned admin
priority
```

Actions:

```text
assign
comment
request evidence
accept
reject
escalate
reopen resolution
```

## 11.6 Users page

Shows:

```text
name
email
role
status
points balance
reserved balance
joined_at
last_active_at
number of bets
flags
```

Actions:

```text
view profile
suspend
unsuspend
adjust balance
view user bets
view audit trail
```

## 11.7 Manual adjustments page

Shows:

```text
pending approvals
recent executed adjustments
failed adjustments
adjustments by admin
adjustments by user
```

Actions:

```text
create adjustment
approve
reject
execute
view ledger entries
```

## 11.8 Audit log page

Filters:

```text
actor
action
target type
target id
date range
market
user
request id
```

Display:

```text
timestamp
actor
action
target
reason
diff summary
request id
```

Allow exporting CSV/JSON for owners.

## 11.9 Abuse and risk dashboard

For v1, simple signals:

```text
users with many cancelled bets
markets with unusual activity
users repeatedly betting just before close
clusters of users always betting together
users disputing many losses
admins making frequent manual adjustments
```

This does not need ML in v1. Use rule-based flags.

---

# 12. Abuse cases

## 12.1 Admin abuse

### Case: Admin changes resolution rule after betting starts

Risk:

```text
Bettors are disadvantaged by retroactive rule change.
```

Controls:

```text
lock material fields after bets exist
require versioned edits
show user-visible changelog
require second approval for material edits
allow market cancellation instead of mutation
```

### Case: Admin resolves market incorrectly to favor friend

Controls:

```text
resolution evidence required
dispute window
second approval for high-impact markets
audit log
admin conflict-of-interest flag
```

### Case: Admin silently credits own account

Controls:

```text
manual adjustments require audit event
self-adjustment forbidden
second approval required
ledger reconciliation
owner-visible adjustment report
```

### Case: Admin deletes evidence

Controls:

```text
evidence is retracted, not deleted
audit every evidence change
retain original object storage file if possible
```

## 12.2 User abuse

### Case: Collusion between friends

Signals:

```text
same group of users repeatedly taking opposite sides
coordinated last-minute betting
accounts sharing invite chain
```

Controls:

```text
bet limits
market exposure limits
admin review
user suspension
private group trust rules
```

### Case: Market manipulation

For a simple private MVP, manipulation can mean users creating ambiguous markets or trying to influence real-life outcomes.

Controls:

```text
admin approval for user-created markets
clear resolution rules
market category restrictions
close before event starts
void markets with manipulated outcomes
```

### Case: Ambiguous personal event market

Example:

```text
Will Sam be late?
```

Problem:

```text
“Late” is undefined.
```

Controls:

```text
require objective resolution rule
require source of truth
reject vague markets
```

Better:

```text
Will Sam arrive at the restaurant after 20:15 local time according to the host?
```

### Case: Insider information

In friends-and-family markets, some users may know the answer.

Controls:

```text
allow markets marked “insider-prone”
lower limits
discourage serious stakes
avoid real money
admin cancellation for unfair setup
```

### Case: Harassment through markets

Example:

```text
Will Alex get fired?
Will Maria fail her exam?
```

Controls:

```text
market category rules
admin review
report market flow
personal event restrictions
moderation policy
```

Recommended v1 rule:

```text
No markets targeting private individuals in humiliating, invasive, or harmful ways.
```

### Case: Multi-accounting

Controls:

```text
invite-only accounts
one account per person rule
admin user review
suspicious invite chain detection
manual suspension
```

### Case: Dispute spam

Controls:

```text
only participants can dispute
one open dispute per user per market
admin can mark dispute as duplicate
repeat abuse warning/suspension
```

### Case: Admin error during settlement

Controls:

```text
idempotent settlement jobs
ledger entries are append-only
settlement can be retried safely
manual correction requires reference to incident/dispute
```

---

# 13. Data models

## 13.1 Admin role tables

```sql
CREATE TABLE roles (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(group_id, name)
);

CREATE TABLE permissions (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id),
    permission_id UUID NOT NULL REFERENCES permissions(id),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL,
    role_id UUID NOT NULL REFERENCES roles(id),
    granted_by UUID,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, role_id, granted_at)
);
```

## 13.2 Market tables

```sql
CREATE TABLE markets (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    market_type TEXT NOT NULL,
    state TEXT NOT NULL,
    category TEXT,
    visibility TEXT NOT NULL DEFAULT 'GROUP',
    open_time TIMESTAMPTZ,
    close_time TIMESTAMPTZ NOT NULL,
    resolution_time TIMESTAMPTZ,
    created_by UUID NOT NULL,
    published_by UUID,
    published_at TIMESTAMPTZ,
    closed_by UUID,
    closed_at TIMESTAMPTZ,
    cancelled_by UUID,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE market_outcomes (
    id UUID PRIMARY KEY,
    market_id UUID NOT NULL REFERENCES markets(id),
    code TEXT NOT NULL,
    label TEXT NOT NULL,
    sort_order INT NOT NULL,
    UNIQUE(market_id, code)
);

CREATE TABLE market_versions (
    id UUID PRIMARY KEY,
    market_id UUID NOT NULL REFERENCES markets(id),
    version_number INT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    resolution_rule TEXT NOT NULL,
    source_of_truth TEXT NOT NULL,
    close_time TIMESTAMPTZ NOT NULL,
    changed_by UUID NOT NULL,
    change_reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(market_id, version_number)
);
```

## 13.3 Resolution tables

```sql
CREATE TABLE market_resolutions (
    id UUID PRIMARY KEY,
    market_id UUID NOT NULL REFERENCES markets(id),
    proposed_outcome_code TEXT NOT NULL,
    summary TEXT NOT NULL,
    status TEXT NOT NULL,
    proposed_by UUID NOT NULL,
    proposed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    rejected_by UUID,
    rejected_at TIMESTAMPTZ,
    rejection_reason TEXT,
    executed_by UUID,
    executed_at TIMESTAMPTZ,
    resolution_version INT NOT NULL DEFAULT 1
);

CREATE TABLE market_results (
    market_id UUID PRIMARY KEY REFERENCES markets(id),
    outcome_code TEXT NOT NULL,
    resolution_id UUID NOT NULL REFERENCES market_resolutions(id),
    resolved_at TIMESTAMPTZ NOT NULL,
    resolved_by UUID NOT NULL,
    summary TEXT NOT NULL,
    final BOOLEAN NOT NULL DEFAULT false
);
```

## 13.4 Evidence tables

```sql
CREATE TABLE evidence (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL,
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    evidence_type TEXT NOT NULL,
    title TEXT,
    description TEXT,
    url TEXT,
    file_object_key TEXT,
    visibility TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    is_primary BOOLEAN NOT NULL DEFAULT false,
    attached_by UUID NOT NULL,
    attached_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    retracted_by UUID,
    retracted_at TIMESTAMPTZ,
    retraction_reason TEXT
);
```

## 13.5 Dispute tables

```sql
CREATE TABLE disputes (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL,
    market_id UUID NOT NULL REFERENCES markets(id),
    opened_by UUID NOT NULL,
    reason TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL,
    assigned_to UUID,
    decision TEXT,
    decision_summary TEXT,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dispute_comments (
    id UUID PRIMARY KEY,
    dispute_id UUID NOT NULL REFERENCES disputes(id),
    author_user_id UUID NOT NULL,
    body TEXT NOT NULL,
    visibility TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 13.6 Manual adjustment tables

```sql
CREATE TABLE manual_adjustments (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL,
    user_id UUID NOT NULL,
    type TEXT NOT NULL,
    amount NUMERIC(18, 4) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'POINTS',
    reason TEXT NOT NULL,
    reference_type TEXT,
    reference_id UUID,
    status TEXT NOT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    rejected_by UUID,
    rejected_at TIMESTAMPTZ,
    rejection_reason TEXT,
    executed_by UUID,
    executed_at TIMESTAMPTZ,
    ledger_transaction_id UUID
);
```

## 13.7 Suspension tables

```sql
CREATE TABLE user_suspensions (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL,
    user_id UUID NOT NULL,
    suspension_type TEXT NOT NULL,
    reason TEXT NOT NULL,
    user_visible_reason TEXT,
    internal_notes TEXT,
    status TEXT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at TIMESTAMPTZ,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_by UUID,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT
);
```

---

# 14. API endpoints

Assume REST-style API for v1.

Base path:

```text
/admin
```

All endpoints require authentication and admin permission checks.

---

## 14.1 Roles and permissions

```http
GET /admin/roles
POST /admin/roles
GET /admin/permissions
POST /admin/users/{userId}/roles
DELETE /admin/users/{userId}/roles/{roleId}
```

Example assign role:

```json
{
  "role": "MARKET_MANAGER",
  "reason": "Will manage football markets"
}
```

---

## 14.2 Market admin APIs

```http
GET /admin/markets
POST /admin/markets
GET /admin/markets/{marketId}
PATCH /admin/markets/{marketId}
POST /admin/markets/{marketId}/publish
POST /admin/markets/{marketId}/close
POST /admin/markets/{marketId}/cancel
POST /admin/markets/{marketId}/void
GET /admin/markets/{marketId}/versions
GET /admin/markets/{marketId}/audit
```

Create market:

```json
{
  "title": "Will Team A beat Team B on 2026-06-05?",
  "description": "Market resolves based on the official league result.",
  "market_type": "BINARY",
  "outcomes": [
    { "code": "YES", "label": "Yes" },
    { "code": "NO", "label": "No" }
  ],
  "category": "SPORTS",
  "open_time": "2026-06-01T12:00:00Z",
  "close_time": "2026-06-05T18:00:00Z",
  "resolution_time": "2026-06-05T22:00:00Z",
  "resolution_rule": "Resolve YES if Team A is officially recorded as winner.",
  "source_of_truth": "Official league match report",
  "visibility": "GROUP"
}
```

Close market:

```json
{
  "reason": "Event started earlier than expected",
  "notify_users": true
}
```

Cancel market:

```json
{
  "reason": "Market terms were ambiguous",
  "refund_policy": "REFUND_ALL",
  "notify_users": true
}
```

---

## 14.3 Resolution APIs

```http
GET /admin/resolution-queue
POST /admin/markets/{marketId}/resolutions
GET /admin/markets/{marketId}/resolutions
POST /admin/resolutions/{resolutionId}/approve
POST /admin/resolutions/{resolutionId}/reject
POST /admin/resolutions/{resolutionId}/execute
```

Propose resolution:

```json
{
  "outcome_code": "YES",
  "summary": "Official source shows Team A won 2-1.",
  "evidence_ids": ["ev_123"],
  "source_url": "https://official-source.example/result"
}
```

Approve resolution:

```json
{
  "reason": "Evidence matches market rule"
}
```

Reject resolution:

```json
{
  "reason": "Evidence source is not the declared source of truth"
}
```

---

## 14.4 Evidence APIs

```http
POST /admin/evidence
GET /admin/evidence/{evidenceId}
PATCH /admin/evidence/{evidenceId}
POST /admin/evidence/{evidenceId}/retract
POST /admin/evidence/{evidenceId}/mark-primary
```

Attach evidence:

```json
{
  "target_type": "MARKET_RESOLUTION",
  "target_id": "res_123",
  "evidence_type": "URL",
  "title": "Official match report",
  "description": "Final result from league website",
  "url": "https://official-source.example/result",
  "visibility": "PUBLIC_TO_GROUP"
}
```

Retract evidence:

```json
{
  "reason": "Wrong match report was attached"
}
```

---

## 14.5 Dispute APIs

User-facing:

```http
POST /markets/{marketId}/disputes
GET /markets/{marketId}/disputes
GET /disputes/{disputeId}
POST /disputes/{disputeId}/comments
```

Admin-facing:

```http
GET /admin/disputes
GET /admin/disputes/{disputeId}
POST /admin/disputes/{disputeId}/assign
POST /admin/disputes/{disputeId}/request-evidence
POST /admin/disputes/{disputeId}/accept
POST /admin/disputes/{disputeId}/reject
POST /admin/disputes/{disputeId}/escalate
POST /admin/disputes/{disputeId}/close
```

Open dispute:

```json
{
  "reason": "INCORRECT_OUTCOME",
  "description": "The official result says Team B won, not Team A.",
  "evidence_ids": ["ev_456"]
}
```

Reject dispute:

```json
{
  "decision_summary": "The attached evidence refers to a different event. Original resolution stands."
}
```

Accept dispute:

```json
{
  "decision": "ACCEPTED_CORRECT_OUTCOME",
  "decision_summary": "Official source confirms outcome should be NO.",
  "corrected_outcome_code": "NO"
}
```

---

## 14.6 Manual adjustment APIs

```http
GET /admin/adjustments
POST /admin/adjustments
GET /admin/adjustments/{adjustmentId}
POST /admin/adjustments/{adjustmentId}/approve
POST /admin/adjustments/{adjustmentId}/reject
POST /admin/adjustments/{adjustmentId}/execute
```

Create adjustment:

```json
{
  "user_id": "usr_123",
  "type": "GOODWILL_CREDIT",
  "amount": 100,
  "currency": "POINTS",
  "reason": "Compensation for admin error",
  "reference_type": "DISPUTE",
  "reference_id": "disp_123"
}
```

---

## 14.7 User suspension APIs

```http
GET /admin/users
GET /admin/users/{userId}
POST /admin/users/{userId}/suspensions
GET /admin/users/{userId}/suspensions
POST /admin/suspensions/{suspensionId}/revoke
```

Suspend user:

```json
{
  "suspension_type": "BETTING_SUSPENSION",
  "reason": "SUSPICIOUS_ACTIVITY",
  "user_visible_reason": "Your betting access is temporarily restricted while an admin reviews recent activity.",
  "internal_notes": "Repeated last-second bets on markets created by same user.",
  "ends_at": "2026-06-01T00:00:00Z"
}
```

Revoke suspension:

```json
{
  "reason": "Review completed; no abuse found"
}
```

---

## 14.8 Audit APIs

```http
GET /admin/audit-events
GET /admin/audit-events/{auditEventId}
GET /admin/markets/{marketId}/audit
GET /admin/users/{userId}/audit
```

Query params:

```text
actor_user_id
action
target_type
target_id
from
to
request_id
limit
cursor
```

---

# 15. UI requirements

## 15.1 General admin UI requirements

Every destructive or trust-sensitive admin action must require:

```text
confirmation modal
reason field
preview of impact
permission check
audit event
```

Examples of sensitive actions:

```text
close market early
cancel market
void market
resolve market
execute settlement
suspend user
manual balance adjustment
role assignment
```

## 15.2 Market editor UI

Must show:

```text
market state
number of bets
total exposure
whether fields are locked
edit history
resolution rule
source of truth
```

When editing a live market:

```text
Show warning: "This market already has bets. Material edits are restricted."
Show diff before submit.
Require reason.
```

## 15.3 Resolution UI

Must show:

```text
market terms
resolution rule
source of truth
current exposure
participants count
evidence panel
proposed outcome
settlement preview
dispute history
```

Settlement preview should include:

```text
number of winners
number of losers
total payout
total refund if voided
system liability
```

## 15.4 Dispute UI

User view:

```text
market title
current result
dispute status
user's submitted reason
admin decision summary
timeline
```

Admin view:

```text
all dispute details
market audit trail
evidence
comments
related users
decision actions
```

## 15.5 Manual adjustment UI

Must show before execution:

```text
current user balance
adjustment amount
new projected balance
reason
reference
approval status
ledger transaction preview
```

Require typed confirmation for debits:

```text
Type ADJUST to confirm.
```

## 15.6 Suspension UI

Must show:

```text
user profile
current roles
current suspensions
open positions
recent activity
reason
duration
scope
user-visible message
internal notes
```

Before suspension:

```text
Warn admin whether existing bets will remain active.
```

## 15.7 Audit UI

Must provide:

```text
timeline view
diff view
filtering
export
direct links to affected entity
```

For diffs:

```text
old value
new value
changed by
changed at
reason
```

---

# 16. Core service interfaces

## 16.1 Permission service

```ts
interface PermissionService {
  hasPermission(userId: string, groupId: string, permission: string): Promise<boolean>;

  requirePermission(
    userId: string,
    groupId: string,
    permission: string
  ): Promise<void>;
}
```

## 16.2 Audit service

```ts
interface AuditService {
  record(event: {
    groupId: string;
    actorUserId: string | null;
    actorRole?: string;
    action: string;
    targetType: string;
    targetId: string;
    reason?: string;
    before?: unknown;
    after?: unknown;
    metadata?: Record<string, unknown>;
    requestId?: string;
    idempotencyKey?: string;
    ipAddress?: string;
    userAgent?: string;
  }): Promise<void>;
}
```

## 16.3 Market admin service

```ts
interface MarketAdminService {
  createDraft(input: CreateMarketInput, actor: Actor): Promise<Market>;
  updateMarket(marketId: string, input: UpdateMarketInput, actor: Actor): Promise<Market>;
  publishMarket(marketId: string, actor: Actor): Promise<Market>;
  closeMarket(marketId: string, reason: string, actor: Actor): Promise<Market>;
  cancelMarket(marketId: string, reason: string, actor: Actor): Promise<Market>;
}
```

## 16.4 Resolution service

```ts
interface ResolutionService {
  proposeResolution(input: ProposeResolutionInput, actor: Actor): Promise<Resolution>;
  approveResolution(resolutionId: string, reason: string, actor: Actor): Promise<Resolution>;
  rejectResolution(resolutionId: string, reason: string, actor: Actor): Promise<Resolution>;
  executeResolution(resolutionId: string, actor: Actor): Promise<MarketResult>;
}
```

## 16.5 Dispute service

```ts
interface DisputeService {
  openDispute(input: OpenDisputeInput, actor: Actor): Promise<Dispute>;
  assignDispute(disputeId: string, assigneeId: string, actor: Actor): Promise<Dispute>;
  acceptDispute(disputeId: string, decision: DisputeDecision, actor: Actor): Promise<Dispute>;
  rejectDispute(disputeId: string, summary: string, actor: Actor): Promise<Dispute>;
}
```

---

# 17. Important invariants

These should be enforced in code and tested.

```text
A resolved market must have exactly one final result.

A settled market cannot be edited.

A market with bets cannot have outcomes changed.

A market with bets cannot have material rules changed without creating a new version and audit event.

A market cannot accept bets after close_time or after state != OPEN.

A resolution cannot be executed without required approval.

A dispute cannot directly mutate settlement without going through correction workflow.

Manual adjustments cannot directly update wallet balances.

Ledger entries are append-only.

Audit events are append-only.

A suspended user cannot place new bets if they have active betting suspension.

An admin cannot approve their own manual adjustment.

An admin cannot approve their own resolution when separation-of-duties is enabled.

Evidence cannot be physically deleted through normal admin APIs.
```

---

# 18. Recommended v1 policy defaults

For a private friends-and-family MVP:

```yaml
market_creation:
  user_created_markets: false
  admin_created_markets: true
  review_required: false

market_editing:
  allow_draft_edits: true
  allow_live_cosmetic_edits: true
  allow_live_material_edits_after_bets: false

resolution:
  require_evidence: true
  require_second_approval: false
  dispute_window_minutes: 60
  settle_immediately: false

disputes:
  participants_only: true
  one_open_dispute_per_user_per_market: true

manual_adjustments:
  require_reason: true
  forbid_self_adjustment: true
  require_second_approval_for_debits: true

suspension:
  existing_positions_remain_active: true
  cancel_unmatched_orders_on_betting_suspension: true

audit:
  retain_forever: true
  expose_market_changelog_to_users: true
```

---

# 19. Implementation order

Recommended build sequence:

```text
1. Roles and permissions
2. Audit log
3. Admin market creation and editing
4. Market close/cancel/void
5. Evidence attachment
6. Resolution workflow
7. Settlement integration
8. Dispute workflow
9. Manual adjustments
10. User suspension
11. Admin dashboard
12. Abuse/risk signals
```

The most important pieces to implement early are:

```text
permission checks
audit log
market versioning
resolution evidence
manual adjustment ledger discipline
```

Those prevent the platform from becoming a manually edited black box.
