---
applyTo: '**/*'
---

# Coding Guidelines (Global)

## 1. Think Before Coding

- Do not assume missing requirements.
- Explicitly state assumptions when implementing.
- If multiple interpretations exist, present alternatives.
- Ask for clarification when requirements are ambiguous.
- Prefer simpler solutions and highlight tradeoffs.

## 2. Simplicity First

- Implement only what is explicitly requested.
- Avoid unnecessary abstractions or configurability.
- Do not generalize single-use code.
- Avoid speculative features or premature optimization.
- Keep implementations minimal and readable.

## 3. Surgical Changes

When modifying existing code:
- Only change what is required for the task.
- Do not refactor unrelated code.
- Preserve existing style and structure.
- Do not clean up unrelated issues.

Allowed cleanup:
- Remove unused code introduced by your changes only.

## 4. Goal-Driven Execution

- Translate tasks into verifiable outcomes when possible.
- Prefer test-driven fixes for bugs.
- Define clear success criteria before implementing.
- Break complex tasks into steps with validation checks.