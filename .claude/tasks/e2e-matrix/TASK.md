# Task: e2e-matrix

Expand E2E coverage with role/permission matrix, settlement scenarios, and error paths.
Also includes framework-agnostic TEST_MATRIX.md for porting.

The work builds on the existing `e2e/playwright/tests/workflow.spec.js` and adds:
- `helpers/common.js` — shared constants and helpers extracted from workflow.spec.js and api.js
- `permissions.spec.js` — role/permission access matrix (26 scenarios)
- `settlement-scenarios.spec.js` — settlement outcome matrix (8 scenarios)
- `error-paths.spec.js` — error path inventory (18 scenarios)
- `TEST_MATRIX.md` — framework-agnostic reference document for porting the suite
