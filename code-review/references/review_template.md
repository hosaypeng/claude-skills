# Code Review Output Template

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

## Output Format

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

## Next Steps Template

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
