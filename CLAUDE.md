# Adivento — Agent Guidelines

## START HERE
Read `docs/INDEX.md` before any implementation work. It contains the project map, current status, file locations, fixtures cheat-sheet, and run commands. One file, under 200 lines.

---

## Coding rules

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think before coding
- State assumptions explicitly. If uncertain, surface the ambiguity — don't pick silently.
- If multiple interpretations exist, name them and pick the most reasonable one, then proceed.
- Simpler approach exists? Say so. Push back when warranted.

### 2. Simplicity first
- Minimum code that solves the problem. Nothing speculative.
- No abstractions for single-use code. No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

### 3. Surgical changes
- Touch only what you must. Don't "improve" adjacent code.
- Match existing style. Every changed line must trace to the request.
- Remove imports/variables YOUR changes made unused. Leave pre-existing dead code alone.

### 4. Goal-driven execution
- Transform tasks into verifiable goals before starting.
- Run tests. Check output. Don't claim success without evidence.

---

## Software development lifecycle

Every feature follows this sequence. Skip steps only when explicitly told to.

```
1. ADR (if architectural)   → docs/adr/ADR-NNNN-name.md
2. Spec                     → docs/specs/YYYY-MM-DD-name.md
3. Plan                     → docs/superpowers/plans/YYYY-MM-DD-name.md
4. Plan review              → docs/superpowers/plans/YYYY-MM-DD-name-review.md
5. Implement                → per plan, one commit per task
6. Verify                   → bin/rails test (must pass, 90% coverage)
7. Update docs              → WORK_LOG.md entry + INDEX.md status update
```

**Use the templates.** Every new doc starts from `docs/templates/`. Never imitate the legacy format of files in `docs/specs/` or `docs/plans/` — those carry a LEGACY header for a reason.

**When is an ADR needed?** When the decision affects multiple systems, is irreversible, or changes a cross-cutting constraint (auth, storage engine, data model shape). Bug fixes and UI additions don't need ADRs.

---

## Task artifacts (for multi-session work)

When a task will span multiple sessions or is handed to an agent loop, create a task folder:

```
.claude/tasks/<task-id>/
  TASK.md              ← restatement of what was asked (one paragraph)
  PLAN.md              ← numbered checkbox checklist with status markers
  FINDINGS.md          ← decisions made, results, surprises discovered
  Q&A.md               ← questions and answers (append-only, see below)
```

**Naming:** use the plan filename slug (e.g. `2026-05-26-betslip-cashout`) as the task-id.

**On session start:** if `.claude/tasks/<task-id>/` exists, read all four files first and continue from the first unchecked step in PLAN.md. Do not re-explain completed work.

**On session end / handoff:** mark completed steps `[x]`, write a brief FINDINGS.md entry for anything non-obvious discovered, leave PLAN.md pointing to the next step.

### Q&A — blocking questions
When genuinely blocked (missing information only the user can provide):
1. Append to `Q&A.md`:
   ```
   ## Q: [short title] — [date]
   **Context:** what you were doing
   **Tried:** what you already attempted
   **Need:** exactly what decision or information is required
   ```
2. Stop work on this task. Leave PLAN.md on the blocking step.
3. To resume after an answer is added, read the `## A:` block under the question and continue.

Do **not** use Q&A for things you can infer from the codebase, the spec, or `docs/INDEX.md`. Reserve it for genuine blockers.

---

## Docs maintenance obligation

After every implementation:
- **`docs/WORK_LOG.md`** — prepend a dated entry: what was built, key files, commit hash.
- **`docs/INDEX.md`** — move implemented items from TODO to DONE in the status table.
- **`docs/plans/ITERATION_005_MASTER_TODO_TREE.md`** — update plan/task statuses.

These updates are part of the task, not optional cleanup. Commit them with the message: `docs: update INDEX and WORK_LOG after [feature-name]`.

---

## Commit discipline
- One commit per logical unit (service, controller+routes, tests, docs). Not one big commit at the end.
- Message format: `type(scope): short description` — e.g. `feat(settlement): ...`, `test(backoffice): ...`, `docs: ...`
- Always `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

---

## Running the project
```bash
docker compose up -d db          # required before bin/rails test
bin/rails db:prepare             # create + migrate + seed
bin/rails test                   # full suite (90% coverage threshold)
bin/rails test path/to/file.rb   # single file
docker compose up -d             # full stack (web + db + redis)
```
