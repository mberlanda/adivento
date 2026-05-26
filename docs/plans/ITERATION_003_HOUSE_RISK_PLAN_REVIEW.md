# Iteration 003 Plan Review

## Findings
1. V1 misses explicit formula definitions in implementation contract.
2. V1 does not define fee handling impact on liability.
3. V1 lacks permission keys for risk read and bet placement.
4. V1 does not define minimal schema needed for forward compatibility.

## Required Revisions
1. Document formulas and expose them in spec.
2. Record fee as explicit field on each bet and ledger entry.
3. Add permissions:
- `bet.place`
- `risk.read`
4. Include market mechanism and risk caps in schema.
5. Ensure API responses expose risk numbers clearly for operations.
