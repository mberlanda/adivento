# Wallet, ledger, and settlement subsystem

## 0. Design goals

The subsystem must support:

1. **Private points in v1**
2. **No real-money movement initially**
3. **Future migration to real-money, crypto, or regulated credits**
4. **Prediction-market accounting**
5. **Full auditability**
6. **Manual/admin market resolution**
7. **Idempotent APIs**
8. **No mutable balance shortcuts as source of truth**

Core rule:

> The ledger is the source of truth. Wallet balances are derived or cached projections from immutable double-entry postings.

---

# 1. Double-entry ledger model

## 1.1 Core concepts

A **ledger transaction** represents a business event.

A **posting** is one debit or credit line inside that transaction.

Every transaction must balance:

```text
sum(debits) == sum(credits)
```

For a single currency/asset:

```text
total_debit_amount == total_credit_amount
```

For multiple assets later:

```text
sum(debits by asset) == sum(credits by asset)
```

Example assets:

```text
POINT
BONUS_POINT
USD
EUR
USDC
```

For v1, use:

```text
asset_code = "POINT"
```

---

## 1.2 Accounting convention

Use integer minor units.

For private points:

```text
1 point = 100 minor units
```

Example:

```text
10.50 points = 1050 units
```

Recommended amount type:

```text
BIGINT amount_minor
```

Never use floating point.

---

## 1.3 Account categories

Use system accounts and user accounts.

### User accounts

Each user has several internal ledger accounts:

```text
USER_AVAILABLE
USER_RESERVED
USER_SETTLED
USER_BONUS_AVAILABLE
USER_BONUS_RESERVED
```

For v1, you can start with:

```text
USER_AVAILABLE
USER_RESERVED
USER_SETTLED
```

### Platform/system accounts

```text
PLATFORM_POINTS_ISSUANCE
PLATFORM_MARKET_ESCROW
PLATFORM_REVENUE
PLATFORM_PROMO_ISSUANCE
PLATFORM_ADJUSTMENTS
PLATFORM_LIABILITY
PLATFORM_ROUNDING
```

For private points, `PLATFORM_POINTS_ISSUANCE` is the source account used when giving points to users.

For real money later, this changes. The source of funds would come from a payment, bank, or stored-value liability account.

---

## 1.4 Account normal balance

For simplicity, treat all ledger postings using explicit debit/credit entries.

A balance can be calculated as:

```sql
balance = SUM(credits) - SUM(debits)
```

This convention makes user asset accounts positive when credited.

For example:

```text
Credit USER_AVAILABLE 1000
Debit PLATFORM_POINTS_ISSUANCE 1000
```

The user now has +1000 units available.

---

# 2. Wallet/account model

## 2.1 Wallet

A wallet belongs to one user and contains balances for one or more assets.

```text
Wallet
- wallet_id
- user_id
- status
- created_at
- updated_at
```

A user should usually have one wallet.

Future extension:

```text
wallet_type:
- MAIN
- PROMO
- TEST
- HOUSE
```

But v1 can avoid this and use account types instead.

---

## 2.2 Ledger account

Each wallet has multiple ledger accounts.

Example for user `u_123`:

```text
wallet:u_123:POINT:AVAILABLE
wallet:u_123:POINT:RESERVED
wallet:u_123:POINT:SETTLED
```

System accounts:

```text
system:POINT:ISSUANCE
system:POINT:MARKET_ESCROW
system:POINT:ADJUSTMENTS
system:POINT:ROUNDING
```

Recommended account key format:

```text
scope:owner:asset:account_type
```

Examples:

```text
USER:u_123:POINT:AVAILABLE
USER:u_123:POINT:RESERVED
USER:u_123:POINT:SETTLED
SYSTEM:PLATFORM:POINT:ISSUANCE
SYSTEM:PLATFORM:POINT:MARKET_ESCROW
```

---

## 2.3 Account statuses

```text
ACTIVE
FROZEN
CLOSED
```

Rules:

```text
ACTIVE  -> can post
FROZEN  -> cannot debit unless admin/system override
CLOSED  -> cannot post
```

---

# 3. Balance types

## 3.1 Available balance

Funds the user can spend on new bets.

Derived from:

```text
USER_AVAILABLE
```

Used for:

```text
bet placement
withdrawal in future real-money version
manual adjustments
```

---

## 3.2 Reserved balance

Funds locked for open bets.

Derived from:

```text
USER_RESERVED
```

Used for:

```text
open unmatched orders
open fixed-odds bets
open binary-share positions
pending settlement
```

For v1, a placed bet should generally move stake from available to reserved.

---

## 3.3 Settled balance

Historical or realized winnings/losses.

There are two ways to model this.

### Option A: settled as a real ledger account

```text
USER_SETTLED
```

At settlement, move net winnings/losses into settled, then optionally sweep to available.

### Option B: settled as reporting only

Keep user balances in `AVAILABLE` and `RESERVED`, and derive settled PnL from transaction history.

For v1, I recommend:

> Use `AVAILABLE` and `RESERVED` as actual spendable accounts. Use `SETTLED` as reporting metadata, not as a separate user balance account unless you have a strong reason.

However, since the requested balance types include settled, implement it as a projection:

```text
settled_profit_loss = SUM(settlement credits) - SUM(losing stake debits)
```

Do not require users to move money through a separate `SETTLED` account unless needed.

---

## 3.4 Bonus/play credits

Bonus credits are useful even for private points because they let you distinguish:

```text
regular points
admin grants
promotional credits
non-withdrawable credits later
```

Recommended v1 approach:

