---
name: require-approval
description: "Create structured approval checkpoints for high-stakes or irreversible decisions. Use when an agent needs human sign-off before destructive actions, production deployments, financial operations, data deletion, or security changes."
user-invocable: true
---

# Human Oversight Approval Task

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

### [WARN] Irreversibility:
[Can this be undone? If so, how?]

### [ALERT] Blast Radius:
[What could break if this goes wrong?]

### [INFO] Impact:
- Users affected: [number/scope]
- Systems affected: [list]
- Downtime risk: [low/medium/high]

### [ROLLBACK] Rollback Plan:
[How to undo if needed]

### [ALERT] Worst Case:
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

1. [APPROVE] - Proceed with the action as described
2. [MODIFY] - I want to change the approach
3. [DEFER] - Not now, ask me later
4. [REJECT] - Don't do this

Additional notes/conditions:
[Space for user input]
```

## Approval Document Format

Create approval documents and format user-facing output per `~/.claude/skills/require-approval/references/approval_template.md`.

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

## Troubleshooting

- **Approval document save fails**: Create the directory with mkdir -p or output the approval document inline.
- **User response is ambiguous**: Re-present the options. If conversational (e.g., "yeah go ahead"), interpret as approval and confirm.

Execute approval checkpoint now.
