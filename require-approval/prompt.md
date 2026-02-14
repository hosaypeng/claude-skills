# Human Oversight Approval Task

You are executing the `/require-approval` skill to create a structured approval checkpoint.

## Philosophy

The article noted: "Human oversight patterns for high-stakes decisions" were missing.

Autonomous agents need clear checkpoints where human judgment is required:
- Before irreversible actions
- For high-stakes decisions
- When consequences are significant
- To maintain accountability

## Objectives

Create a structured approval workflow that provides full context for informed decision-making.

## When to Use This

### High-Stakes Categories

**Financial Operations**:
- Purchases over threshold
- Subscription changes
- Payment processing
- Refunds or chargebacks

**Data Operations**:
- Deleting databases or tables
- Dropping production data
- Irreversible migrations
- Bulk data modifications

**Production Deployments**:
- Production releases
- Infrastructure changes
- DNS modifications
- Security policy updates

**Public Communications**:
- Social media posts
- Public announcements
- Customer communications
- Legal/compliance documents

**Security Changes**:
- Permission modifications
- Access control changes
- API key rotations
- Authentication changes

## Process

### 1. Capture Proposed Action

Document exactly what the agent wants to do:
```markdown
## Proposed Action
[Clear description of the action]

### What will happen:
- [Specific change 1]
- [Specific change 2]
- [Specific change 3]

### Affected systems/data:
- [System/resource 1]
- [System/resource 2]
```

### 2. Provide Full Context

Explain why this action is needed:
```markdown
## Context
### Goal:
[What we're trying to achieve]

### Current state:
[What exists now]

### Desired state:
[What we want after action]

### Why this approach:
[Reasoning behind chosen method]

### Alternatives considered:
1. [Alternative 1] - Rejected because [reason]
2. [Alternative 2] - Rejected because [reason]
```

### 3. Assess Risks and Impact

Be transparent about consequences:
```markdown
## Risk Assessment

### ⚠️  Irreversibility:
[Can this be undone? If so, how?]

### 💥 Blast Radius:
[What could break if this goes wrong?]

### 📊 Impact:
- Users affected: [number/scope]
- Systems affected: [list]
- Downtime risk: [low/medium/high]

### 🔄 Rollback Plan:
[How to undo if needed]

### 🚨 Worst Case:
[What's the worst that could happen?]
```

### 4. Show Preview (if possible)

If the action can be previewed:
```markdown
## Preview

### Before:
[Current state snapshot]

### After:
[Expected state after action]

### Changes:
[Diff or summary of changes]
```

### 5. Request Approval

Present clear options:
```markdown
## Approval Request

Choose one:

1. ✅ APPROVE - Proceed with the action as described
2. 🔄 MODIFY - I want to change the approach
3. ⏸️  DEFER - Not now, ask me later
4. ❌ REJECT - Don't do this

Additional notes/conditions:
[Space for user input]
```

## Approval Document Format

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

## After Approval/Rejection

### If Approved:
1. Log the approval decision
2. Execute the action
3. Verify success
4. Update approval document with results
5. Archive for audit trail

### If Modified:
1. Update the proposal
2. Resubmit for approval
3. Log the iteration

### If Deferred:
1. Save state for later
2. Set reminder if requested
3. Don't execute

### If Rejected:
1. Log the rejection
2. Don't execute
3. Optionally suggest alternatives

## Output to User

```
📋 APPROVAL CHECKPOINT

Category: [Financial/Data/Production/etc]
Risk Level: [Low/Medium/High/Critical]

Proposed Action:
[One sentence summary]

I need your approval to proceed because:
[Reason this requires human oversight]

Full details: scratchpad/approvals/approval-[timestamp].md

Please review and respond:
- ✅ APPROVE to proceed
- 🔄 MODIFY to change approach
- ⏸️  DEFER to decide later
- ❌ REJECT to cancel

What's your decision?
```

## Audit Trail

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

## Acceptance Criteria

- Action is clearly described
- All risks are transparently disclosed
- Alternatives are shown
- Rollback plan exists
- User has full context to decide
- Decision is logged
- Execution only happens after approval

## Constraints

- Never execute before getting approval
- Be transparent about risks
- Don't downplay consequences
- Provide honest worst-case scenarios
- Always offer rollback plan
- Log all decisions for accountability

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

Execute approval checkpoint now.
