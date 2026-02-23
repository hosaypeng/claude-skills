---
name: persist-state
description: "Save current agent work state to scratchpad for resumable workflows. Use when user says 'save my progress', 'checkpoint this work', 'persist state', 'save for later', or before ending a long-running session that should be resumable."
user-invocable: true
---

# State Persistence Task

## Objectives

Persist current work state to structured scratchpad so agent work can be resumed or reviewed later.

## Scratchpad Structure

Organize the scratchpad directory as:

```
/scratchpad/
├── intermediate/     # Work-in-progress results
│   └── [taskname]/   # Per-task intermediate data
├── logs/            # Execution logs
│   └── [date]/      # Daily log organization
├── outputs/         # Partial or final outputs
│   └── [taskname]/  # Task-specific outputs
├── plans/           # Planning artifacts
│   └── [taskname].md # Task plans and decisions
└── state/           # State snapshots
    └── [taskname]-state.json # Resumable state
```

## What to Persist

1. **Intermediate Results**:
   - Partial computations
   - Temporary data structures
   - Search/analysis results

2. **Execution Logs**:
   - Commands run
   - Errors encountered
   - Decisions made

3. **Outputs**:
   - Generated files
   - Reports
   - Data artifacts

4. **Planning Context**:
   - Current approach
   - Alternatives considered
   - Next steps

5. **State Snapshot**:
   - Current progress
   - Variables/context
   - Resume instructions

## Process

1. **Determine Task Name**:
   - Ask user or infer from context
   - Create safe filename (lowercase, no spaces)

2. **Create Directory Structure**:
   - Ensure scratchpad directories exist
   - Create task-specific subdirectories

3. **Save Current State**:
   - Identify what needs persisting
   - Organize by category (intermediate/logs/outputs/plans/state)
   - Save with descriptive filenames

4. **Create State Snapshot**:
   - Save JSON with:
     ```json
     {
       "task": "task name",
       "timestamp": "ISO-8601 timestamp",
       "progress": "description of current state",
       "nextSteps": ["step 1", "step 2"],
       "context": {
         "key": "value"
       },
       "files": ["list of created files"]
     }
     ```

5. **Create Resume Instructions**:
   - Document how to resume this work
   - List files created and their purpose
   - Note any dependencies or setup

## Output Format

After persisting state, report to user:

```
[OK] State persisted to scratchpad

Task: [taskname]
Timestamp: [when]

Saved:
- Intermediate: [N] files
- Logs: [N] entries
- Outputs: [N] artifacts
- Plans: [description]

Resume with:
  Read state snapshot: scratchpad/state/[taskname]-state.json
  Review plan: scratchpad/plans/[taskname].md

Location: [full path to task directory]
```

## Acceptance Criteria

- Scratchpad structure is created
- Current state is saved with clear organization
- State snapshot JSON is valid and complete
- User can resume work from saved state
- All files have descriptive names

## Constraints

- Use only the scratchpad directory (never user's working directory)
- Keep file names safe and readable
- Make state self-documenting
- Don't persist sensitive data (credentials, keys)
- Keep logs concise and actionable

## Troubleshooting

**Error: Disk full when writing state files**
Cause: No remaining disk space on the volume.
Fix: Check available space with `df -h`. Remove old snapshots from `scratchpad/state/` or free space elsewhere. Prioritize saving the state JSON over logs and intermediate files.

**Error: Permission denied writing to scratchpad**
Cause: The scratchpad directory or its parent has restrictive permissions.
Fix: Check permissions with `ls -la` on the scratchpad path. Use `chmod` to fix, or ask the user to specify an alternate writable location.

**Error: Scratchpad directory doesn't exist and can't be created**
Cause: The parent path is invalid or on a read-only filesystem.
Fix: Verify the intended scratchpad path exists. Create it with `mkdir -p`. If on a read-only volume, output the state snapshot to the terminal so the user can save it manually.
