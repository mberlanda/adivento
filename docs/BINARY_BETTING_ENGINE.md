Below is an implementation-ready v1 betting engine for **private-points binary YES/NO markets**.

The simplest viable mechanism I recommend is:

> **Fixed-odds binary betting with admin-set prices, no order book, no matching, and manual resolution.**

Users do not trade with each other directly. They place bets against a platform-backed pool using private points. Every accepted bet snapshots the odds at placement time. This is much simpler than a central limit order book, LMSR, or dynamic share market.

---

# 0. Recommended v1 mechanism

## Mechanism

Each market has two outcomes:

```text
YES
NO
```

Each side has an admin-configured decimal odds value:

```text
YES odds = 1.80
NO odds  = 2.10
```

A user stakes points on one side.

Example:

```text
User bets 100 points on YES at 1.80 odds.

If YES wins:
  gross payout = 100 * 1.80 = 180
  net profit   = 80

If YES loses:
  payout = 0
  user loses 100
```

The stake is moved from the user wallet into market escrow immediately.

At resolution, winning bets are paid out from escrow plus any required house reserve.

---

# 1. Domain model

## Core concepts

```text
User
Wallet
Market
Outcome
Bet
Position
MarketExposure
LedgerTransaction
LedgerEntry
IdempotencyKey
AuditLog
```

---

## User

Represents a participant.

```ts
type User = {
  id: UUID
  email: string
  displayName: string
  status: "ACTIVE" | "SUSPENDED" | "DELETED"
  createdAt: Instant
}
```

---

## Wallet

Each user has a points wallet.

```ts
type Wallet = {
  id: UUID
  userId: UUID
  currency: "POINTS"
  status: "ACTIVE" | "LOCKED"
}
```

Wallet balances should not be stored as mutable truth unless you also maintain a ledger. The ledger is the source of truth.

Useful derived balances:

```ts
type WalletBalance = {
  available: Decimal
  reserved: Decimal
  settled: Decimal
}
```

For v1:

```text
available = points user can spend
reserved  = points locked in open bets
settled   = historical net settled amount
```

---

## Market

```ts
type Market = {
  id: UUID
  title: string
  description: string | null

  type: "BINARY"

  status:
    | "DRAFT"
    | "OPEN"
    | "SUSPENDED"
    | "CLOSED"
    | "RESOLVING"
    | "RESOLVED"
    | "VOIDED"
    | "SETTLED"

  yesOdds: Decimal
  noOdds: Decimal

  minStake: Decimal
  maxStake: Decimal
  maxTotalStake: Decimal | null
  maxPlatformExposure: Decimal | null

  opensAt: Instant | null
  closesAt: Instant | null

  resolvedOutcome: "YES" | "NO" | "VOID" | null
  resolvedAt: Instant | null
  resolvedBy: UUID | null
  resolutionReason: string | null

  createdBy: UUID
  createdAt: Instant
  updatedAt: Instant

  version: number
}
```

---

## Outcome

For v1, outcomes can be implicit:

```text
YES
NO
```

A separate outcome table is optional. If you expect multi-outcome markets later, add it now. For binary-only v1, keeping outcomes as enums is simpler.

---

## Bet

```ts
type Bet = {
  id: UUID
  marketId: UUID
  userId: UUID

  side: "YES" | "NO"

  stake: Decimal
  odds: Decimal

  potentialPayout: Decimal
  potentialProfit: Decimal

  status:
    | "PENDING"
    | "ACCEPTED"
    | "CANCEL_REQUESTED"
    | "CANCELLED"
    | "VOIDED"
    | "LOST"
    | "WON"
    | "SETTLED"
    | "REJECTED"

  rejectionCode: string | null
  cancellationReason: string | null

  placedAt: Instant
  acceptedAt: Instant | null
  cancelledAt: Instant | null
  settledAt: Instant | null

  idempotencyKey: string

  createdAt: Instant
  updatedAt: Instant
}
```

---

## Position

A position is an aggregate view per user, market, and side.

You can either materialize it or calculate it from bets.

For v1, I would materialize it for speed but treat the ledger and bets as the source of truth.

```ts
type Position = {
  id: UUID
  userId: UUID
  marketId: UUID

  yesStake: Decimal
  noStake: Decimal

  yesPotentialPayout: Decimal
  noPotentialPayout: Decimal

  realizedPnl: Decimal
  unrealizedPnl: Decimal | null

  updatedAt: Instant
}
```

---

## Market exposure

Tracks platform liability.

```ts
type MarketExposure = {
  marketId: UUID

  totalYesStake: Decimal
  totalNoStake: Decimal

  totalYesPotentialPayout: Decimal
  totalNoPotentialPayout: Decimal

  totalStakeCollected: Decimal

  worstCasePayout: Decimal
  worstCasePlatformLoss: Decimal

  updatedAt: Instant
}
```

Where:

```text
worstCasePayout = max(totalYesPotentialPayout, totalNoPotentialPayout)

worstCasePlatformLoss =
  max(0, worstCasePayout - totalStakeCollected)
```

Example:

```text
YES bets:
  total stake = 100
  total payout = 180

NO bets:
  total stake = 50
  total payout = 105

totalStakeCollected = 150
worstCasePayout = max(180, 105) = 180
worstCasePlatformLoss = max(0, 180 - 150) = 30
```

The platform needs 30 extra points reserved from its house bankroll to guarantee settlement.

---

# 2. Bet lifecycle state machine

## States

```text
PENDING
ACCEPTED
CANCEL_REQUESTED
CANCELLED
VOIDED
WON
LOST
SETTLED
REJECTED
```

## Normal flow

```text
PENDING
  -> ACCEPTED
  -> WON
  -> SETTLED
```

or:

```text
PENDING
  -> ACCEPTED
  -> LOST
  -> SETTLED
```

## Rejection flow

```text
PENDING
  -> REJECTED
```

Reasons:

```text
MARKET_NOT_OPEN
MARKET_CLOSED
INSUFFICIENT_FUNDS
STAKE_TOO_LOW
STAKE_TOO_HIGH
EXPOSURE_LIMIT_EXCEEDED
INVALID_SIDE
DUPLICATE_IDEMPOTENCY_KEY
USER_SUSPENDED
WALLET_LOCKED
ODDS_CHANGED_OPTIONAL_REJECT
```

## Cancellation flow

```text
ACCEPTED
  -> CANCEL_REQUESTED
  -> CANCELLED
```

For v1, cancellation should be admin-only or allowed only while the market is still open and before a configured cutoff.

Recommended v1 rule:

```text
Users cannot cancel accepted bets.
Admins can void/cancel bets before settlement for operational reasons.
```

