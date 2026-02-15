# Approval Document Template

Create: `scratchpad/approvals/approval-[timestamp].md`

```markdown
# Approval Request: [Action Summary]

**Created**: [ISO-8601 timestamp]
**Category**: [Financial/Data/Production/Communication/Security]
**Agent Task**: [Related task name if any]

---

## Proposed Action
[Detailed description]

### Changes:
- [ ] Change 1
- [ ] Change 2
- [ ] Change 3

---

## Context
**Goal**: [What we're trying to achieve]
**Reasoning**: [Why this way]

**Alternatives**:
1. [Alt 1] - [Why not]
2. [Alt 2] - [Why not]

---

## Risk Assessment

**Irreversibility**: [Can be undone? How?]
**Blast Radius**: [What could break?]
**Impact**: [Scope of effect]
**Rollback Plan**: [Recovery steps]
**Worst Case**: [Maximum damage]

---

## Preview
### Before:
```
[Current state]
```

### After:
```
[Expected state]
```

---

## Decision

**Status**: PENDING
**Reviewed by**: [To be filled]
**Decision**: [To be filled]
**Timestamp**: [To be filled]
**Conditions**: [To be filled]

---

## Execution Log
[Will be filled after action taken]
```

## User-Facing Output

```
APPROVAL CHECKPOINT

Category: [Financial/Data/Production/etc]
Risk Level: [Low/Medium/High/Critical]

Proposed Action:
[One sentence summary]

I need your approval to proceed because:
[Reason this requires human oversight]

Full details: scratchpad/approvals/approval-[timestamp].md

Please review and respond:
- APPROVE to proceed
- MODIFY to change approach
- DEFER to decide later
- REJECT to cancel

What's your decision?
```

## Audit Trail Entry

After execution, append to `~/.claude/approvals-log.jsonl`:

```json
{
  "timestamp": "ISO-8601",
  "category": "production",
  "action": "description",
  "approved_by": "user",
  "decision": "approved",
  "executed": true,
  "result": "success",
  "file": "scratchpad/approvals/approval-timestamp.md"
}
```

## Examples

### Example 1: Production Deployment
```
Category: Production
Action: Deploy v2.0 to production
Risk: Medium (can rollback within 5 minutes)
Approval needed: Breaking API changes affect 3 clients
```

### Example 2: Data Deletion
```
Category: Data
Action: Delete user data for GDPR request
Risk: High (irreversible after 30 days)
Approval needed: Affects user ID 12345, includes all history
```

### Example 3: Financial
```
Category: Financial
Action: Refund $500 to customer
Risk: Low (can be logged for reconciliation)
Approval needed: Amount over $100 threshold
```
