# Task Artifacts

Each multi-session or agent-dispatched task gets a folder here:

```
.claude/tasks/<task-id>/
  TASK.md       restatement of what was asked (one paragraph, immutable)
  PLAN.md       numbered checklist — mark [x] as steps complete
  FINDINGS.md   append-only: decisions, surprises, results
  Q&A.md        append-only: blocking questions + answers
```

## Naming
Use the plan slug: e.g. `2026-05-26-betslip-cashout`, `2026-06-01-binary-invariants`.

## Resume protocol
If a task folder exists, read all four files before doing anything. Continue from the first unchecked step in PLAN.md. Do not re-explain completed work.

## Q&A (blocking questions)
Append and stop — never spin on a missing decision:
```markdown
## Q: [short title] — YYYY-MM-DD
**Context:** what you were doing
**Tried:** what you already attempted or inferred
**Need:** exact decision or information required
```
After a `## A:` block is added by the user, resume from the blocked step.
