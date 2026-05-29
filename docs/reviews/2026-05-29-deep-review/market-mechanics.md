# Market Mechanics Deep Review

## Scope

Reviewed the market-mechanics documentation and implementation for economic correctness, ledger semantics, fee accounting, settlement, cashout/buyback, CLOB sell orders, LMSR positions, parimutuel refunds, and conservation/overpay risks.

Primary evidence came from `CLAUDE.md`, `docs/INDEX.md`, `docs/wiki/market-mechanisms.md`, `docs/wiki/tech-debt-backlog.md`, ADRs 0003/0009/0010/0011/0013/0014, specs `2026-05-26-betslip-cashout.md`, `2026-05-26-binary-line-invariants.md`, `2026-05-27-pluggable-market-mechanisms.md`, `2026-05-27-clob-order-book.md`, market services under `app/services`, ledger-related models under `app/models`, and corresponding service/model tests under `test/`.

## Top Findings table with Priority/Finding/Evidence/Recommended next task

| Priority | Finding | Evidence | Recommended next task |
|---|---|---|---|
| P0 | CLOB settlement overpays after sell/cashout fills because sold contracts are still paid as winners. | `Settlement::ClobSettlementHandler` pays every winning-side order with `filled_quantity > 0` and does not filter or net `direction` (`app/services/settlement/clob_settlement_handler.rb:28-40`). Sell fills create filled sell orders and credit the seller proceeds (`app/services/clob/order_matching_service.rb:198-232`). `NetPositionService` already defines net as filled buys minus filled sells (`app/services/clob/net_position_service.rb:5-8`). The backlog independently records TD-018 with the same overpay risk (`docs/wiki/tech-debt-backlog.md:158-163`). | Replace CLOB settlement with a net-position payout path, add a regression where a user buys YES, sells all YES, YES wins, and receives no settlement payout. |
| P0 | CLOB sell orders do not reserve contracts, so one user can list or fill sells exceeding holdings. | Sell validation checks current net position only at order creation (`app/services/clob/order_matching_service.rb:72-75`); sell orders do not reserve position (`app/models/order.rb:20-21` returns zero reserved for sells); matching does not revalidate seller net under lock before each sell fill (`app/services/clob/order_matching_service.rb:88-100`, `198-232`). Backlog TD-019 documents the same negative-position risk (`docs/wiki/tech-debt-backlog.md:167-172`). | Add contract reservation semantics for open sell orders or compute available-to-sell as `filled_buys - filled_sells - open_sell_unfilled`; recheck under lock at fill time. |
| P1 | Ledger semantics are not conservation-safe for CLOB fills: `ORDER_FILL_CREDIT` is a ledger credit without a matching wallet credit. | ADR-0003 says wallet balances are fast reads and ledger entries preserve auditability (`docs/adr/ADR-0003-fantasy-wallet-ledger-first.md:9-14`). In cross-side CLOB fills, maker reserved funds are reduced but `available_minor` is not increased (`app/services/clob/order_matching_service.rb:160-164`), then a credit ledger entry is written for the maker (`app/services/clob/order_matching_service.rb:172-176`). Tests only assert entry existence, not wallet/ledger reconciliation (`test/services/clob/order_matching_service_test.rb:103-123`). | Define a ledger taxonomy that separates cash movements from position acquisition, then update CLOB fill entries and leaderboard/P&L consumers accordingly. Add wallet-vs-ledger conservation tests per mechanism. |
| P1 | Fixed-odds cashout fee accounting double-counts the fee in the ledger relative to wallet movement. | Cashout quote computes gross, fee, and net (`app/services/cashout_quote_service.rb:12-14`). Execution credits only `net_payout_minor` to wallet (`app/services/cashout_execution_service.rb:12-14`) but writes `BET_CASHOUT_PAYOUT` for net and a separate `BET_CASHOUT_FEE` debit (`app/services/cashout_execution_service.rb:17-35`). The test asserts wallet +1980 while ledger contains +1980 and -20, producing ledger net +1960 for a wallet +1980 movement (`test/services/cashout_execution_service_test.rb:26-43`). | Decide whether payout ledger should be gross with fee debit, or net with fee only in metadata. Make wallet delta equal ledger credit-minus-debit for the cashout transaction. |
| P1 | Parimutuel takeout is audit-only, not ledgered, and payout rounding leaves unallocated pool dust. | Spec requires all stake/fee/payout/refund financial transactions to write ledger entries (`docs/specs/2026-05-27-pluggable-market-mechanisms.md:41`) and explicitly lists `PARIMUTUEL_TAKEOUT` (`docs/specs/2026-05-27-pluggable-market-mechanisms.md:153-164`). Implementation computes `takeout_minor` but only writes an `AuditEvent` (`app/services/parimutuel/parimutuel_settlement_service.rb:25-51`). Winner payouts use `floor` per entry (`app/services/parimutuel/parimutuel_settlement_service.rb:29-44`) with no remainder allocation or ledger row for dust. Tests validate only formula/refund success, not takeout ledger or total payout conservation (`test/services/parimutuel/parimutuel_settlement_service_test.rb:18-39`). | Add `PARIMUTUEL_TAKEOUT` ledger accounting and an explicit rounding policy: largest-remainder allocation, house dust entry, or deterministic residual carry. Test total credits + takeout + dust equals total pool. |
| P2 | LMSR implementation is buy-only despite the spec describing sell trades, so positions can only grow and the subsidy guard is mostly forward-looking. | Spec allows negative quantity to sell and defines sell credit/fee entries (`docs/specs/2026-05-27-pluggable-market-mechanisms.md:118-136`). Service rejects non-positive quantity (`app/services/lmsr/lmsr_trade_service.rb:18-20`), only increments `lmsr_q_yes/q_no` (`app/services/lmsr/lmsr_trade_service.rb:68-75`), and tests state buy-only means realized loss does not change on standard buys (`test/services/lmsr/lmsr_trade_service_test.rb:64-70`). | Either amend the spec/docs to state LMSR v1 is buy-only, or implement sell trades with position decrement, `LMSR_TRADE_CREDIT`, sell fee accounting, and subsidy outflow tests. |
| P2 | Mechanism docs are stale in financially relevant places. | Product wiki says CLOB cashout is not implemented and LMSR payouts are not implemented (`docs/wiki/market-mechanisms.md:31-48`), while INDEX says LMSR positions and CLOB sell/buyback are done (`docs/INDEX.md:126-129`). Source confirms `ClobCashoutService`, `OperatorBuybackService`, and `LmsrSettlementHandler` exist. | Update `docs/wiki/market-mechanisms.md` to match current source and keep known gaps linked to TD-018/TD-019 and any LMSR sell decision. |

