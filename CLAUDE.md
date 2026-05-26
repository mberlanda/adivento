# Adivento — Claude Working Instructions

## Session start: read this first

1. **Read `docs/INDEX.md`** — project overview, implementation status, file map, fixtures, run commands.
2. **Check `.claude/tasks/`** — if any task folder has an unfinished `PLAN.md` or unanswered `Q&A.md`, resume that task before starting new work.
3. **Check `docs/WORK_LOG.md`** — to understand what was recently built.

---

## Software Development Lifecycle

Every feature follows this sequence. Never skip steps — they are guardrails for sub-agent execution.

```
1. ADR         (if architectural choice)   → docs/adr/ADR-NNNN-*.md
2. Spec        (WHAT: contracts, invariants) → docs/specs/YYYY-MM-DD-*.md
3. Plan        (HOW: step-by-step tasks)   → docs/superpowers/plans/YYYY-MM-DD-*.md
4. Plan review (sanity check)              → docs/superpowers/plans/YYYY-MM-DD-*-review.md
5. Implement   (task by task, TDD)
6. Update docs (WORK_LOG + INDEX status)
```

**When to skip:**
- Skip ADR for pure feature work (no new architectural choice).
- Skip spec for trivial changes (<1 day, no new invariants or accounting).
- **Never skip the plan.** Plans are the primary guardrail for agent execution.

**Templates** for each doc type: `docs/templates/`

---

## Task artifacts (for multi-session and blocked work)

For any task that takes more than one session or may need to block for input, create a folder:

```
.claude/tasks/<task-id>/
  TASK.md         ← restatement of what was asked
  PLAN.md         ← numbered checklist with [ ] / [x] markers
  Q&A.md          ← blocking questions + answers (append-only)
```

### Starting a task
1. Create the folder and write `TASK.md` (what, why, done-criteria).
2. Write `PLAN.md` as a numbered checklist. Derive it from the superpowers plan if one exists.
3. Begin working through checklist items, marking `[x]` as you go.
4. Commit after each logical unit.

### Resuming a task
1. Read `TASK.md`, `PLAN.md`, `Q&A.md`.
2. Find the first unchecked `[ ]` item in `PLAN.md`.
3. Continue from there. No re-explaining needed.

### Blocking for input
When you cannot proceed without a decision only the user can make:
1. Append a `## Q:` block to `Q&A.md`:
   ```
   ## Q: [short label] — [date]
   **Context:** [what you were doing]
   **Tried:** [what you already considered]
   **Need:** [specific decision or information]
   ```
2. Stop. Do not guess. Do not continue with a placeholder.
3. When the user answers, they append `## A:` to `Q&A.md`. Resume from there.

---

## Coding principles

### 1. Think before coding
- State assumptions explicitly. If uncertain, stop and name the confusion.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.

### 2. Simplicity first
- Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked. No abstractions for single-use code.
- No error handling for impossible scenarios.
- If you wrote 200 lines and it could be 50, rewrite it.

### 3. Surgical changes
- Touch only what you must. Match existing style.
- Don't refactor things that aren't broken.
- Don't "improve" adjacent code while fixing something else.
- Every changed line should trace directly to the request.

### 4. TDD
- Write the failing test first. Run it. See it fail.
- Write minimal implementation. Run the test. See it pass.
- Run the full suite before committing.

### 5. Atomic commits
- One commit per logical unit (service, controller+routes, tests).
- Commit message: `type(scope): what and why` — e.g., `feat(settlement): add SettlementService`.
- Never commit with failing tests.

---

## Docs update obligation

After every feature implementation:
1. **Append to `docs/WORK_LOG.md`**: date, what was built, key files, commit refs.
2. **Update `docs/INDEX.md` status**: move items from TODO to Done, add new active plans.
3. Commit: `docs: update INDEX and WORK_LOG after [feature]`.

This keeps the docs authoritative for the next session. A stale INDEX.md misleads future agents.

---

## Adivento-specific patterns

### Write actions always produce audit events
```ruby
AuditEvent.create!(
  actor: current_user,
  action: "resource.verb",    # e.g., "market.settle", "bet.place"
  target_type: "ClassName",
  target_id: record.id,
  reason: params[:reason],    # optional but encouraged
  metadata: {}
)
```

### Ledger entries for every money movement
```ruby
LedgerEntry.create!(
  user: user,
  actor: actor,
  entry_type: "BET_WIN_PAYOUT",   # SCREAMING_SNAKE_CASE
  amount_minor: amount,
  direction: "credit",            # or "debit"
  metadata: { bet_id: bet.id, market_id: market.id }
)
```

### Hot storage projection after market state changes
```ruby
HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: "market.settle")
```

### Backoffice controllers: session auth + permission check
```ruby
module Backoffice
  class FooController < BaseController
    before_action -> { require_permission!("foo.manage") }
    # render HTML, redirect on success/error
  end
end
```

### Admin API controllers: JWT auth + permission check
```ruby
module Admin
  class FooController < BaseController
    before_action -> { require_permission!("foo.read") }
    # render json:, status:
  end
end
```

### Test: backoffice auth
```ruby
post "/signin", params: { email: users(:admin).email, password: "password123" }
```

### Test: admin API auth
```ruby
get "/admin/foo", headers: auth_headers_for(users(:admin)), as: :json
```

### Test: fixture bets interfere with settlement tests
```ruby
setup do
  @market.bets.delete_all   # remove fixture bets so only test-created bets are settled
end
```
