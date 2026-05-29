# Specialist Review Dispatch Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:dispatching-parallel-agents` for the review wave and `superpowers:verification-before-completion` before claiming synthesis is complete. Specialist role guidance comes from local `voltagent-local` skill files under `/Users/mauroberlanda/.codex/plugins/cache/voltagent-local/voltagent-subagents/1.0.0/skills/`.

**Goal:** Run deeper, specialist-led reviews across Adivento's architecture, code correctness, product strategy, UX design, and mobile app direction, then synthesize findings into a prioritized implementation backlog.

**Architecture:** Use a scatter-gather review model. Each specialist gets a read-only review family, a disjoint report file, and a strict output schema. The lead agent coordinates inputs, prevents duplicated scope, and merges findings into one synthesis report and backlog update proposal.

**Tech Stack:** Rails 8, PostgreSQL, Redis/SSE, Minitest, Playwright, markdown docs, local VoltAgent specialist skill references, Codex multi-agent tooling.

---

## Local Plugin / Role Inventory

`voltagent-local` is present in the local Codex plugin cache:

```text
/Users/mauroberlanda/.codex/plugins/cache/voltagent-local/voltagent-subagents/1.0.0/skills/
```

Use these specialist skill files as role guidance:

| Review family | VoltAgent role file |
|---------------|---------------------|
| Meta orchestration | `multi-agent-coordinator/SKILL.md` |
| Architecture | `architect-reviewer/SKILL.md` |
| Rails/backend code | `rails-expert/SKILL.md`, `code-reviewer/SKILL.md` |
| Market mechanics and financial correctness | `fintech-engineer/SKILL.md`, `quant-analyst/SKILL.md` |
| Data model and database performance | `postgres-pro/SKILL.md`, `database-optimizer/SKILL.md` |
| Security, trust, compliance | `security-auditor/SKILL.md`, `compliance-auditor/SKILL.md`, `risk-manager/SKILL.md` |
| Product strategy and roadmap | `product-manager/SKILL.md`, `competitive-analyst/SKILL.md` |
| UX research and information architecture | `ux-researcher/SKILL.md` |
| UI / visual design system | `ui-designer/SKILL.md`, `ui-ux-tester/SKILL.md` |
| Mobile app design and native strategy | `mobile-app-developer/SKILL.md`, `expo-react-native-expert/SKILL.md`, `flutter-expert/SKILL.md` |
| QA and release confidence | `qa-expert/SKILL.md`, `test-automator/SKILL.md` |
| DevOps and operability | `devops-engineer/SKILL.md`, `sre-engineer/SKILL.md` |
| Documentation quality | `documentation-engineer/SKILL.md`, `technical-writer/SKILL.md` |

---

## Review Output Contract

Each specialist writes exactly one report:

```text
docs/reviews/2026-05-29-deep-review/<family>.md
```

Each report must use this structure:

```markdown
# <Family> Deep Review

## Scope
- Files/docs inspected
- Explicitly out of scope

## Top Findings
| Priority | Finding | Evidence | Recommended next task |
|----------|---------|----------|------------------------|

## Detailed Notes

## Open Questions

## Backlog Candidates
| ID suggestion | Task | Size | Dependencies | Acceptance check |
```

Priority levels:
- `P0`: correctness, security, or trust issue that can corrupt balances, payouts, auth, or operator control.
- `P1`: major product/UX/architecture issue that blocks credible demo or near-term roadmap.
- `P2`: meaningful quality, maintainability, or adoption improvement.
- `P3`: polish or longer-horizon opportunity.

Evidence requirement:
- Cite exact local files, docs, routes, services, tests, or missing artifacts.
- Avoid speculative findings unless clearly labeled as a hypothesis.

---

## Dispatch Waves

### Wave 0: Coordinator Setup

**Lead:** `multi-agent-coordinator`

**Purpose:** Confirm scope, assign agents, and prepare result aggregation.

**Reads:**
- `docs/INDEX.md`
- `.claude/tasks/ATTENTION.md`
- `docs/wiki/tech-debt-backlog.md`
- `docs/wiki/UX_BACKLOG.md`
- `docs/product/BACKLOG.md`
- `docs/design/`

**Writes:**
- `docs/reviews/2026-05-29-deep-review/README.md`

**Output:** Review map, report index, and synthesis checklist.