## Void flow

```text
ACCEPTED
  -> VOIDED
  -> SETTLED
```

Void means stake is returned.

---

# 3. Market lifecycle state machine

## States

```text
DRAFT
OPEN
SUSPENDED
CLOSED
RESOLVING
RESOLVED
VOIDED
SETTLED
```

## Flow

```text
DRAFT
  -> OPEN
  -> SUSPENDED
  -> OPEN
  -> CLOSED
  -> RESOLVING
  -> RESOLVED
  -> SETTLED
```

Alternative void flow:

```text
OPEN/CLOSED/SUSPENDED
  -> VOIDED
  -> SETTLED
```

## State meanings

### DRAFT

Market exists but cannot accept bets.

### OPEN

Market accepts bets.

### SUSPENDED

Market is temporarily paused. Existing bets remain active, but no new bets are accepted.

### CLOSED

No more bets accepted. Awaiting outcome.

### RESOLVING

Admin has started resolution. Used to prevent concurrent settlement operations.

### RESOLVED

Outcome has been recorded.

### VOIDED

Market is cancelled. All accepted bets should be refunded.

### SETTLED

All bets have been settled and ledger entries posted.

---

# 4. Placement algorithm

## Inputs

```ts
type PlaceBetRequest = {
  marketId: UUID
  side: "YES" | "NO"
  stake: Decimal
  idempotencyKey: string
}
```

## Output

```ts
type PlaceBetResponse = {
  betId: UUID
  status: "ACCEPTED"
  marketId: UUID
  side: "YES" | "NO"
  stake: Decimal
  odds: Decimal
  potentialPayout: Decimal
  potentialProfit: Decimal
  placedAt: Instant
}
```

## Algorithm

Inside a single database transaction:

```text
1. Validate idempotency key.
2. Lock user wallet.
3. Lock market row.
4. Lock market exposure row.
5. Validate user status.
6. Validate wallet status.
7. Validate market status is OPEN.
8. Validate current time is inside betting window.
9. Validate stake min/max.
10. Select odds snapshot for requested side.
11. Calculate potential payout.
12. Calculate incremental exposure.
13. Validate market exposure limits.
14. Validate user has enough available balance.
15. Create bet as ACCEPTED.
16. Move user stake from available to market escrow.
17. Reserve incremental house exposure if needed.
18. Update market exposure.
19. Update user position.
20. Store idempotency result.
21. Commit.
```

---

# 5. Price calculation

For v1, prices are admin-set decimal odds.

```text
YES odds = market.yesOdds
NO odds  = market.noOdds
```

On bet placement:

```text
odds = side == YES ? market.yesOdds : market.noOdds
```

Then:

```text
potentialPayout = stake * odds
potentialProfit = potentialPayout - stake
```

Use decimal arithmetic, not floating point.

Example:

```text
stake = 100
odds = 1.75

potentialPayout = 175
potentialProfit = 75
```

## Optional implied probability

For display:

```text
impliedProbability = 1 / odds
```

Example:

```text
odds = 2.00
impliedProbability = 50%
```

For a two-sided market, the admin can configure overround:

```text
yesImplied = 1 / yesOdds
noImplied  = 1 / noOdds
overround  = yesImplied + noImplied - 1
```

Example:

```text
YES odds = 1.80 => 55.56%
NO odds  = 1.90 => 52.63%

overround = 108.19% - 100% = 8.19%
```

This is optional for v1 but useful for admin tooling.

---

# 6. Exposure calculation

## Per bet

```text
stake = S
odds = O

potentialPayout = S * O
potentialProfit = potentialPayout - S
```

The user’s stake is already collected into escrow.

The incremental gross payout added to one outcome is:

```text
incrementalOutcomePayout = potentialPayout
```

The total collected stake increases by:

```text
incrementalStakeCollected = stake
```

## Per market

```text
totalYesPotentialPayout = sum(potentialPayout where side = YES and status = ACCEPTED)
totalNoPotentialPayout  = sum(potentialPayout where side = NO  and status = ACCEPTED)

totalStakeCollected = sum(stake where status = ACCEPTED)

worstCasePayout = max(totalYesPotentialPayout, totalNoPotentialPayout)

worstCasePlatformLoss = max(0, worstCasePayout - totalStakeCollected)
```

## Incremental exposure check

Before accepting a new bet, simulate the post-bet exposure.

```ts
function calculatePostBetExposure(
  exposure: MarketExposure,
  side: Side,
  stake: Decimal,
  potentialPayout: Decimal
): MarketExposure {
  const next = clone(exposure)

  if (side === "YES") {
    next.totalYesStake += stake
    next.totalYesPotentialPayout += potentialPayout
  } else {
    next.totalNoStake += stake
    next.totalNoPotentialPayout += potentialPayout
  }

  next.totalStakeCollected += stake
  next.worstCasePayout = max(
    next.totalYesPotentialPayout,
    next.totalNoPotentialPayout
  )

  next.worstCasePlatformLoss = max(
    0,
    next.worstCasePayout - next.totalStakeCollected
  )

  return next
}
```

Then:

```text
if next.worstCasePlatformLoss > market.maxPlatformExposure:
    reject bet
```

---

# 7. Concurrency and locking strategy

Use database transactions with row-level locks.

## Critical rows to lock during bet placement

```sql
SELECT * FROM markets WHERE id = :market_id FOR UPDATE;
SELECT * FROM market_exposures WHERE market_id = :market_id FOR UPDATE;
SELECT * FROM wallets WHERE user_id = :user_id FOR UPDATE;
```

If balances are materialized:

```sql
SELECT * FROM wallet_balances WHERE wallet_id = :wallet_id FOR UPDATE;
```

## Lock order

Always lock rows in the same order to avoid deadlocks:

```text
1. idempotency key
2. market
3. market exposure
4. user wallet
5. user balance
6. position
```

Alternatively, for wallet-heavy systems:

```text
1. idempotency key
2. user wallet
3. market
4. market exposure
5. position
```

Pick one and use it everywhere.

My recommendation for v1:

```text
idempotency -> market -> market_exposure -> wallet -> position
```

Because market status and exposure are the main contention points.

## Isolation level

Use:

```text
READ COMMITTED + SELECT FOR UPDATE
```

or:

```text
REPEATABLE READ
```

Do not rely on application-level checks without DB locks.

## Settlement locking

When resolving a market:

```sql
SELECT * FROM markets WHERE id = :market_id FOR UPDATE;
SELECT * FROM bets WHERE market_id = :market_id AND status = 'ACCEPTED' FOR UPDATE;
```

