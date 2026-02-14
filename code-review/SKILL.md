---
name: code-review
version: 1.0.0
description: "Expert code review with senior engineer lens. Detects SOLID violations, security risks, test gaps, dependency issues, and proposes actionable improvements. Use when user says 'review my code', 'code review', 'check this PR', 'review these changes', or 'audit this diff'."
---

# Code Review

## Overview

Perform a structured review of current git changes with focus on correctness, security, architecture, test coverage, and maintainability. Default to review-only output unless the user asks to implement changes.

## Severity Levels

| Level | Name | Description | Action |
|-------|------|-------------|--------|
| **P0** | Critical | Security vulnerability, data loss risk, correctness bug | Must block merge |
| **P1** | High | Logic error, significant SOLID violation, performance regression, missing critical tests | Should fix before merge |
| **P2** | Medium | Code smell, maintainability concern, minor SOLID violation, test gap | Fix in this PR or create follow-up |
| **P3** | Low | Style, naming, minor suggestion | Optional improvement |

## Confidence Levels

For P0 and P1 findings, indicate certainty:

| Confidence | Meaning | Example |
|------------|---------|---------|
| **Confirmed** | Verified exploitable/broken | "SQL injection via unsanitized `userId` parameter" |
| **Likely** | High probability based on pattern | "Likely race condition in balance update (no locking)" |
| **Possible** | Needs investigation | "Possible N+1 query - verify with profiler" |

## Workflow

### 1) Preflight Context

Scope the changes:
```bash
bash ~/.claude/skills/code-review/scripts/preflight_context.sh
```

If needed, use `rg` to find related modules, usages, and contracts.

Identify:
- Entry points and ownership boundaries
- Critical paths (auth, payments, data writes, network)
- Public API surface changes

**Edge cases:**
- **No changes**: If `git diff HEAD` is empty, ask if user wants to review a specific commit range or branch comparison.
- **Large diff (>500 lines)**: Summarize by file first, then review in batches by module/feature area.
- **Mixed concerns**: Group findings by logical feature, not just file order.

### 2) Test Coverage Scan

Check if changed code has corresponding tests:

- **New functions/methods**: Is there a test file? Are key paths covered?
- **Modified logic**: Are existing tests updated to reflect changes?
- **Deleted code**: Are orphaned tests removed or updated?
- **Edge cases**: Are boundary conditions tested (null, empty, error paths)?

Use `rg` to find test files:
```bash
bash ~/.claude/skills/code-review/scripts/test_coverage_scan.sh
```

Flag as P1 if critical paths lack tests. Flag as P2 for non-critical gaps.

### 3) Dependency Audit

Check for dependency changes:

```bash
bash ~/.claude/skills/code-review/scripts/dependency_audit.sh
```

For new dependencies:
- Is the package actively maintained?
- Does it have known vulnerabilities? (check npm audit, pip-audit, cargo audit)
- Is it from a trusted source?
- Is the version pinned appropriately?

For version changes:
- Are there breaking changes in the changelog?
- Security patches should be P1 priority.

### 4) SOLID + Architecture Smells

Reference: `references/solid_checklist.md`

Look for:
- **SRP**: Modules with unrelated responsibilities
- **OCP**: Frequent edits to add behavior instead of extension points
- **LSP**: Subclasses that break expectations
- **ISP**: Wide interfaces with unused methods
- **DIP**: High-level logic tied to low-level implementations

When proposing refactors:
- Explain *why* it improves cohesion/coupling
- Outline a minimal, safe split
- For non-trivial changes, propose an incremental plan

### 5) Removal Candidates

Reference: `references/removal_plan.md`

Identify:
- Unused code (no references found via `rg`)
- Redundant implementations
- Feature-flagged code that's been off for extended periods
- Deprecated APIs still in codebase

Distinguish **safe delete now** vs **defer with plan**.

### 6) Security and Reliability Scan

Reference: `references/security_checklist.md`

Check for:
- **Injection**: SQL, NoSQL, command, XSS, SSRF, path traversal
- **Auth**: Missing AuthZ/AuthN checks, IDOR, tenant isolation gaps
- **Secrets**: API keys, tokens, credentials in code/logs
- **Race conditions**: TOCTOU, check-then-act, missing locks
- **Crypto**: Weak algorithms, hardcoded secrets, missing auth on encryption
- **Supply chain**: New untrusted dependencies, unpinned versions

Call out both **exploitability** and **impact**.

### 7) Code Quality Scan

Reference: `references/code_quality_checklist.md`

Check for:
- **Error handling**: Swallowed exceptions, missing async error handling
- **Performance**: N+1 queries, unbounded loops, missing pagination
- **Boundaries**: Null handling, empty collections, off-by-one, numeric limits
- **Breaking changes**: Public API modifications, schema changes, removed exports

### 8) Output Format

Structure your review as:

```markdown
## Code Review Summary

**Files reviewed**: X files, Y lines changed
**Test coverage**: [Adequate / Gaps identified / Missing]
**Dependencies**: [No changes / N new packages / Updates only]
**Overall assessment**: [APPROVE / REQUEST_CHANGES / COMMENT]

---

## Findings

### P0 - Critical
(none or list with confidence level)

### P1 - High
- **[file:line]** Brief title `[Confirmed/Likely/Possible]`
  - Description of issue
  - Suggested fix

### P2 - Medium
...

### P3 - Low
...

---

## Test Coverage Gaps
(list untested code paths if any)

## Dependency Notes
(new packages, version changes, audit findings)

## Removal Candidates
(if applicable)

## Breaking Changes
(API/schema changes affecting consumers)

## Additional Suggestions
(optional improvements, not blocking)
```

**Clean review**: If no issues found, explicitly state:
- What was checked
- Any areas not covered (e.g., "Did not verify database migrations")
- Residual risks or recommended follow-up

### 9) Next Steps

After presenting findings, ask user how to proceed:

```markdown
---

## Next Steps

I found X issues (P0: _, P1: _, P2: _, P3: _).

**How would you like to proceed?**

1. **Fix all** - Implement all suggested fixes
2. **Fix P0/P1 only** - Address critical and high priority issues
3. **Fix specific items** - Tell me which issues to address
4. **Create issues** - Open GitHub/GitLab issues for tracking
5. **No changes** - Review complete, no implementation needed

Please choose an option or provide specific instructions.
```

**Important**: Do NOT implement any changes until user explicitly confirms. This is a review-first workflow.

## Commit Hygiene (Optional Check)

If reviewing a PR with multiple commits:
- Are commits atomic (one logical change per commit)?
- Are commit messages descriptive (why, not just what)?
- Any fixup/squash candidates?

## References

| File | Purpose |
|------|---------|
| `references/solid_checklist.md` | SOLID smell prompts and refactor heuristics |
| `references/security_checklist.md` | Security, reliability, and supply chain risks |
| `references/code_quality_checklist.md` | Error handling, performance, boundaries, test coverage |
| `references/removal_plan.md` | Template for deletion candidates and follow-up plan |