## Detailed Notes

### Cross-mechanism invariants

The intended invariant is ledger-first auditability: wallet balances are fast reads, and financial transitions should be reconstructable from `ledger_entries` and `audit_events` (`docs/adr/ADR-0003-fantasy-wallet-ledger-first.md:9-14`). The pluggable mechanism spec strengthens this: all stake, fee, payout, and refund movements should write `LedgerEntry` rows (`docs/specs/2026-05-27-pluggable-market-mechanisms.md:41`).

That invariant is not consistently testable today because `LedgerEntry` validates shape only (`app/models/ledger_entry.rb:1-7`) and there are no per-service conservation assertions that compare wallet deltas with ledger net deltas. This matters most in CLOB and cashout, where some ledger rows represent position accounting rather than wallet cash movement, but use `direction: credit/debit` like cash rows.

### Fixed-odds and cashout

`BetPlacementService` charges the full stake from wallet, stores `fee_minor` in bet metadata, and writes one `BET_STAKE` debit for the full stake (`app/services/bet_placement_service.rb:12-51`). That is internally coherent as long as fee revenue is derived from metadata or a separate house ledger is not required.

Cashout is less coherent. `CashoutQuoteService` calculates gross, fee, and net (`app/services/cashout_quote_service.rb:12-14`). `CashoutExecutionService` credits only net to wallet (`app/services/cashout_execution_service.rb:12-14`), but writes a net payout credit plus a separate fee debit (`app/services/cashout_execution_service.rb:17-35`). The current test locks in wallet +1980 and ledger +1980/-20 (`test/services/cashout_execution_service_test.rb:26-43`). For ledger reconstruction, that makes the transaction look 20 minor units lower than the actual wallet movement.