### Wave 1: Independent Deep Reviews

Run these in parallel. Each agent owns only its report file.

| Agent | Family | Primary questions | Report |
|-------|--------|-------------------|--------|
| A1 | Architecture | Are Rails modular-monolith boundaries, ADRs, service seams, hot/cold storage, and mechanism abstractions coherent and evolvable? | `architecture.md` |
| A2 | Rails/code correctness | What are the highest-risk bugs, concurrency issues, lifecycle gaps, and test blind spots in controllers/services/models? | `code-correctness.md` |
| A3 | Market mechanics | Do CLOB, LMSR, parimutuel, fixed-odds, settlement, cashout, fees, and ledger semantics preserve financial invariants? | `market-mechanics.md` |
| A4 | Data/Postgres | Are migrations, constraints, indexes, query patterns, locks, and aggregation paths correct and performant enough for the roadmap? | `data-postgres.md` |
| A5 | Security/trust/compliance | Are auth, RBAC, JWT/session flows, auditability, operator actions, settlement transparency, and fantasy-money safety controls adequate? | `security-trust.md` |
| A6 | Product/roadmap | Are product backlog priorities, feature dependencies, MVP credibility gaps, competitive parity, and business loops correctly ordered? | `product-roadmap.md` |
| A7 | UX research / IA | Do user journeys, information architecture, market discovery, profile, onboarding, settlement explanations, and trust flows match user needs? | `ux-research-ia.md` |
| A8 | UI visual design | Are design system, visual hierarchy, responsive behavior, accessibility, and interaction affordances polished and internally consistent? | `ui-design.md` |
| A9 | Mobile app design | What should the mobile experience be: responsive web, Turbo Native, React Native/Expo, Flutter, or native? What mobile-specific flows are needed? | `mobile-design.md` |
| A10 | QA/E2E/release | Does test coverage match risk? Are E2E flows, CI gates, browser matrix, fixtures, and validation scripts sufficient? | `qa-release.md` |
| A11 | DevOps/operability | Are Docker, production-mode E2E, Redis/SSE, background jobs, logs, health checks, and deployment assumptions operationally sound? | `devops-operability.md` |
| A12 | Docs/backlog hygiene | Are docs, plans, ADRs, work log, backlog IDs, and handoff artifacts consistent and actionable? | `docs-handoff.md` |

### Wave 2: Cross-Cutting Synthesis

**Lead:** parent coordinator with optional `knowledge-synthesizer` role guidance.

**Inputs:** All Wave 1 reports.

**Writes:**
- `docs/reviews/2026-05-29-deep-review/synthesis.md`
- Proposed updates to `.claude/tasks/ATTENTION.md`
- Proposed updates to `docs/wiki/tech-debt-backlog.md`
- Proposed updates to `docs/wiki/UX_BACKLOG.md`
- Proposed new specs/plans list, without implementing them.

**Synthesis rules:**
1. Merge duplicate findings by root cause.
2. Prefer correctness/trust issues over visual polish.
3. Distinguish "must fix before demo", "should plan next", and "future strategy".
4. Convert findings into granular backlog candidates with acceptance checks.
5. Keep implementation tasks small enough for one PR each.

---

## Shared Specialist Prompt

```text
You are working in /private/tmp/adivento-specialist-reviews.

This is a read-only deep review task unless your assigned report file is explicitly in your write scope. Do not modify application code. Do not revert or clean up unrelated local changes.

Start by reading:
- CLAUDE.md
- docs/INDEX.md
- .claude/tasks/ATTENTION.md
- docs/wiki/tech-debt-backlog.md
- docs/wiki/UX_BACKLOG.md

Write exactly one report to:
docs/reviews/2026-05-29-deep-review/<family>.md

Use the required report structure from this dispatch plan. Cite exact files and evidence. Return a brief summary and the path written.
```

---

## Execution Checklist

- [ ] Create `docs/reviews/2026-05-29-deep-review/README.md` with this dispatch map.
- [ ] Spawn Wave 1 specialists in parallel using the prompts above.
- [ ] Wait for all Wave 1 reports.
- [ ] Commit each specialist report separately.
- [ ] Create `synthesis.md` with merged findings and a recommended execution sequence.
- [ ] Commit synthesis separately.
- [ ] Push `codex/specialist-deep-reviews` and create a dedicated PR.