For large markets, settle in batches after moving the market to `RESOLVED`.

For v1 friends-and-family scale, single-transaction settlement is acceptable if the number of bets is small.

---

# 8. Idempotency model

Every mutating API request should accept an idempotency key.

## Idempotency key scope

Use:

```text
user_id + endpoint + idempotency_key
```

Example:

```text
user_123 + PLACE_BET + abc-123
```

## Idempotency table

```ts
type IdempotencyRecord = {
  id: UUID
  userId: UUID
  endpoint: string
  idempotencyKey: string

  requestHash: string
  responseStatusCode: number | null
  responseBody: JSON | null

  status: "IN_PROGRESS" | "COMPLETED" | "FAILED"

  createdAt: Instant
  updatedAt: Instant
  expiresAt: Instant
}
```

## Behavior

When a request arrives:

```text
1. Try to insert idempotency record with status IN_PROGRESS.
2. If insert succeeds, process request.
3. Store final response in idempotency record.
4. Return response.
```

If key already exists:

```text
1. Compare request hash.
2. If hash differs, return 409 IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST.
3. If status COMPLETED, return stored response.
4. If status IN_PROGRESS, return 409 REQUEST_ALREADY_IN_PROGRESS.
5. If status FAILED, either return stored error or allow retry depending on failure type.
```

Recommended v1 behavior:

```text
COMPLETED -> return original response
IN_PROGRESS -> 409
FAILED -> return original failure
```

---

# 9. Error cases

## Market errors

```text
MARKET_NOT_FOUND
MARKET_NOT_OPEN
MARKET_SUSPENDED
MARKET_CLOSED
MARKET_ALREADY_RESOLVED
MARKET_ALREADY_SETTLED
INVALID_MARKET_STATE_TRANSITION
INVALID_RESOLUTION_OUTCOME
```

## Bet errors

```text
BET_NOT_FOUND
BET_NOT_CANCELLABLE
BET_ALREADY_CANCELLED
BET_ALREADY_SETTLED
BET_ALREADY_VOIDED
INVALID_BET_SIDE
STAKE_TOO_LOW
STAKE_TOO_HIGH
```

## Wallet errors

```text
WALLET_NOT_FOUND
WALLET_LOCKED
INSUFFICIENT_FUNDS
BALANCE_INVARIANT_VIOLATION
```

## Exposure errors

```text
MARKET_EXPOSURE_LIMIT_EXCEEDED
HOUSE_BANKROLL_INSUFFICIENT
```

## Idempotency errors

```text
IDEMPOTENCY_KEY_REQUIRED
IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST
REQUEST_ALREADY_IN_PROGRESS
```

## Authorization errors

```text
UNAUTHENTICATED
FORBIDDEN
USER_SUSPENDED
ADMIN_REQUIRED
```

## Settlement errors

```text
NO_RESOLUTION_OUTCOME
SETTLEMENT_ALREADY_STARTED
SETTLEMENT_ALREADY_COMPLETED
LEDGER_POSTING_FAILED
PARTIAL_SETTLEMENT_DETECTED
```

---

# 10. API contract

## Create market

```http
POST /admin/markets
```

Request:

```json
{
  "title": "Will Team A win the final?",
  "description": "Market resolves YES if Team A wins in regulation or extra time.",
  "yesOdds": "1.80",
  "noOdds": "2.10",
  "minStake": "1.00",
  "maxStake": "1000.00",
  "maxTotalStake": "10000.00",
  "maxPlatformExposure": "2500.00",
  "opensAt": "2026-06-01T10:00:00Z",
  "closesAt": "2026-06-02T18:00:00Z"
}
```

Response:

```json
{
  "marketId": "uuid",
  "status": "DRAFT"
}
```

---

## Open market

```http
POST /admin/markets/{marketId}/open
```

Response:

```json
{
  "marketId": "uuid",
  "status": "OPEN"
}
```

---

## Place bet

```http
POST /markets/{marketId}/bets
Idempotency-Key: abc-123
```

Request:

```json
{
  "side": "YES",
  "stake": "100.00"
}
```

Response:

```json
{
  "betId": "uuid",
  "marketId": "uuid",
  "side": "YES",
  "stake": "100.00",
  "odds": "1.80",
  "potentialPayout": "180.00",
  "potentialProfit": "80.00",
  "status": "ACCEPTED",
  "placedAt": "2026-06-01T12:00:00Z"
}
```

---

## Cancel bet

For v1, admin-only.

```http
POST /admin/bets/{betId}/cancel
Idempotency-Key: cancel-123
```

Request:

```json
{
  "reason": "Operational correction"
}
```

Response:

```json
{
  "betId": "uuid",
  "status": "CANCELLED",
  "refundedStake": "100.00"
}
```

---

## Close market

```http
POST /admin/markets/{marketId}/close
```

Response:

```json
{
  "marketId": "uuid",
  "status": "CLOSED"
}
```

---

## Resolve market

```http
POST /admin/markets/{marketId}/resolve
Idempotency-Key: resolve-123
```

Request:

```json
{
  "outcome": "YES",
  "reason": "Official result confirmed."
}
```

Response:

```json
{
  "marketId": "uuid",
  "status": "RESOLVED",
  "resolvedOutcome": "YES"
}
```

---

## Settle market

```http
POST /admin/markets/{marketId}/settle
Idempotency-Key: settle-123
```

Response:

```json
{
  "marketId": "uuid",
  "status": "SETTLED",
  "settledBets": 42,
  "totalPaidOut": "3200.00",
  "totalRefunded": "0.00"
}
```

---

## Void market

```http
POST /admin/markets/{marketId}/void
Idempotency-Key: void-123
```

Request:

```json
{
  "reason": "Market rules were ambiguous."
}
```

Response:

```json
{
  "marketId": "uuid",
  "status": "VOIDED"
}
```

Then settlement refunds all accepted stakes.

---

# 11. Database tables

Assume PostgreSQL.

Use `NUMERIC(20, 6)` for points/odds values.

---

## users

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## wallets

```sql
CREATE TABLE wallets (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  currency TEXT NOT NULL CHECK (currency IN ('POINTS')),
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'LOCKED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (user_id, currency)
);
```

---

## accounts

Use double-entry accounts.

```sql
CREATE TABLE accounts (
  id UUID PRIMARY KEY,
  owner_type TEXT NOT NULL CHECK (
    owner_type IN ('USER', 'MARKET', 'HOUSE', 'SYSTEM')
  ),
  owner_id UUID NULL,

  account_type TEXT NOT NULL CHECK (
    account_type IN (
      'USER_AVAILABLE',
      'USER_RESERVED',
      'MARKET_ESCROW',
      'HOUSE_BANKROLL',
      'HOUSE_EXPOSURE_RESERVE',
      'SYSTEM_REVENUE',
      'SYSTEM_ADJUSTMENT'
    )
  ),

  currency TEXT NOT NULL CHECK (currency IN ('POINTS')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (owner_type, owner_id, account_type, currency)
);
```