The existing backlog already flags missing wallet locks in fixed-odds placement, void, cashout, and settlement (`docs/wiki/tech-debt-backlog.md:113-118`). That is a real double-spend risk, but it is already well captured as TD-013.

### CLOB order book, sell orders, and buyback

The original buy-vs-buy CLOB flow reserves buy order funds (`app/services/clob/order_matching_service.rb:61-70`) and on fill releases both parties' reservations (`app/services/clob/order_matching_service.rb:160-164`). It also writes `ORDER_FILL_STAKE` for taker and `ORDER_FILL_CREDIT` for maker (`app/services/clob/order_matching_service.rb:166-176`), but only the taker fee updates wallet available (`app/services/clob/order_matching_service.rb:180-188`). If `ORDER_FILL_CREDIT` is intended as a cash credit, wallet is missing a credit. If it is intended as position acquisition, then its ledger direction/name is misleading and downstream P&L can overstate returns.

Sell orders were added as pure exit orders. A sell order validates net holdings once (`app/services/clob/order_matching_service.rb:72-75`), matches same-side buy orders (`app/services/clob/order_matching_service.rb:105-145`), credits seller proceeds, and debits buyer stake via ledger (`app/services/clob/order_matching_service.rb:198-228`). `ClobCashoutService` wraps this as a sell limit order (`app/services/clob/clob_cashout_service.rb:17-36`), while `OperatorBuybackService` posts operator buy orders at an inferred mid-price (`app/services/clob/operator_buyback_service.rb:20-52`).

Two high-risk issues follow. First, unfilled sell orders do not reserve contracts: `Order#reserved_minor` is zero for sells (`app/models/order.rb:20-21`), and `NetPositionService` subtracts only filled sells (`app/services/clob/net_position_service.rb:5-8`). Second, CLOB settlement pays all filled winning-side orders regardless of direction (`app/services/settlement/clob_settlement_handler.rb:28-40`). After a user sells a winning contract, both the seller's filled sell order and the buyer's filled buy order can be counted unless settlement switches to net positions.

### LMSR

The current LMSR math uses the standard cost function (`app/services/lmsr/lmsr_pricing_service.rb:9-16`) and derives `b` from subsidy (`app/services/lmsr/lmsr_pricing_service.rb:26-29`; `app/models/market.rb:118-122`). Trades lock the market before pricing and updating quantities (`app/services/lmsr/lmsr_trade_service.rb:21-23`, `68-73`), debit wallet by cost plus fee (`app/services/lmsr/lmsr_trade_service.rb:35-66`), and upsert positions (`app/services/lmsr/lmsr_trade_service.rb:96-100`). Settlement pays winning `LmsrPosition` rows at 100 minor units per contract (`app/services/settlement/lmsr_settlement_handler.rb:38-63`).

The main correctness gap is product-contract mismatch: the spec describes buy and sell trades, including sell credit entries (`docs/specs/2026-05-27-pluggable-market-mechanisms.md:118-136`), but implementation and tests are explicitly buy-only (`app/services/lmsr/lmsr_trade_service.rb:18-20`; `test/services/lmsr/lmsr_trade_service_test.rb:64-70`). Buy-only LMSR can still be economically bounded by the cost function plus subsidy, but the `lmsr_realized_loss_minor` guard is not exercising the settlement loss path; it is only meaningful for future sell/outflow handling.

### Parimutuel

Stake placement is straightforward: wallet is locked, debited, a `PARIMUTUEL_STAKE` ledger row is written, then the market pool column is incremented under lock (`app/services/parimutuel/parimutuel_pool_service.rb:11-25`). Settlement computes total pool, winning pool, takeout, and payout ratio (`app/services/parimutuel/parimutuel_settlement_service.rb:15-27`). If winning pool is zero, all stake ledger entries for the market are refunded (`app/services/parimutuel/parimutuel_settlement_service.rb:70-81`), matching the spec's no-takeout refund rule (`docs/specs/2026-05-27-pluggable-market-mechanisms.md:155-156`).

