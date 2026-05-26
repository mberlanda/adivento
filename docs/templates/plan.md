# [Feature Name] Implementation Plan

<!-- File location: docs/superpowers/plans/YYYY-MM-DD-feature-name.md -->
<!-- Written AFTER the spec is approved. Describes HOW. -->
<!-- Each task = one atomic commit. Each step = one verifiable action. -->

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use `- [ ]` for tracking.

**Goal:** [One sentence — same as spec goal]

**Architecture:** [2-3 sentences on approach, key classes, transaction boundaries]

**Tech Stack:** Rails 8, Minitest, existing patterns (see docs/INDEX.md for file map)

**Spec:** [link to spec file]

---

## File Map

**Create:**
- `app/services/foo_service.rb`
- `test/services/foo_service_test.rb`

**Modify:**
- `app/controllers/bar_controller.rb` — add X action
- `config/routes.rb` — add route for X
- `test/integration/bar_test.rb` — add tests

---

## Task 1: [Component Name]

**Files:**
- Create: `exact/path/to/file.rb`
- Modify: `exact/path/to/existing.rb`
- Test: `test/exact/path/to/test.rb`

- [ ] **Step 1.1: Write the failing test**

```ruby
# test/services/foo_service_test.rb
test "does the thing" do
  result = FooService.call(input: "x")
  assert_equal "expected", result
end
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
bin/rails test test/services/foo_service_test.rb -v
```
Expected: FAIL with `uninitialized constant FooService`

- [ ] **Step 1.3: Implement minimal code**

```ruby
# app/services/foo_service.rb
class FooService
  def self.call(input:)
    "expected"
  end
end
```

- [ ] **Step 1.4: Run test to verify it passes**

```bash
bin/rails test test/services/foo_service_test.rb -v
```
Expected: PASS

- [ ] **Step 1.5: Commit**

```bash
git add app/services/foo_service.rb test/services/foo_service_test.rb
git commit -m "feat: add FooService"
```

---

## Task 2: [Next Component]

<!-- Repeat pattern. Never use placeholders — every step has real code. -->

---

## Task N: Update docs

- [ ] Append entry to `docs/WORK_LOG.md` with what was built and commit refs
- [ ] Update `docs/INDEX.md` implementation status (move items from TODO to DONE)
- [ ] Commit: `git commit -m "docs: update INDEX and WORK_LOG after [feature]"`

---

## Self-Review Checklist
- [ ] Every spec invariant has a test
- [ ] Every write action has an AuditEvent
- [ ] Every ledger write has correct entry_type and direction
- [ ] Full test suite passes: `bin/rails test`
- [ ] No placeholder steps remain