Use separate asset codes:

```text
POINT
BONUS_POINT
```

This is cleaner than mixing bonus status inside the same account.

Example:

```text
USER:u_123:POINT:AVAILABLE
USER:u_123:BONUS_POINT:AVAILABLE
```

Future rule:

```text
BONUS_POINT cannot be withdrawn
BONUS_POINT may expire
BONUS_POINT may be wagerable or non-wagerable
```

For v1, you can defer bonus support but reserve the schema for it.

---

# 4. Transaction types

Use explicit transaction types. Do not overload generic adjustment rows.

## 4.1 Funding and admin

```text
POINTS_GRANT
POINTS_REVOKE
ADMIN_ADJUSTMENT_CREDIT
ADMIN_ADJUSTMENT_DEBIT
BONUS_GRANT
BONUS_EXPIRE
```

## 4.2 Bet lifecycle

```text
BET_RESERVE
BET_CANCEL_RELEASE
BET_VOID_RELEASE
BET_SETTLE_WIN
BET_SETTLE_LOSS
BET_SETTLE_PUSH
BET_SETTLE_PARTIAL
BET_PAYOUT
```

Depending on mechanism, you may also need:

```text
ORDER_RESERVE
ORDER_RELEASE
ORDER_FILL
ORDER_CANCEL
TRADE_EXECUTION
POSITION_OPEN
POSITION_CLOSE
```

## 4.3 Market lifecycle

```text
MARKET_SETTLEMENT
MARKET_VOID
MARKET_CORRECTION
MARKET_REOPEN
MARKET_RESOLUTION_REVERSAL
```

## 4.4 Fees, future

```text
PLATFORM_FEE
CREATOR_FEE
WITHDRAWAL_FEE
DEPOSIT
WITHDRAWAL
CHARGEBACK
PAYMENT_REVERSAL
```

Even if unused in v1, keep transaction type enum extensible.

---

# 5. Bet placement and reservation flow

Assume v1 uses simple fixed-stake binary bets.

Example:

```text
User bets 100 points on YES.
Potential payout if YES wins: 180 points.
Stake: 100 points.
Potential profit: 80 points.
```

For a private-points MVP, reserve the user stake.

## 5.1 Pre-conditions

Before placing a bet:

```text
user.status == ACTIVE
wallet.status == ACTIVE
market.status == OPEN
outcome in [YES, NO]
stake > 0
available_balance >= stake
idempotency_key is unique for this user and endpoint
market accepts bets
market has not passed close time
```

---

## 5.2 Ledger transaction: reserve stake

Move stake from available to reserved.

```text
Transaction: BET_RESERVE
Reference: bet_id

Debit  USER:u_123:POINT:AVAILABLE   10000
Credit USER:u_123:POINT:RESERVED    10000
```

The user’s total balance does not change.

```text
available decreases
reserved increases
total remains same
```

---

## 5.3 Bet record

Create bet:

```text
bet_id
user_id
market_id
outcome
stake_amount_minor
odds_snapshot
potential_payout_amount_minor
potential_profit_amount_minor
status = RESERVED
created_at
```

Then transition:

```text
RESERVED -> OPEN
```

You can do this in the same DB transaction.

---

## 5.4 Atomicity

The following must commit atomically:

```text
insert bet
insert ledger transaction
insert ledger postings
update balance projection
insert audit log
insert outbox event
```

If any fail, all rollback.

---

## 5.5 Sequence

```text
POST /bets
  validate request
  check idempotency key
  load user wallet accounts FOR UPDATE
  compute available balance
  reject if insufficient
  create bet
  create ledger transaction BET_RESERVE
  create postings available -> reserved
  update balance projection
  write audit event
  write outbox event BetPlaced
  commit
  return bet
```

---

# 6. Bet cancellation and void flow

Cancellation and void are different.

## 6.1 Cancellation

Cancellation happens before settlement, usually because:

```text
user cancels unmatched order
admin cancels bet before close
system rejects stale bet
```

For v1 fixed-stake bets, user cancellation may not be allowed after placement. But the ledger should support it.

### Ledger transaction

Release reserved stake back to available.

```text
Transaction: BET_CANCEL_RELEASE
Reference: bet_id

Debit  USER:u_123:POINT:RESERVED    10000
Credit USER:u_123:POINT:AVAILABLE   10000
```

### Bet status transition

```text
OPEN -> CANCELLED
```

Allowed only if:

```text
bet.status in [RESERVED, OPEN]
market.status in [OPEN, PAUSED]
bet not settled
```

---

## 6.2 Void

Void means the market or bet is invalid, and stake is returned.

Examples:

```text
market question invalid
event cancelled
resolution impossible
admin voids market
rule violation
```

### Ledger transaction

Same balance movement as cancellation:

```text
Transaction: BET_VOID_RELEASE
Reference: bet_id

Debit  USER:u_123:POINT:RESERVED    10000
Credit USER:u_123:POINT:AVAILABLE   10000
```

### Bet status transition

```text
OPEN -> VOIDED
```

### Market status transition

```text
OPEN|CLOSED|RESOLVED_PENDING -> VOIDED
```

---

## 6.3 Idempotency for cancel/void

Repeated void/cancel calls must not double-release funds.

Enforce with:

```text
unique(reference_type, reference_id, transaction_type)
```

Example:

```text
unique("BET", bet_id, "BET_VOID_RELEASE")
```

---

# 7. Market settlement flow

Assume binary market:

```text
YES wins
NO loses
```

Each bet has:

```text
stake
potential_payout
potential_profit
```