The gaps are accounting completeness and rounding. Takeout is not a ledger entry despite the spec (`docs/specs/2026-05-27-pluggable-market-mechanisms.md:153-164`); it is only an audit event (`app/services/parimutuel/parimutuel_settlement_service.rb:46-51`). Winner payouts floor each individual payment (`app/services/parimutuel/parimutuel_settlement_service.rb:34`), but there is no residual/dust policy. This can leave minor units neither credited to winners nor explicitly booked as operator takeout/dust.

### Tests

The tests cover happy-path mechanics for CLOB matching, CLOB sell fills, net position arithmetic, LMSR buys/positions, fixed-odds settlement/cashout, and parimutuel basic settlement. The missing tests map directly to the conservation risks:

- CLOB settlement after a full sell/cashout of the winning side.
- Multiple open CLOB sell orders against the same position and fill-time revalidation.
- Wallet delta equals ledger net delta for fixed-odds cashout.
- CLOB fill ledger taxonomy does not count position acquisition as cash return.
- Parimutuel total pool conservation including takeout and rounding dust.
- LMSR spec decision test: sell rejected by design, or sell implemented with position decrement.

## Open Questions

1. Should ledger entries represent only wallet cash movements, or may they also represent non-cash position acquisition? The answer determines whether `ORDER_FILL_CREDIT` should stay, be renamed/retyped, or be removed from P&L return calculations.
2. For CLOB buy-vs-buy matches, is the maker supposed to receive a cash credit, or only a contract position? Current wallet behavior says contract only; current ledger naming says cash credit.
3. For fixed-odds cashout, should `BET_CASHOUT_PAYOUT` be gross payout with a separate fee debit, or net payout with fee captured only in metadata?
4. Should LMSR v1 intentionally remain buy-only, or is the spec's negative-quantity sell path still a product requirement?
5. What is the desired parimutuel rounding policy for leftover minor units: allocate by largest remainder, book to operator dust/takeout, or carry as market residual?
6. Is operator buyback meant to introduce deliberate operator inventory/risk, and if so should those operator-held CLOB positions be visible in risk reporting and excluded from "no house position" claims?

## Backlog Candidates table with ID suggestion/Task/Size/Dependencies/Acceptance check

| ID suggestion | Task | Size | Dependencies | Acceptance check |
|---|---|---|---|---|
| TD-018 | Settle CLOB by net positions, not raw filled orders. | M | Existing `Clob::NetPositionService`; decision on position aggregation query shape. | Regression: buy 10 YES, sell 10 YES, settle YES; seller gets 0 settlement, buyer gets 1000, total winning payout equals net winning contracts * 100. |
| TD-019 | Reserve or encumber CLOB contracts for open sell orders. | M | CLOB position model/query decision; concurrency locking approach. | A user with 10 YES cannot place two open sell orders for 10 YES each; fill-time validation prevents negative net positions under concurrent matches. |
| TD-023 | Normalize ledger taxonomy and conservation tests across mechanisms. | L | Decision on cash-only vs position ledger semantics; leaderboard/profile P&L consumers. | For each service, tests assert wallet delta equals cash ledger net delta, and non-cash position entries are separately typed or excluded from cash P&L. |
| TD-024 | Fix fixed-odds cashout payout/fee ledger semantics. | S | Ledger taxonomy decision from TD-023. | Cashout transaction ledger reconstructs the exact wallet delta; tests cover gross+fee and/or net-only chosen policy. |
| TD-025 | Add parimutuel takeout ledger and rounding residual policy. | S | Rounding policy decision. | Settlement test asserts total winner credits + takeout ledger + residual/dust entry equals total pool; zero-winning-pool path writes only refunds and no takeout. |
| TD-026 | Resolve LMSR sell-trade contract mismatch. | M | Product decision: buy-only v1 or full sell support. | If buy-only: docs/specs updated and tests assert negative quantity is rejected by design. If sell-enabled: positions decrement, wallet credits net of fee, and subsidy outflow guard is covered. |
| TD-027 | Refresh market mechanism wiki after PR #35/#36. | S | Completion or explicit listing of TD-018/TD-019 status. | `docs/wiki/market-mechanisms.md` matches source: LMSR settlement payouts exist, CLOB cashout/sell/buyback exist, remaining gaps link to current backlog. |