---

## ledger_transactions

```sql
CREATE TABLE ledger_transactions (
  id UUID PRIMARY KEY,
  transaction_type TEXT NOT NULL CHECK (
    transaction_type IN (
      'POINTS_GRANT',
      'BET_PLACED',
      'BET_CANCELLED',
      'BET_VOIDED',
      'MARKET_RESOLVED',
      'BET_SETTLED_WIN',
      'BET_SETTLED_LOSS',
      'MARKET_VOID_SETTLEMENT',
      'HOUSE_EXPOSURE_RESERVED',
      'HOUSE_EXPOSURE_RELEASED',
      'ADMIN_ADJUSTMENT'
    )
  ),

  reference_type TEXT NULL,
  reference_id UUID NULL,

  idempotency_key TEXT NULL,

  created_by UUID NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## ledger_entries

Use signed amounts, or debit/credit columns. For simplicity:

```sql
CREATE TABLE ledger_entries (
  id UUID PRIMARY KEY,
  transaction_id UUID NOT NULL REFERENCES ledger_transactions(id),
  account_id UUID NOT NULL REFERENCES accounts(id),

  amount NUMERIC(20, 6) NOT NULL,
  currency TEXT NOT NULL CHECK (currency IN ('POINTS')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Invariant:

```sql
For every ledger_transaction:
  SUM(ledger_entries.amount) = 0
```

Example bet placement:

```text
Debit user available: -100
Credit market escrow: +100
```

Depending on sign convention, the names debit/credit are less important than the invariant that transaction entries sum to zero.

---

## markets

```sql
CREATE TABLE markets (
  id UUID PRIMARY KEY,

  title TEXT NOT NULL,
  description TEXT NULL,

  type TEXT NOT NULL CHECK (type IN ('BINARY')),

  status TEXT NOT NULL CHECK (
    status IN (
      'DRAFT',
      'OPEN',
      'SUSPENDED',
      'CLOSED',
      'RESOLVING',
      'RESOLVED',
      'VOIDED',
      'SETTLED'
    )
  ),

  yes_odds NUMERIC(20, 6) NOT NULL CHECK (yes_odds > 1),
  no_odds NUMERIC(20, 6) NOT NULL CHECK (no_odds > 1),

  min_stake NUMERIC(20, 6) NOT NULL CHECK (min_stake >= 0),
  max_stake NUMERIC(20, 6) NOT NULL CHECK (max_stake > 0),
  max_total_stake NUMERIC(20, 6) NULL,
  max_platform_exposure NUMERIC(20, 6) NULL,

  opens_at TIMESTAMPTZ NULL,
  closes_at TIMESTAMPTZ NULL,

  resolved_outcome TEXT NULL CHECK (
    resolved_outcome IN ('YES', 'NO', 'VOID')
  ),
  resolved_at TIMESTAMPTZ NULL,
  resolved_by UUID NULL REFERENCES users(id),
  resolution_reason TEXT NULL,

  created_by UUID NOT NULL REFERENCES users(id),

  version BIGINT NOT NULL DEFAULT 0,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## market_exposures

```sql
CREATE TABLE market_exposures (
  market_id UUID PRIMARY KEY REFERENCES markets(id),

  total_yes_stake NUMERIC(20, 6) NOT NULL DEFAULT 0,
  total_no_stake NUMERIC(20, 6) NOT NULL DEFAULT 0,

  total_yes_potential_payout NUMERIC(20, 6) NOT NULL DEFAULT 0,
  total_no_potential_payout NUMERIC(20, 6) NOT NULL DEFAULT 0,

  total_stake_collected NUMERIC(20, 6) NOT NULL DEFAULT 0,

  worst_case_payout NUMERIC(20, 6) NOT NULL DEFAULT 0,
  worst_case_platform_loss NUMERIC(20, 6) NOT NULL DEFAULT 0,

  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## bets

```sql
CREATE TABLE bets (
  id UUID PRIMARY KEY,

  market_id UUID NOT NULL REFERENCES markets(id),
  user_id UUID NOT NULL REFERENCES users(id),

  side TEXT NOT NULL CHECK (side IN ('YES', 'NO')),

  stake NUMERIC(20, 6) NOT NULL CHECK (stake > 0),
  odds NUMERIC(20, 6) NOT NULL CHECK (odds > 1),

  potential_payout NUMERIC(20, 6) NOT NULL CHECK (potential_payout >= 0),
  potential_profit NUMERIC(20, 6) NOT NULL CHECK (potential_profit >= 0),

  status TEXT NOT NULL CHECK (
    status IN (
      'PENDING',
      'ACCEPTED',
      'CANCEL_REQUESTED',
      'CANCELLED',
      'VOIDED',
      'LOST',
      'WON',
      'SETTLED',
      'REJECTED'
    )
  ),

  rejection_code TEXT NULL,
  cancellation_reason TEXT NULL,

  idempotency_key TEXT NOT NULL,

  placed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ NULL,
  cancelled_at TIMESTAMPTZ NULL,
  settled_at TIMESTAMPTZ NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (user_id, idempotency_key)
);

CREATE INDEX idx_bets_market_status ON bets(market_id, status);
CREATE INDEX idx_bets_user_market ON bets(user_id, market_id);
```

---

## positions

```sql
CREATE TABLE positions (
  id UUID PRIMARY KEY,

  user_id UUID NOT NULL REFERENCES users(id),
  market_id UUID NOT NULL REFERENCES markets(id),

  yes_stake NUMERIC(20, 6) NOT NULL DEFAULT 0,
  no_stake NUMERIC(20, 6) NOT NULL DEFAULT 0,

  yes_potential_payout NUMERIC(20, 6) NOT NULL DEFAULT 0,
  no_potential_payout NUMERIC(20, 6) NOT NULL DEFAULT 0,

  realized_pnl NUMERIC(20, 6) NOT NULL DEFAULT 0,

  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (user_id, market_id)
);
```

---

## idempotency_records

```sql
CREATE TABLE idempotency_records (
  id UUID PRIMARY KEY,

  user_id UUID NULL REFERENCES users(id),
  endpoint TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,

  request_hash TEXT NOT NULL,

  status TEXT NOT NULL CHECK (
    status IN ('IN_PROGRESS', 'COMPLETED', 'FAILED')
  ),

  response_status_code INT NULL,
  response_body JSONB NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,

  UNIQUE (user_id, endpoint, idempotency_key)
);
```

---

## audit_logs

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY,

  actor_user_id UUID NULL REFERENCES users(id),
  action TEXT NOT NULL,

  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,

  before_state JSONB NULL,
  after_state JSONB NULL,

  reason TEXT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

# 12. Pseudocode

The pseudocode below assumes a service layer plus repository methods using database transactions.

---

## 12.1 Create market

```ts
async function createMarket(adminUserId: UUID, request: CreateMarketRequest): Promise<Market> {
  requireAdmin(adminUserId)

  validate(request.title.length > 0)
  validate(request.yesOdds > 1)
  validate(request.noOdds > 1)
  validate(request.minStake >= 0)
  validate(request.maxStake > request.minStake)

  if (request.opensAt && request.closesAt) {
    validate(request.opensAt < request.closesAt)
  }

  return db.transaction(async tx => {
    const marketId = uuid()

    const market = await tx.markets.insert({
      id: marketId,
      title: request.title,
      description: request.description,
      type: "BINARY",
      status: "DRAFT",

      yesOdds: request.yesOdds,
      noOdds: request.noOdds,

      minStake: request.minStake,
      maxStake: request.maxStake,
      maxTotalStake: request.maxTotalStake,
      maxPlatformExposure: request.maxPlatformExposure,

      opensAt: request.opensAt,
      closesAt: request.closesAt,

      resolvedOutcome: null,
      createdBy: adminUserId
    })

    await tx.marketExposures.insert({
      marketId,
      totalYesStake: 0,
      totalNoStake: 0,
      totalYesPotentialPayout: 0,
      totalNoPotentialPayout: 0,
      totalStakeCollected: 0,
      worstCasePayout: 0,
      worstCasePlatformLoss: 0
    })

    await createAccount(tx, {
      ownerType: "MARKET",
      ownerId: marketId,
      accountType: "MARKET_ESCROW",
      currency: "POINTS"
    })

    await audit(tx, {
      actorUserId: adminUserId,
      action: "MARKET_CREATED",
      entityType: "MARKET",
      entityId: marketId,
      beforeState: null,
      afterState: market
    })

    return market
  })
}
```

---

## 12.2 Open market

```ts
async function openMarket(adminUserId: UUID, marketId: UUID): Promise<Market> {
  requireAdmin(adminUserId)

  return db.transaction(async tx => {
    const market = await tx.markets.findByIdForUpdate(marketId)

    if (!market) throw error("MARKET_NOT_FOUND")
    if (market.status !== "DRAFT" && market.status !== "SUSPENDED") {
      throw error("INVALID_MARKET_STATE_TRANSITION")
    }

    const updated = await tx.markets.update(marketId, {
      status: "OPEN",
      updatedAt: now(),
      version: market.version + 1
    })

    await audit(tx, {
      actorUserId: adminUserId,
      action: "MARKET_OPENED",
      entityType: "MARKET",
      entityId: marketId,
      beforeState: market,
      afterState: updated
    })

    return updated
  })
}
```

---

## 12.3 Place bet

```ts
async function placeBet(
  userId: UUID,
  marketId: UUID,
  request: PlaceBetRequest,
  idempotencyKey: string
): Promise<PlaceBetResponse> {
  requireIdempotencyKey(idempotencyKey)

  const requestHash = hashJson({
    userId,
    marketId,
    request
  })

  return withIdempotency(
    userId,
    "PLACE_BET",
    idempotencyKey,
    requestHash,
    async () => {
      return db.transaction(async tx => {
        const user = await tx.users.findById(userId)
        if (!user || user.status !== "ACTIVE") {
          throw error("USER_SUSPENDED")
        }

        const market = await tx.markets.findByIdForUpdate(marketId)
        if (!market) throw error("MARKET_NOT_FOUND")

        const exposure = await tx.marketExposures.findByMarketIdForUpdate(marketId)
        if (!exposure) throw error("MARKET_EXPOSURE_NOT_FOUND")

        const wallet = await tx.wallets.findByUserIdForUpdate(userId, "POINTS")
        if (!wallet) throw error("WALLET_NOT_FOUND")
        if (wallet.status !== "ACTIVE") throw error("WALLET_LOCKED")

        const nowTs = now()

        if (market.status !== "OPEN") {
          throw error("MARKET_NOT_OPEN")
        }

        if (market.opensAt && nowTs < market.opensAt) {
          throw error("MARKET_NOT_OPEN")
        }

        if (market.closesAt && nowTs >= market.closesAt) {
          throw error("MARKET_CLOSED")
        }

        if (request.side !== "YES" && request.side !== "NO") {
          throw error("INVALID_BET_SIDE")
        }

        const stake = decimal(request.stake)

        if (stake < market.minStake) {
          throw error("STAKE_TOO_LOW")
        }

        if (stake > market.maxStake) {
          throw error("STAKE_TOO_HIGH")
        }

        if (
          market.maxTotalStake !== null &&
          exposure.totalStakeCollected + stake > market.maxTotalStake
        ) {
          throw error("MARKET_TOTAL_STAKE_LIMIT_EXCEEDED")
        }

        const odds = request.side === "YES"
          ? market.yesOdds
          : market.noOdds

        const potentialPayout = stake * odds
        const potentialProfit = potentialPayout - stake

        const availableBalance = await calculateAvailableBalance(tx, wallet.id)

        if (availableBalance < stake) {
          throw error("INSUFFICIENT_FUNDS")
        }

        const nextExposure = calculatePostBetExposure(
          exposure,
          request.side,
          stake,
          potentialPayout
        )

        if (
          market.maxPlatformExposure !== null &&
          nextExposure.worstCasePlatformLoss > market.maxPlatformExposure
        ) {
          throw error("MARKET_EXPOSURE_LIMIT_EXCEEDED")
        }

        const currentHouseReserveNeeded = exposure.worstCasePlatformLoss
        const nextHouseReserveNeeded = nextExposure.worstCasePlatformLoss
        const additionalHouseReserveNeeded =
          max(0, nextHouseReserveNeeded - currentHouseReserveNeeded)

        if (additionalHouseReserveNeeded > 0) {
          const houseAvailable = await calculateHouseAvailableBalance(tx)

          if (houseAvailable < additionalHouseReserveNeeded) {
            throw error("HOUSE_BANKROLL_INSUFFICIENT")
          }
        }

        const betId = uuid()

        const bet = await tx.bets.insert({
          id: betId,
          marketId,
          userId,
          side: request.side,
          stake,
          odds,
          potentialPayout,
          potentialProfit,
          status: "ACCEPTED",
          idempotencyKey,
          placedAt: nowTs,
          acceptedAt: nowTs
        })

        const userAvailableAccount = await getAccount(tx, {
          ownerType: "USER",
          ownerId: userId,
          accountType: "USER_AVAILABLE",
          currency: "POINTS"
        })

        const marketEscrowAccount = await getAccount(tx, {
          ownerType: "MARKET",
          ownerId: marketId,
          accountType: "MARKET_ESCROW",
          currency: "POINTS"
        })

        await postLedgerTransaction(tx, {
          transactionType: "BET_PLACED",
          referenceType: "BET",
          referenceId: betId,
          idempotencyKey,
          createdBy: userId,
          entries: [
            {
              accountId: userAvailableAccount.id,
              amount: -stake,
              currency: "POINTS"
            },
            {
              accountId: marketEscrowAccount.id,
              amount: stake,
              currency: "POINTS"
            }
          ]
        })

        if (additionalHouseReserveNeeded > 0) {
          const houseBankrollAccount = await getHouseBankrollAccount(tx)
          const houseReserveAccount = await getHouseExposureReserveAccount(tx)

          await postLedgerTransaction(tx, {
            transactionType: "HOUSE_EXPOSURE_RESERVED",
            referenceType: "MARKET",
            referenceId: marketId,
            createdBy: userId,
            entries: [
              {
                accountId: houseBankrollAccount.id,
                amount: -additionalHouseReserveNeeded,
                currency: "POINTS"
              },
              {
                accountId: houseReserveAccount.id,
                amount: additionalHouseReserveNeeded,
                currency: "POINTS"
              }
            ]
          })
        }

        await tx.marketExposures.update(marketId, nextExposure)

        await upsertPositionForBet(tx, {
          userId,
          marketId,
          side: request.side,
          stake,
          potentialPayout
        })

        await audit(tx, {
          actorUserId: userId,
          action: "BET_PLACED",
          entityType: "BET",
          entityId: betId,
          beforeState: null,
          afterState: bet
        })

        return {
          betId,
          marketId,
          side: request.side,
          stake,
          odds,
          potentialPayout,
          potentialProfit,
          status: "ACCEPTED",
          placedAt: nowTs
        }
      })
    }
  )
}
```

---

## 12.4 Cancel bet if allowed

Recommended v1: admin-only cancellation before market settlement.

```ts
async function cancelBet(
  adminUserId: UUID,
  betId: UUID,
  reason: string,
  idempotencyKey: string
): Promise<CancelBetResponse> {
  requireAdmin(adminUserId)
  requireIdempotencyKey(idempotencyKey)

  const requestHash = hashJson({
    adminUserId,
    betId,
    reason
  })

  return withIdempotency(
    adminUserId,
    "CANCEL_BET",
    idempotencyKey,
    requestHash,
    async () => {
      return db.transaction(async tx => {
        const bet = await tx.bets.findByIdForUpdate(betId)
        if (!bet) throw error("BET_NOT_FOUND")

        if (bet.status !== "ACCEPTED") {
          throw error("BET_NOT_CANCELLABLE")
        }

        const market = await tx.markets.findByIdForUpdate(bet.marketId)
        if (!market) throw error("MARKET_NOT_FOUND")

        if (market.status === "SETTLED") {
          throw error("BET_ALREADY_SETTLED")
        }

        const exposure = await tx.marketExposures.findByMarketIdForUpdate(bet.marketId)

        const userAvailableAccount = await getAccount(tx, {
          ownerType: "USER",
          ownerId: bet.userId,
          accountType: "USER_AVAILABLE",
          currency: "POINTS"
        })

        const marketEscrowAccount = await getAccount(tx, {
          ownerType: "MARKET",
          ownerId: bet.marketId,
          accountType: "MARKET_ESCROW",
          currency: "POINTS"
        })

        await postLedgerTransaction(tx, {
          transactionType: "BET_CANCELLED",
          referenceType: "BET",
          referenceId: bet.id,
          idempotencyKey,
          createdBy: adminUserId,
          entries: [
            {
              accountId: marketEscrowAccount.id,
              amount: -bet.stake,
              currency: "POINTS"
            },
            {
              accountId: userAvailableAccount.id,
              amount: bet.stake,
              currency: "POINTS"
            }
          ]
        })

        const beforeExposure = exposure
        const afterExposure = removeBetFromExposure(exposure, bet)

        await tx.marketExposures.update(bet.marketId, afterExposure)

        await releaseExcessHouseReserveIfNeeded(tx, {
          marketId: bet.marketId,
          beforeWorstCaseLoss: beforeExposure.worstCasePlatformLoss,
          afterWorstCaseLoss: afterExposure.worstCasePlatformLoss,
          actorUserId: adminUserId
        })

        const updatedBet = await tx.bets.update(bet.id, {
          status: "CANCELLED",
          cancellationReason: reason,
          cancelledAt: now(),
          updatedAt: now()
        })

        await subtractPositionForBet(tx, bet)

        await audit(tx, {
          actorUserId: adminUserId,
          action: "BET_CANCELLED",
          entityType: "BET",
          entityId: bet.id,
          beforeState: bet,
          afterState: updatedBet,
          reason
        })

        return {
          betId: bet.id,
          status: "CANCELLED",
          refundedStake: bet.stake
        }
      })
    }
  )
}
```

---

## 12.5 Close market

```ts
async function closeMarket(adminUserId: UUID, marketId: UUID): Promise<Market> {
  requireAdmin(adminUserId)

  return db.transaction(async tx => {
    const market = await tx.markets.findByIdForUpdate(marketId)
    if (!market) throw error("MARKET_NOT_FOUND")

    if (market.status !== "OPEN" && market.status !== "SUSPENDED") {
      throw error("INVALID_MARKET_STATE_TRANSITION")
    }

    const updated = await tx.markets.update(marketId, {
      status: "CLOSED",
      updatedAt: now(),
      version: market.version + 1
    })

    await audit(tx, {
      actorUserId: adminUserId,
      action: "MARKET_CLOSED",
      entityType: "MARKET",
      entityId: marketId,
      beforeState: market,
      afterState: updated
    })

    return updated
  })
}
```

---

## 12.6 Resolve market

Resolution only records the outcome. Settlement can be a separate step.

```ts
async function resolveMarket(
  adminUserId: UUID,
  marketId: UUID,
  request: ResolveMarketRequest,
  idempotencyKey: string
): Promise<Market> {
  requireAdmin(adminUserId)
  requireIdempotencyKey(idempotencyKey)

  const requestHash = hashJson({
    adminUserId,
    marketId,
    request
  })

  return withIdempotency(
    adminUserId,
    "RESOLVE_MARKET",
    idempotencyKey,
    requestHash,
    async () => {
      return db.transaction(async tx => {
        const market = await tx.markets.findByIdForUpdate(marketId)
        if (!market) throw error("MARKET_NOT_FOUND")

        if (market.status !== "CLOSED" && market.status !== "SUSPENDED") {
          throw error("INVALID_MARKET_STATE_TRANSITION")
        }

        if (
          request.outcome !== "YES" &&
          request.outcome !== "NO" &&
          request.outcome !== "VOID"
        ) {
          throw error("INVALID_RESOLUTION_OUTCOME")
        }

        const before = market

        const resolving = await tx.markets.update(marketId, {
          status: "RESOLVING",
          updatedAt: now(),
          version: market.version + 1
        })

        const finalStatus = request.outcome === "VOID"
          ? "VOIDED"
          : "RESOLVED"

        const resolved = await tx.markets.update(marketId, {
          status: finalStatus,
          resolvedOutcome: request.outcome,
          resolvedAt: now(),
          resolvedBy: adminUserId,
          resolutionReason: request.reason,
          updatedAt: now(),
          version: resolving.version + 1
        })

        await audit(tx, {
          actorUserId: adminUserId,
          action: "MARKET_RESOLVED",
          entityType: "MARKET",
          entityId: marketId,
          beforeState: before,
          afterState: resolved,
          reason: request.reason
        })

        return resolved
      })
    }
  )
}
```

---

## 12.7 Settle positions

For v1, settle all bets in one transaction if the market is small.

```ts
async function settleMarket(
  adminUserId: UUID,
  marketId: UUID,
  idempotencyKey: string
): Promise<SettleMarketResponse> {
  requireAdmin(adminUserId)
  requireIdempotencyKey(idempotencyKey)

  const requestHash = hashJson({
    adminUserId,
    marketId
  })

  return withIdempotency(
    adminUserId,
    "SETTLE_MARKET",
    idempotencyKey,
    requestHash,
    async () => {
      return db.transaction(async tx => {
        const market = await tx.markets.findByIdForUpdate(marketId)
        if (!market) throw error("MARKET_NOT_FOUND")

        if (market.status !== "RESOLVED" && market.status !== "VOIDED") {
          throw error("INVALID_MARKET_STATE_TRANSITION")
        }

        if (!market.resolvedOutcome) {
          throw error("NO_RESOLUTION_OUTCOME")
        }

        const bets = await tx.bets.findByMarketIdAndStatusForUpdate(
          marketId,
          "ACCEPTED"
        )

        const marketEscrowAccount = await getAccount(tx, {
          ownerType: "MARKET",
          ownerId: marketId,
          accountType: "MARKET_ESCROW",
          currency: "POINTS"
        })

        const houseReserveAccount = await getHouseExposureReserveAccount(tx)
        const houseBankrollAccount = await getHouseBankrollAccount(tx)

        let settledBets = 0
        let totalPaidOut = decimal(0)
        let totalRefunded = decimal(0)

        for (const bet of bets) {
          const userAvailableAccount = await getAccount(tx, {
            ownerType: "USER",
            ownerId: bet.userId,
            accountType: "USER_AVAILABLE",
            currency: "POINTS"
          })

          if (market.resolvedOutcome === "VOID") {
            await postLedgerTransaction(tx, {
              transactionType: "MARKET_VOID_SETTLEMENT",
              referenceType: "BET",
              referenceId: bet.id,
              createdBy: adminUserId,
              entries: [
                {
                  accountId: marketEscrowAccount.id,
                  amount: -bet.stake,
                  currency: "POINTS"
                },
                {
                  accountId: userAvailableAccount.id,
                  amount: bet.stake,
                  currency: "POINTS"
                }
              ]
            })

            await tx.bets.update(bet.id, {
              status: "SETTLED",
              settledAt: now(),
              updatedAt: now()
            })

            totalRefunded += bet.stake
            settledBets += 1
            continue
          }

          const won = bet.side === market.resolvedOutcome

          if (won) {
            const payout = bet.potentialPayout

            /*
              Payout funding:

              The market escrow contains all user stakes.
              If winner payouts exceed escrow, the difference comes from house reserve.

              For simplicity, each winning payout can draw first from escrow,
              then from reserve. In production, calculate aggregate first.
            */

            await payUserFromMarketAndReserve(tx, {
              marketEscrowAccount,
              houseReserveAccount,
              userAvailableAccount,
              amount: payout,
              referenceBetId: bet.id,
              actorUserId: adminUserId
            })

            await tx.bets.update(bet.id, {
              status: "SETTLED",
              settledAt: now(),
              updatedAt: now()
            })

            await tx.bets.markIntermediateOutcomeIfNeeded(bet.id, "WON")

            await updatePositionRealizedPnl(tx, {
              userId: bet.userId,
              marketId: bet.marketId,
              realizedPnlDelta: bet.potentialProfit
            })

            totalPaidOut += payout
            settledBets += 1
          } else {
            /*
              Losing user already paid stake into escrow.
              Nothing is returned to them.
            */

            await postLedgerTransaction(tx, {
              transactionType: "BET_SETTLED_LOSS",
              referenceType: "BET",
              referenceId: bet.id,
              createdBy: adminUserId,
              entries: []
            })

            await tx.bets.update(bet.id, {
              status: "SETTLED",
              settledAt: now(),
              updatedAt: now()
            })

            await tx.bets.markIntermediateOutcomeIfNeeded(bet.id, "LOST")

            await updatePositionRealizedPnl(tx, {
              userId: bet.userId,
              marketId: bet.marketId,
              realizedPnlDelta: -bet.stake
            })

            settledBets += 1
          }
        }

        /*
          After paying winners/refunds, any leftover escrow belongs to house.
          This represents losing stakes not needed for winner payouts.
        */

        const remainingEscrow = await calculateAccountBalance(tx, marketEscrowAccount.id)

        if (remainingEscrow > 0) {
          await postLedgerTransaction(tx, {
            transactionType: "HOUSE_EXPOSURE_RELEASED",
            referenceType: "MARKET",
            referenceId: marketId,
            createdBy: adminUserId,
            entries: [
              {
                accountId: marketEscrowAccount.id,
                amount: -remainingEscrow,
                currency: "POINTS"
              },
              {
                accountId: houseBankrollAccount.id,
                amount: remainingEscrow,
                currency: "POINTS"
              }
            ]
          })
        }

        /*
          Release unused reserve back to house bankroll.
        */

        const remainingReserve = await calculateAccountBalance(tx, houseReserveAccount.id)

        if (remainingReserve > 0) {
          await postLedgerTransaction(tx, {
            transactionType: "HOUSE_EXPOSURE_RELEASED",
            referenceType: "MARKET",
            referenceId: marketId,
            createdBy: adminUserId,
            entries: [
              {
                accountId: houseReserveAccount.id,
                amount: -remainingReserve,
                currency: "POINTS"
              },
              {
                accountId: houseBankrollAccount.id,
                amount: remainingReserve,
                currency: "POINTS"
              }
            ]
          })
        }

        const settledMarket = await tx.markets.update(marketId, {
          status: "SETTLED",
          updatedAt: now(),
          version: market.version + 1
        })

        await audit(tx, {
          actorUserId: adminUserId,
          action: "MARKET_SETTLED",
          entityType: "MARKET",
          entityId: marketId,
          beforeState: market,
          afterState: settledMarket
        })

        return {
          marketId,
          status: "SETTLED",
          settledBets,
          totalPaidOut,
          totalRefunded
        }
      })
    }
  )
}
```

---

# 13. Simpler settlement implementation

The above payout loop is operationally correct but a little awkward because it pays bet-by-bet from escrow and reserve.

A cleaner implementation is to aggregate first.

## Aggregate settlement formula

For resolved outcome:

```text
winningBets = accepted bets where side = resolvedOutcome
losingBets  = accepted bets where side != resolvedOutcome

totalWinnerPayout = sum(winningBets.potentialPayout)
totalStakeEscrow  = sum(all accepted bets.stake)

houseTopUpNeeded = max(0, totalWinnerPayout - totalStakeEscrow)
houseProfit      = max(0, totalStakeEscrow - totalWinnerPayout)
```

Then:

```text
1. If houseTopUpNeeded > 0:
     move houseTopUpNeeded from reserve to market escrow.

2. Pay each winning user from market escrow.

3. Losing users get nothing.

4. Move remaining escrow to house bankroll.

5. Release unused house reserve.
```

For v1, this is easier to reason about.

---

# 14. Important invariants

These should be enforced by tests and reconciliation jobs.

## Ledger invariants

```text
Every ledger transaction balances to zero.
No account balance that must be non-negative goes below zero.
All wallet balances derive from ledger entries.
```

## Bet invariants

```text
Accepted bet has stake > 0.
Accepted bet has odds snapshot.
Accepted bet has potentialPayout = stake * odds.
Accepted bet belongs to exactly one market.
Settled bet cannot change.
Cancelled bet cannot settle as win/loss.
Rejected bet has rejectionCode.
```

## Market invariants

```text
OPEN markets may accept bets.
CLOSED, SUSPENDED, RESOLVED, VOIDED, SETTLED markets may not accept bets.
SETTLED market cannot be resolved again.
Resolved market has resolvedOutcome.
Void market resolves all accepted bets as refunds.
```

## Exposure invariants

```text
market_exposure totals equal aggregate accepted bets.
worstCasePayout = max(totalYesPotentialPayout, totalNoPotentialPayout).
worstCasePlatformLoss = max(0, worstCasePayout - totalStakeCollected).
```

## Settlement invariants

```text
Total winner payouts + house profit = total escrow + house top-up.
All accepted bets become settled after market settlement.
No unsettled accepted bets remain in settled market.
No payout occurs twice for the same bet.
```

---

# 15. Reconciliation queries

## Check ledger balance per transaction

```sql
SELECT
  transaction_id,
  SUM(amount) AS total
FROM ledger_entries
GROUP BY transaction_id
HAVING SUM(amount) <> 0;
```

Should return zero rows.

---

## Recalculate market exposure

```sql
SELECT
  market_id,

  SUM(CASE WHEN side = 'YES' THEN stake ELSE 0 END) AS total_yes_stake,
  SUM(CASE WHEN side = 'NO' THEN stake ELSE 0 END) AS total_no_stake,

  SUM(CASE WHEN side = 'YES' THEN potential_payout ELSE 0 END) AS total_yes_potential_payout,
  SUM(CASE WHEN side = 'NO' THEN potential_payout ELSE 0 END) AS total_no_potential_payout,

  SUM(stake) AS total_stake_collected,

  GREATEST(
    SUM(CASE WHEN side = 'YES' THEN potential_payout ELSE 0 END),
    SUM(CASE WHEN side = 'NO' THEN potential_payout ELSE 0 END)
  ) AS worst_case_payout,

  GREATEST(
    0,
    GREATEST(
      SUM(CASE WHEN side = 'YES' THEN potential_payout ELSE 0 END),
      SUM(CASE WHEN side = 'NO' THEN potential_payout ELSE 0 END)
    ) - SUM(stake)
  ) AS worst_case_platform_loss

FROM bets
WHERE status = 'ACCEPTED'
GROUP BY market_id;
```

---

## Find settled markets with unsettled bets

```sql
SELECT
  m.id AS market_id,
  COUNT(b.id) AS unsettled_bets
FROM markets m
JOIN bets b ON b.market_id = m.id
WHERE m.status = 'SETTLED'
  AND b.status = 'ACCEPTED'
GROUP BY m.id
HAVING COUNT(b.id) > 0;
```

---

## Find accepted bets on non-open placement window anomalies

```sql
SELECT
  b.id,
  b.market_id,
  b.placed_at,
  m.opens_at,
  m.closes_at
FROM bets b
JOIN markets m ON m.id = b.market_id
WHERE b.status = 'ACCEPTED'
  AND (
    b.placed_at < m.opens_at
    OR b.placed_at >= m.closes_at
  );
```

---

## User wallet balance from ledger

```sql
SELECT
  a.owner_id AS user_id,
  a.account_type,
  SUM(le.amount) AS balance
FROM accounts a
JOIN ledger_entries le ON le.account_id = a.id
WHERE a.owner_type = 'USER'
GROUP BY a.owner_id, a.account_type;
```

---

# 16. Recommended implementation order

Build in this order:

```text
1. Users and wallets
2. Double-entry ledger
3. Admin market creation
4. Market open/close
5. Bet placement with idempotency
6. Market exposure tracking
7. Admin resolution
8. Settlement
9. Reconciliation jobs
10. Audit log UI/admin tools
```

For v1, avoid:

```text
order books
peer-to-peer matching
dynamic AMM pricing
secondary trading
partial fills
cash payments
crypto
public markets
automated oracle resolution
user-created markets without review
```

The most important thing is to make **ledger correctness, idempotency, and market settlement** boring and reliable before adding richer market mechanics.