For v1, use simple fixed payout determined at bet placement.

---

## 7.1 Settlement states

Market statuses:

```text
DRAFT
OPEN
PAUSED
CLOSED
RESOLUTION_PROPOSED
RESOLVED
VOIDED
DISPUTED
CORRECTED
ARCHIVED
```

Bet statuses:

```text
RESERVED
OPEN
CANCELLED
VOIDED
WON
LOST
PUSHED
SETTLED
SETTLEMENT_REVERSED
```

Recommended simpler v1 bet statuses:

```text
OPEN
CANCELLED
VOIDED
WON
LOST
PUSHED
```

---

## 7.2 Settlement pre-conditions

```text
market.status in [CLOSED, RESOLUTION_PROPOSED]
resolution_outcome in [YES, NO, VOID, PUSH]
admin has permission MARKET_RESOLVE
settlement has not already been completed
all target bets are OPEN
```

---

## 7.3 Winning bet settlement

Example:

```text
Stake: 100
Payout: 180
Profit: 80
```

At placement, 100 was moved from available to reserved.

At settlement:

```text
Reserved stake is consumed.
Stake + winnings are credited to available.
```

Ledger:

```text
Transaction: BET_SETTLE_WIN
Reference: bet_id

Debit  USER:u_123:POINT:RESERVED        10000
Debit  SYSTEM:PLATFORM:POINT:ISSUANCE    8000
Credit USER:u_123:POINT:AVAILABLE       18000
```

This creates 80 points of profit from platform issuance in a play-money environment.

For a real-money parimutuel or exchange model, this would not come from issuance. It would come from escrowed losing stakes.

---

## 7.4 Losing bet settlement

Example:

```text
Stake: 100
Payout: 0
```

Ledger:

```text
Transaction: BET_SETTLE_LOSS
Reference: bet_id

Debit  USER:u_123:POINT:RESERVED       10000
Credit SYSTEM:PLATFORM:POINT:REVENUE   10000
```

For private points, `PLATFORM_REVENUE` can represent burned/retained points.

For future real-money or pooled markets, this should go to escrow/payout pool rather than revenue unless the platform is the counterparty.

---

## 7.5 Push settlement

Push means stake returned, no win/loss.

```text
Transaction: BET_SETTLE_PUSH
Reference: bet_id

Debit  USER:u_123:POINT:RESERVED    10000
Credit USER:u_123:POINT:AVAILABLE   10000
```

---

## 7.6 Market-wide settlement transaction strategy

There are two valid options.

### Option A: one ledger transaction per bet

Recommended for v1.

Pros:

```text
simple idempotency
easy retry
easy audit
partial failure recovery
```

Cons:

```text
more rows
market settlement spans many transactions
```

### Option B: one large ledger transaction for entire market

Pros:

```text
single balanced settlement event
```

Cons:

```text
huge transaction
harder retries
harder partial recovery
row-lock contention
```

Recommendation:

> Use one ledger transaction per bet, grouped by a `settlement_batch_id`.

---

## 7.7 Settlement batch

```text
settlement_batch_id
market_id
resolved_outcome
status
created_by_admin_id
started_at
completed_at
failure_reason
```

Each bet settlement transaction links to:

```text
settlement_batch_id
market_id
bet_id
```

Batch statuses:

```text
PENDING
RUNNING
COMPLETED
PARTIALLY_FAILED
FAILED
REVERSED
```

---

## 7.8 Settlement sequence

```text
Admin resolves market
  create settlement_batch
  lock market
  transition market to RESOLUTION_PROPOSED or RESOLVED
  fetch OPEN bets
  for each bet:
    lock bet
    check no prior settlement transaction
    compute result
    create ledger transaction
    create postings
    update bet status
    update balance projection
    write audit log
    write outbox event BetSettled
  mark batch COMPLETED
  write outbox event MarketSettled
```

For small v1 markets, this can run synchronously.

For larger markets, use async worker with retry.

---

# 8. Idempotency strategy

Idempotency is mandatory.

## 8.1 API-level idempotency

Every write endpoint accepts:

```http
Idempotency-Key: <client-generated-uuid>
```

Store:

```text
idempotency_key
user_id
endpoint
request_hash
response_status
response_body
created_at
expires_at
```

Constraint:

```sql
UNIQUE(user_id, endpoint, idempotency_key)
```

Rules:

1. Same key + same request hash returns same response.
2. Same key + different request hash returns `409 Conflict`.
3. Idempotency keys expire after a retention period.
4. For financial/ledger writes, retain much longer than normal API idempotency, ideally indefinitely or at least several years if real money later.

---

## 8.2 Ledger-level idempotency

Ledger transactions need their own idempotency independent of HTTP.

Fields:

```text
transaction_type
reference_type
reference_id
idempotency_key
```

Constraints:

```sql
UNIQUE(transaction_type, reference_type, reference_id)
UNIQUE(idempotency_key)
```

Examples:

```text
BET_RESERVE + BET + bet_id
BET_SETTLE_WIN + BET + bet_id
BET_VOID_RELEASE + BET + bet_id
```

This prevents duplicate posting even if workers retry.

---

## 8.3 Outbox idempotency

Every important write should produce an outbox event.

```text
outbox_event_id
aggregate_type
aggregate_id
event_type
payload
status
created_at
published_at
```

Constraint:

```sql
UNIQUE(aggregate_type, aggregate_id, event_type, dedupe_key)
```

---

# 9. Audit log requirements

The audit log is separate from the ledger.

The ledger says:

```text
what value moved
```

The audit log says:

```text
who did what, why, from where, and under which authority
```

## 9.1 Audit events

Examples:

```text
WalletCreated
PointsGranted
BetPlaced
BetCancelled
MarketClosed
MarketResolved
MarketVoided
BetSettled
AdminAdjustmentCreated
SettlementReversed
UserFrozen
```

## 9.2 Required fields

```text
audit_log_id
occurred_at
actor_type
actor_id
actor_role
action
entity_type
entity_id
before_state_json
after_state_json
reason
ip_address
user_agent
correlation_id
request_id
idempotency_key
metadata_json
```

Actor types:

```text
USER
ADMIN
SYSTEM
WORKER
```

## 9.3 Admin actions require reason

For admin financial actions:

```text
reason is required
```

Examples:

```text
manual correction
market void
duplicate bet correction
abuse investigation
test grant
```

---

# 10. Reconciliation queries

These should be implemented as scheduled checks.

## 10.1 Ledger transactions must balance

```sql
SELECT
    lt.ledger_transaction_id,
    lp.asset_code,
    SUM(CASE WHEN lp.direction = 'DEBIT' THEN lp.amount_minor ELSE 0 END) AS total_debits,
    SUM(CASE WHEN lp.direction = 'CREDIT' THEN lp.amount_minor ELSE 0 END) AS total_credits
FROM ledger_transactions lt
JOIN ledger_postings lp
    ON lp.ledger_transaction_id = lt.ledger_transaction_id
GROUP BY lt.ledger_transaction_id, lp.asset_code
HAVING
    SUM(CASE WHEN lp.direction = 'DEBIT' THEN lp.amount_minor ELSE 0 END)
    <>
    SUM(CASE WHEN lp.direction = 'CREDIT' THEN lp.amount_minor ELSE 0 END);
```

Expected result:

```text
zero rows
```

---

## 10.2 Cached account balances match postings

```sql
SELECT
    la.ledger_account_id,
    la.asset_code,
    ab.balance_minor AS cached_balance,
    COALESCE(SUM(
        CASE
            WHEN lp.direction = 'CREDIT' THEN lp.amount_minor
            WHEN lp.direction = 'DEBIT' THEN -lp.amount_minor
        END
    ), 0) AS computed_balance
FROM ledger_accounts la
LEFT JOIN ledger_postings lp
    ON lp.ledger_account_id = la.ledger_account_id
LEFT JOIN account_balances ab
    ON ab.ledger_account_id = la.ledger_account_id
GROUP BY la.ledger_account_id, la.asset_code, ab.balance_minor
HAVING ab.balance_minor <> COALESCE(SUM(
        CASE
            WHEN lp.direction = 'CREDIT' THEN lp.amount_minor
            WHEN lp.direction = 'DEBIT' THEN -lp.amount_minor
        END
    ), 0);
```

Expected result:

```text
zero rows
```

---

## 10.3 No negative available balances

```sql
SELECT
    la.ledger_account_id,
    la.owner_id,
    ab.balance_minor
FROM ledger_accounts la
JOIN account_balances ab
    ON ab.ledger_account_id = la.ledger_account_id
WHERE la.account_type = 'USER_AVAILABLE'
  AND ab.balance_minor < 0;
```

Expected result:

```text
zero rows
```

---

## 10.4 No negative reserved balances

```sql
SELECT
    la.ledger_account_id,
    la.owner_id,
    ab.balance_minor
FROM ledger_accounts la
JOIN account_balances ab
    ON ab.ledger_account_id = la.ledger_account_id
WHERE la.account_type = 'USER_RESERVED'
  AND ab.balance_minor < 0;
```

Expected result:

```text
zero rows
```

---

## 10.5 Open bet reserved amount matches user reserved postings

```sql
SELECT
    b.bet_id,
    b.user_id,
    b.stake_amount_minor,
    COALESCE(SUM(
        CASE
            WHEN lp.direction = 'CREDIT' THEN lp.amount_minor
            WHEN lp.direction = 'DEBIT' THEN -lp.amount_minor
        END
    ), 0) AS net_reserved_for_bet
FROM bets b
JOIN ledger_transactions lt
    ON lt.reference_type = 'BET'
   AND lt.reference_id = b.bet_id
JOIN ledger_postings lp
    ON lp.ledger_transaction_id = lt.ledger_transaction_id
JOIN ledger_accounts la
    ON la.ledger_account_id = lp.ledger_account_id
WHERE la.account_type = 'USER_RESERVED'
  AND b.status = 'OPEN'
GROUP BY b.bet_id, b.user_id, b.stake_amount_minor
HAVING COALESCE(SUM(
        CASE
            WHEN lp.direction = 'CREDIT' THEN lp.amount_minor
            WHEN lp.direction = 'DEBIT' THEN -lp.amount_minor
        END
    ), 0) <> b.stake_amount_minor;
```

Expected result:

```text
zero rows
```

---

## 10.6 Settled bets must have settlement transaction

```sql
SELECT b.bet_id, b.status
FROM bets b
WHERE b.status IN ('WON', 'LOST', 'PUSHED', 'VOIDED')
  AND NOT EXISTS (
      SELECT 1
      FROM ledger_transactions lt
      WHERE lt.reference_type = 'BET'
        AND lt.reference_id = b.bet_id
        AND lt.transaction_type IN (
            'BET_SETTLE_WIN',
            'BET_SETTLE_LOSS',
            'BET_SETTLE_PUSH',
            'BET_VOID_RELEASE'
        )
  );
```

Expected result:

```text
zero rows
```

---

