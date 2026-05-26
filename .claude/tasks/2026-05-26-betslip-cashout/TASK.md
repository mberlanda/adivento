# Task: Betslip + Cashout

Enable players to submit multi-item betslips via a quote-then-execute flow with idempotency, and to cashout open positions at a current fair value. The feature adds two persisted models (`BetslipQuote`, `BetslipExecution`), four service objects (`BetslipQuoteService`, `BetslipExecutionService`, `CashoutQuoteService`, `CashoutExecutionService`), and a set of JSON endpoints under the `web/` surface (session auth). All write paths are transactional. Stake debits are owned by the existing `BetPlacementService`; the betslip layer does not double-debit.

Spec: `docs/specs/2026-05-26-betslip-cashout.md`
Plan: `docs/superpowers/plans/2026-05-26-betslip-cashout.md`
