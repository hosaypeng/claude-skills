# Removal and Iteration Plan Template

## Priority Levels

- **P0**: Immediate removal (security risk, significant cost, blocking other work)
- **P1**: Remove in current sprint
- **P2**: Backlog / next iteration

---

## Safe to Remove Now

### Item: [Name/Description]

| Field | Details |
|-------|---------|
| **Location** | `path/to/file.ts:line` |
| **Rationale** | Why this should be removed |
| **Evidence** | Unused (no references), dead feature flag, deprecated API |
| **Impact** | None / Low - no active consumers |
| **Deletion steps** | 1. Remove code 2. Remove tests 3. Remove config |
| **Verification** | Run tests, check no runtime errors, monitor logs |

---

## Defer Removal (Plan Required)

### Item: [Name/Description]

| Field | Details |
|-------|---------|
| **Location** | `path/to/file.ts:line` |
| **Why defer** | Active consumers, needs migration, stakeholder sign-off |
| **Preconditions** | Feature flag off for 2 weeks, telemetry shows 0 usage |
| **Breaking changes** | List any API/contract changes |
| **Migration plan** | Steps for consumers to migrate |
| **Timeline** | Target date or sprint |
| **Owner** | Person/team responsible |
| **Validation** | Metrics to confirm safe removal (error rates, usage counts) |
| **Rollback plan** | How to restore if issues found |

---

## How to Find Unused Code

```bash
# Search for references
rg "functionName" --type ts
rg "ClassName" --type py

# Check exports used
rg "import.*from.*module"

# Find dead feature flags
rg "FEATURE_FLAG_NAME"
```

## Checklist Before Removal

- [ ] Searched codebase for all references (`rg`, `grep`)
- [ ] Checked for dynamic/reflection-based usage
- [ ] Verified no external consumers (APIs, SDKs, docs)
- [ ] Feature flag telemetry reviewed (if applicable)
- [ ] Tests updated/removed
- [ ] Documentation updated
- [ ] Team notified (if shared code)
- [ ] Removal is reversible (or backed up)

---

## Common Removal Candidates

| Type | How to Identify |
|------|-----------------|
| Dead code | No callers found via search |
| Deprecated APIs | Marked deprecated, replacement exists |
| Feature flags | Flag off for >30 days, no recent toggles |
| Old migrations | Already applied, past rollback window |
| Test fixtures | Only used by deleted tests |
| Config for removed features | References non-existent code |
| Commented-out code | If in git history, delete it |