## 10.7 Duplicate settlement detection

```sql
SELECT
    reference_id AS bet_id,
    COUNT(*) AS settlement_tx_count
FROM ledger_transactions
WHERE reference_type = 'BET'
  AND transaction_type IN (
      'BET_SETTLE_WIN',
      'BET_SETTLE_LOSS',
      'BET_SETTLE_PUSH',
      'BET_VOID_RELEASE'
  )
GROUP BY reference_id
HAVING COUNT(*) > 1;
```

Expected result:

```text
zero rows
```

---

# 11. Database schema

PostgreSQL-style schema.

## 11.1 Wallets

```sql
CREATE TABLE wallets (
    wallet_id UUID PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 11.2 Ledger accounts

```sql
CREATE TABLE ledger_accounts (
    ledger_account_id UUID PRIMARY KEY,
    wallet_id UUID NULL REFERENCES wallets(wallet_id),
    owner_type TEXT NOT NULL CHECK (owner_type IN ('USER', 'SYSTEM')),
    owner_id TEXT NOT NULL,
    asset_code TEXT NOT NULL,
    account_type TEXT NOT NULL CHECK (account_type IN (
        'USER_AVAILABLE',
        'USER_RESERVED',
        'USER_SETTLED',
        'USER_BONUS_AVAILABLE',
        'USER_BONUS_RESERVED',
        'SYSTEM_ISSUANCE',
        'SYSTEM_MARKET_ESCROW',
        'SYSTEM_REVENUE',
        'SYSTEM_PROMO_ISSUANCE',
        'SYSTEM_ADJUSTMENTS',
        'SYSTEM_LIABILITY',
        'SYSTEM_ROUNDING'
    )),
    status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(owner_type, owner_id, asset_code, account_type)
);
```

---

## 11.3 Account balances projection

```sql
CREATE TABLE account_balances (
    ledger_account_id UUID PRIMARY KEY REFERENCES ledger_accounts(ledger_account_id),
    asset_code TEXT NOT NULL,
    balance_minor BIGINT NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (balance_minor >= 0)
);
```

For some system accounts, negative balances may be acceptable depending on accounting convention. If so, remove the global `CHECK` and enforce non-negative only for user spendable accounts in application code or via trigger.

Safer version:

```sql
-- No global check here.
-- Enforce non-negative user balances inside posting transaction logic.
```

---

## 11.4 Ledger transactions

```sql
CREATE TABLE ledger_transactions (
    ledger_transaction_id UUID PRIMARY KEY,
    transaction_type TEXT NOT NULL,
    reference_type TEXT NOT NULL,
    reference_id UUID NOT NULL,
    idempotency_key TEXT NOT NULL,
    asset_group TEXT NULL,
    status TEXT NOT NULL CHECK (status IN ('PENDING', 'POSTED', 'REVERSED')),
    description TEXT NULL,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    posted_at TIMESTAMPTZ NULL,

    UNIQUE(transaction_type, reference_type, reference_id),
    UNIQUE(idempotency_key)
);
```

---

## 11.5 Ledger postings

```sql
CREATE TABLE ledger_postings (
    ledger_posting_id UUID PRIMARY KEY,
    ledger_transaction_id UUID NOT NULL REFERENCES ledger_transactions(ledger_transaction_id),
    ledger_account_id UUID NOT NULL REFERENCES ledger_accounts(ledger_account_id),
    asset_code TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ledger_postings_account
    ON ledger_postings (ledger_account_id, created_at);

CREATE INDEX idx_ledger_postings_transaction
    ON ledger_postings (ledger_transaction_id);
```

---

## 11.6 Markets

```sql
CREATE TABLE markets (
    market_id UUID PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NULL,
    status TEXT NOT NULL CHECK (status IN (
        'DRAFT',
        'OPEN',
        'PAUSED',
        'CLOSED',
        'RESOLUTION_PROPOSED',
        'RESOLVED',
        'VOIDED',
        'DISPUTED',
        'CORRECTED',
        'ARCHIVED'
    )),
    market_type TEXT NOT NULL CHECK (market_type IN ('BINARY')),
    close_time TIMESTAMPTZ NULL,
    resolution_outcome TEXT NULL CHECK (resolution_outcome IN ('YES', 'NO', 'PUSH', 'VOID') OR resolution_outcome IS NULL),
    created_by_user_id UUID NOT NULL,
    resolved_by_user_id UUID NULL,
    resolution_reason TEXT NULL,
    resolved_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 11.7 Bets

```sql
CREATE TABLE bets (
    bet_id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    market_id UUID NOT NULL REFERENCES markets(market_id),
    outcome TEXT NOT NULL CHECK (outcome IN ('YES', 'NO')),
    stake_amount_minor BIGINT NOT NULL CHECK (stake_amount_minor > 0),
    asset_code TEXT NOT NULL,
    odds_numerator BIGINT NOT NULL,
    odds_denominator BIGINT NOT NULL,
    potential_payout_amount_minor BIGINT NOT NULL,
    potential_profit_amount_minor BIGINT NOT NULL,
    status TEXT NOT NULL CHECK (status IN (
        'RESERVED',
        'OPEN',
        'CANCELLED',
        'VOIDED',
        'WON',
        'LOST',
        'PUSHED',
        'SETTLEMENT_REVERSED'
    )),
    idempotency_key TEXT NOT NULL,
    placed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    settled_at TIMESTAMPTZ NULL,
    settlement_batch_id UUID NULL,

    UNIQUE(user_id, idempotency_key)
);

CREATE INDEX idx_bets_user
    ON bets (user_id, placed_at DESC);

CREATE INDEX idx_bets_market_status
    ON bets (market_id, status);
```

---

## 11.8 Settlement batches

```sql
CREATE TABLE settlement_batches (
    settlement_batch_id UUID PRIMARY KEY,
    market_id UUID NOT NULL REFERENCES markets(market_id),
    resolved_outcome TEXT NOT NULL CHECK (resolved_outcome IN ('YES', 'NO', 'PUSH', 'VOID')),
    status TEXT NOT NULL CHECK (status IN (
        'PENDING',
        'RUNNING',
        'COMPLETED',
        'PARTIALLY_FAILED',
        'FAILED',
        'REVERSED'
    )),
    created_by_user_id UUID NOT NULL,
    reason TEXT NOT NULL,
    started_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    failure_reason TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(market_id, resolved_outcome)
);
```

This unique constraint may be too strict if corrections are allowed. For v1, it is useful. For later versions, use:

```text
market_id + settlement_version
```

---

## 11.9 Idempotency keys

```sql
CREATE TABLE idempotency_records (
    idempotency_record_id UUID PRIMARY KEY,
    actor_id UUID NOT NULL,
    endpoint TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    response_status INT NULL,
    response_body_json JSONB NULL,
    status TEXT NOT NULL CHECK (status IN ('IN_PROGRESS', 'COMPLETED', 'FAILED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NULL,

    UNIQUE(actor_id, endpoint, idempotency_key)
);
```

---

## 11.10 Audit log

```sql
CREATE TABLE audit_logs (
    audit_log_id UUID PRIMARY KEY,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor_type TEXT NOT NULL CHECK (actor_type IN ('USER', 'ADMIN', 'SYSTEM', 'WORKER')),
    actor_id TEXT NOT NULL,
    actor_role TEXT NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    before_state_json JSONB NULL,
    after_state_json JSONB NULL,
    reason TEXT NULL,
    ip_address INET NULL,
    user_agent TEXT NULL,
    correlation_id TEXT NULL,
    request_id TEXT NULL,
    idempotency_key TEXT NULL,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_audit_entity
    ON audit_logs (entity_type, entity_id, occurred_at DESC);

CREATE INDEX idx_audit_actor
    ON audit_logs (actor_type, actor_id, occurred_at DESC);
```

---

## 11.11 Outbox events

```sql
CREATE TABLE outbox_events (
    outbox_event_id UUID PRIMARY KEY,
    aggregate_type TEXT NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    dedupe_key TEXT NOT NULL,
    payload_json JSONB NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED')),
    attempts INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ NULL,

    UNIQUE(aggregate_type, aggregate_id, event_type, dedupe_key)
);
```

---

# 12. API specs

## 12.1 Get wallet

```http
GET /v1/wallet
Authorization: Bearer <token>
```

Response:

```json
{
  "walletId": "uuid",
  "userId": "uuid",
  "assetBalances": [
    {
      "assetCode": "POINT",
      "availableMinor": 125000,
      "reservedMinor": 30000,
      "totalMinor": 155000
    }
  ]
}
```

---

## 12.2 Grant points, admin only

```http
POST /v1/admin/wallets/{userId}/grants
Idempotency-Key: uuid
```

Request:

```json
{
  "assetCode": "POINT",
  "amountMinor": 100000,
  "reason": "Initial private beta grant"
}
```

Ledger:

```text
Debit  SYSTEM_ISSUANCE
Credit USER_AVAILABLE
```

Response:

```json
{
  "transactionId": "uuid",
  "userId": "uuid",
  "assetCode": "POINT",
  "amountMinor": 100000,
  "status": "POSTED"
}
```

---

## 12.3 Place bet

```http
POST /v1/bets
Idempotency-Key: uuid
```

Request:

```json
{
  "marketId": "uuid",
  "outcome": "YES",
  "stakeAmountMinor": 10000,
  "assetCode": "POINT",
  "maxOddsNumerator": 18,
  "maxOddsDenominator": 10
}
```

For fixed odds, you may use:

```json
{
  "oddsNumerator": 18,
  "oddsDenominator": 10
}
```

Response:

```json
{
  "betId": "uuid",
  "marketId": "uuid",
  "outcome": "YES",
  "stakeAmountMinor": 10000,
  "assetCode": "POINT",
  "oddsNumerator": 18,
  "oddsDenominator": 10,
  "potentialPayoutAmountMinor": 18000,
  "potentialProfitAmountMinor": 8000,
  "status": "OPEN",
  "ledgerTransactionId": "uuid"
}
```

Errors:

```http
400 INVALID_AMOUNT
400 INVALID_OUTCOME
403 WALLET_FROZEN
404 MARKET_NOT_FOUND
409 IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST
409 MARKET_NOT_OPEN
409 INSUFFICIENT_AVAILABLE_BALANCE
422 ODDS_CHANGED
```

---

## 12.4 Cancel bet

```http
POST /v1/bets/{betId}/cancel
Idempotency-Key: uuid
```

Request:

```json
{
  "reason": "User cancellation"
}
```

Response:

```json
{
  "betId": "uuid",
  "status": "CANCELLED",
  "releasedAmountMinor": 10000,
  "ledgerTransactionId": "uuid"
}
```

---

## 12.5 Void market, admin only

```http
POST /v1/admin/markets/{marketId}/void
Idempotency-Key: uuid
```

Request:

```json
{
  "reason": "Event cancelled"
}
```

Response:

```json
{
  "marketId": "uuid",
  "status": "VOIDED",
  "settlementBatchId": "uuid"
}
```

---

## 12.6 Resolve market, admin only

```http
POST /v1/admin/markets/{marketId}/resolve
Idempotency-Key: uuid
```

Request:

```json
{
  "resolvedOutcome": "YES",
  "reason": "Official result confirmed"
}
```

Response:

```json
{
  "marketId": "uuid",
  "resolvedOutcome": "YES",
  "settlementBatchId": "uuid",
  "status": "RESOLVED",
  "settledBets": 42,
  "failedBets": 0
}
```

For async settlement:

```json
{
  "marketId": "uuid",
  "resolvedOutcome": "YES",
  "settlementBatchId": "uuid",
  "status": "SETTLEMENT_STARTED"
}
```

---

## 12.7 Get ledger transactions for wallet

```http
GET /v1/wallet/ledger-transactions?assetCode=POINT&limit=50&cursor=...
```

Response:

```json
{
  "items": [
    {
      "transactionId": "uuid",
      "transactionType": "BET_RESERVE",
      "referenceType": "BET",
      "referenceId": "uuid",
      "assetCode": "POINT",
      "amountMinor": 10000,
      "createdAt": "2026-05-21T18:00:00Z",
      "postings": [
        {
          "accountType": "USER_AVAILABLE",
          "direction": "DEBIT",
          "amountMinor": 10000
        },
        {
          "accountType": "USER_RESERVED",
          "direction": "CREDIT",
          "amountMinor": 10000
        }
      ]
    }
  ],
  "nextCursor": "..."
}
```

---

# 13. Edge cases and invariants

## 13.1 Core ledger invariants

These must always hold:

```text
Every posted ledger transaction has at least two postings.
Every posted ledger transaction balances by asset.
Every posting amount is positive.
Every posting references an active ledger account.
Ledger postings are immutable.
Ledger transactions are immutable after POSTED, except status reversal metadata.
User available balance cannot go negative.
User reserved balance cannot go negative.
A bet can reserve funds exactly once.
A bet can settle exactly once.
A voided bet cannot later settle.
A settled bet cannot be cancelled.
A market cannot be resolved twice without explicit correction flow.
```

---

## 13.2 Bet lifecycle invariants

Allowed transitions:

```text
RESERVED -> OPEN
RESERVED -> CANCELLED
OPEN -> CANCELLED
OPEN -> VOIDED
OPEN -> WON
OPEN -> LOST
OPEN -> PUSHED
WON -> SETTLEMENT_REVERSED
LOST -> SETTLEMENT_REVERSED
PUSHED -> SETTLEMENT_REVERSED
VOIDED -> SETTLEMENT_REVERSED
```

Disallowed:

```text
WON -> LOST
LOST -> WON
VOIDED -> WON
CANCELLED -> WON
CANCELLED -> LOST
```

For correction, create explicit reversal transactions instead of mutating old ones.

---

## 13.3 Market correction

Mistaken resolution will happen.

Do not delete settlement transactions.

Use reversal.

Example:

Original settlement:

```text
BET_SETTLE_WIN
```

Correction:

```text
BET_SETTLEMENT_REVERSAL
```

Then apply the correct settlement.

### Reversal principle

A reversal transaction posts exact opposite entries.

Original:

```text
Debit  USER_RESERVED      10000
Debit  SYSTEM_ISSUANCE     8000
Credit USER_AVAILABLE     18000
```

Reversal:

```text
Debit  USER_AVAILABLE     18000
Credit USER_RESERVED      10000
Credit SYSTEM_ISSUANCE     8000
```

But this can fail if the user no longer has enough available balance.

Therefore, for v1:

> Avoid automatic settlement reversal unless balances are sufficient, or allow negative correction receivables through a dedicated account.

Recommended correction account:

```text
USER_NEGATIVE_ADJUSTMENT_RECEIVABLE
```

For v1 friends-and-family points, you may instead allow admin correction that brings the user balance negative only if explicitly permitted. But that complicates product UX.

Safer v1 rule:

```text
Market resolutions are final after admin confirmation.
Corrections require manual admin adjustment if user balances have changed.
```

---

## 13.4 Insufficient funds at placement

Must reject before ledger write:

```http
409 INSUFFICIENT_AVAILABLE_BALANCE
```

Never create a negative user available balance for normal betting.

---

## 13.5 Concurrent bet placement

Two simultaneous bets can race.

Solution:

```text
lock account_balances row for USER_AVAILABLE
```

Example:

```sql
SELECT *
FROM account_balances
WHERE ledger_account_id = :available_account_id
FOR UPDATE;
```

Then check balance and post.

Alternative:

```sql
UPDATE account_balances
SET balance_minor = balance_minor - :amount,
    version = version + 1
WHERE ledger_account_id = :available_account_id
  AND balance_minor >= :amount;
```

Check affected rows = 1.

---

## 13.6 Retried bet placement

If client retries after timeout:

```text
same Idempotency-Key
same request body
```

Return original response.

Do not create a second bet.

---

## 13.7 Market closes while bet is being placed

Use database lock or status check inside transaction.

```text
lock market row
check status == OPEN
check close_time > now()
then reserve funds
```

This prevents accepting a bet after close.

---

## 13.8 Odds changed during bet placement

If using fixed odds:

Client submits acceptable odds.

```json
{
  "minAcceptedPayoutAmountMinor": 18000
}
```

or:

```json
{
  "maxOddsNumerator": 18,
  "maxOddsDenominator": 10
}
```

If current odds are worse than accepted:

```http
422 ODDS_CHANGED
```

For v1, you can avoid dynamic odds entirely.

---

## 13.9 Partial settlement failure

If settling a market with many bets, some may fail due to bugs, locks, or inconsistent state.

Rules:

```text
Each bet settlement is idempotent.
Batch can be PARTIALLY_FAILED.
Retry only failed bets.
Never settle already-settled bets again.
```

---

## 13.10 Rounding

Use integer minor units and deterministic rounding.

For fixed odds:

```text
payout = floor(stake * odds_numerator / odds_denominator)
profit = payout - stake
```

Any remainder goes to:

```text
SYSTEM_ROUNDING
```

But if using integer division with floor, no posting is needed unless you explicitly track theoretical remainder.

Invariant:

```text
potential_payout_amount_minor >= stake_amount_minor
```

unless negative-odds style bets are introduced later.

---

## 13.11 Bonus credits

If bonus credits are used:

Rules must define:

```text
Can bonus be wagered?
Can winnings from bonus become regular points?
Can bonus expire while reserved?
What happens if a bonus bet is voided?
```

Simple v1 rule:

```text
No bonus credits.
Only POINT.
```

Future rule:

```text
Stake consumed from BONUS_POINT first.
Winnings paid in POINT.
Voids return BONUS_POINT.
```

---

# 14. Recommended v1 implementation

## 14.1 Keep it simple

For v1, implement:

```text
Asset: POINT
Accounts:
  USER_AVAILABLE
  USER_RESERVED
  SYSTEM_ISSUANCE
  SYSTEM_REVENUE
  SYSTEM_ADJUSTMENTS

Flows:
  grant points
  place bet
  cancel bet if allowed
  void bet/market
  settle market manually
  wallet balance query
  ledger history query
```

Defer:

```text
real money
withdrawals
deposits
fees
bonus credits
multi-currency
market correction automation
order book
LMSR
parimutuel settlement
```

---

## 14.2 Recommended posting templates

### Grant points

```text
Debit  SYSTEM_ISSUANCE
Credit USER_AVAILABLE
```

### Reserve stake

```text
Debit  USER_AVAILABLE
Credit USER_RESERVED
```

### Cancel bet

```text
Debit  USER_RESERVED
Credit USER_AVAILABLE
```

### Void bet

```text
Debit  USER_RESERVED
Credit USER_AVAILABLE
```

### Winning bet

```text
Debit  USER_RESERVED
Debit  SYSTEM_ISSUANCE
Credit USER_AVAILABLE
```

### Losing bet

```text
Debit  USER_RESERVED
Credit SYSTEM_REVENUE
```

### Push

```text
Debit  USER_RESERVED
Credit USER_AVAILABLE
```

---

# 15. Future real-money compatibility

To avoid blocking real-money support:

## 15.1 Do now

```text
Use asset_code everywhere.
Use integer minor units.
Use immutable ledger postings.
Use double-entry accounting.
Use idempotency keys.
Separate ledger from audit log.
Separate user accounts from system accounts.
Track reference_type and reference_id.
Use explicit transaction types.
```

## 15.2 Avoid now

```text
Do not call points "cash".
Do not imply redeemability.
Do not mix bonus and regular balances without asset/account separation.
Do not mutate balances directly without postings.
Do not delete or overwrite ledger transactions.
Do not allow negative user balances casually.
Do not build settlement logic that assumes platform-issued infinite liquidity forever.
```

## 15.3 Later real-money changes

Add:

```text
DEPOSIT_PENDING
DEPOSIT_SETTLED
WITHDRAWAL_PENDING
WITHDRAWAL_SETTLED
PAYMENT_REVERSAL
CHARGEBACK
KYC_STATUS
AML_HOLD
USER_CASH_AVAILABLE
USER_CASH_RESERVED
PLATFORM_CLIENT_FUNDS_LIABILITY
PAYMENT_PROCESSOR_CLEARING
BANK_CLEARING
```

Real-money postings would shift from issuance-style accounting to liability-style accounting.

Example deposit:

```text
Debit  PAYMENT_PROCESSOR_CLEARING
Credit USER_CASH_AVAILABLE
```

Example bet reserve:

```text
Debit  USER_CASH_AVAILABLE
Credit USER_CASH_RESERVED
```

Example exchange-style settlement:

```text
Debit  LOSER_RESERVED
Credit WINNER_AVAILABLE
```

No money is created.

---

# 16. Implementation checklist for coding agent

Build in this order:

1. Create wallet on user signup.
2. Create default ledger accounts for `POINT`.
3. Implement ledger posting engine.
4. Implement balance projection updates.
5. Implement idempotency table.
6. Implement admin point grants.
7. Implement wallet balance endpoint.
8. Implement bet placement with reservation.
9. Implement bet cancellation.
10. Implement market void.
11. Implement market settlement.
12. Implement audit log.
13. Implement reconciliation queries.
14. Implement outbox events.
15. Add integration tests around all posting templates.

Minimum test cases:

```text
grant points increases available
placing bet decreases available and increases reserved
cannot place bet with insufficient available
retry place bet with same idempotency key returns same bet
retry place bet with different body returns conflict
cancel bet releases reserved
void bet releases reserved
winning bet consumes reserved and credits payout
losing bet consumes reserved
push returns reserved
settling same bet twice fails/idempotently returns original
ledger transactions always balance
cached balances match postings
concurrent placements cannot overspend
```

The key design decision is this:

> Treat private points as a real ledger asset even though they are not real money. That gives you correctness, auditability, and a clean migration path if the platform ever supports regulated value later.
