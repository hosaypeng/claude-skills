---
name: recover
description: "Analyze agent failures and provide recovery strategies with rollback options. Use when user says 'something broke', 'recover from error', 'rollback', 'fix this failure', 'undo what went wrong', or after a failed operation needs diagnosis and recovery."
user-invocable: true
argument-hint: "[error description or context]"
---

# Error Recovery Task

## Objectives

Analyze the current failure state and provide actionable recovery strategies.

## Process

### 1. Analyze the Failure

Ask user or check context:
- What operation failed?
- What was the error message?
- Where did it fail (which step)?
- What state was preserved?

Check for error artifacts:
- Recent log files in `scratchpad/logs/`
- State snapshots in `scratchpad/state/`
- Cost tracker for recent tool failures
- Shell history for failed commands

### 2. Categorize the Error

Identify error type:

**Tool Failures**:
- Command not found
- Permission denied
- Syntax errors
- Tool crashed

**Partial Completions**:
- Some files written, some failed
- Partial data processing
- Incomplete migrations

**Resource Issues**:
- Timeout errors
- Memory exhaustion
- Disk space
- Rate limits hit

**Unexpected Outputs**:
- Wrong results
- Corrupted data
- Format mismatches

**State Corruption**:
- Inconsistent state
- Broken dependencies
- Conflicting changes

### 3. Assess What's Recoverable

Check:
- Is there a state snapshot before failure?
- Were intermediate results saved?
- Can the operation be safely retried?
- What cleanup is needed first?

### 4. Generate Recovery Options

Provide 3-4 recovery strategies ranked by safety:

**Option 1: Safe Rollback**
- Restore from last checkpoint
- Revert partial changes
- Return to known good state
- Pros/cons listed

**Option 2: Fix and Retry**
- Identify root cause
- Fix the issue
- Retry the operation
- Pros/cons listed

**Option 3: Partial Recovery**
- Keep successful parts
- Skip failed parts
- Continue from checkpoint
- Pros/cons listed

**Option 4: Manual Intervention**
- What user needs to do manually
- Why automation can't handle it
- Step-by-step instructions

### 5. Create Recovery Checkpoint

Before executing recovery:
- Save current state (even if broken)
- Create recovery log
- Document what we're about to try

### 6. Execute Recovery

With user approval:
- Execute chosen strategy
- Monitor for new errors
- Verify recovery success
- Clean up temporary artifacts

## Output Format

```
=== Error Recovery Analysis ===

[ALERT] FAILURE DETECTED
Operation: [what failed]
Error: [error message]
Location: [where it failed]
Timestamp: [when]

[INFO] STATE ASSESSMENT
- Partial progress: [what succeeded]
- Preserved state: [what's saved]
- Corruption risk: [low/medium/high]

[OPTIONS] RECOVERY OPTIONS

Option 1: ROLLBACK (Safest) [RECOMMENDED]
  └─ Restore from checkpoint-[timestamp]
  └─ Loses: [X minutes of work]
  └─ Risk: Low
  └─ Time: ~30 seconds

Option 2: FIX AND RETRY (Recommended)
  └─ Fix: [specific fix needed]
  └─ Retry: [the operation]
  └─ Risk: Medium
  └─ Time: ~2 minutes

Option 3: PARTIAL RECOVERY
  └─ Keep: [successful parts]
  └─ Skip: [failed parts]
  └─ Risk: Medium
  └─ Time: ~1 minute

Option 4: MANUAL (If needed)
  └─ User must: [manual steps]
  └─ Because: [why automation can't handle]

[RECOMMENDATION]
[Your suggested approach and why]

[WARN] WARNINGS
- [Any risks to be aware of]
- [Data that might be lost]

Ready to execute recovery? Choose an option.
```

## Checkpoint Before Recovery

Create: `scratchpad/recovery/recovery-[timestamp].json`

```json
{
  "failure": {
    "operation": "description",
    "error": "error message",
    "timestamp": "ISO-8601",
    "context": {}
  },
  "state_before_recovery": {
    "files": ["list of files in broken state"],
    "partial_results": "what was completed"
  },
  "recovery_strategy": "chosen option",
  "recovery_timestamp": "ISO-8601"
}
```

## After Recovery

Report results:
```
[OK] RECOVERY COMPLETE

Strategy: [which option was used]
Result: [success/partial/failed]
Time taken: [duration]

Changes made:
- [list of changes]

Verification:
- [what was verified]

Recovery log: scratchpad/recovery/recovery-[timestamp].json
```

## Acceptance Criteria

- Failure is clearly understood
- Multiple recovery options provided
- User can make informed choice
- State is preserved before recovery
- Recovery is logged for learning
- Success is verified

## Constraints

- Never make destructive changes without checkpoint
- Always offer rollback option
- Be honest about what can't be recovered
- Document failures for pattern analysis
- Keep recovery logs for learning

## Learning from Failures

After recovery, optionally:
- Add pattern to failure database
- Suggest preventive measures
- Update error handling for similar cases
- Recommend process improvements

## Troubleshooting

- **No state snapshots or logs found**: Fall back to git history (git log, git reflog, git stash list) and shell history. Ask the user to describe the failure.
- **Recovery checkpoint directory not writable**: Write recovery logs to /tmp/ as fallback, or output the plan to the terminal directly.

Execute error recovery analysis now.
