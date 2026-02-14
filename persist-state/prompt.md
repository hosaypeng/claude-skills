# State Persistence Task

You are executing the `/persist-state` skill to save current agent work state.

## Philosophy

From "How to Get Out of Your Agent's Way":
> "Stateless systems are inefficient. Without persistent state, agents recompute work, lose context, inflate prompts, increase cost."

Each significant task should have a writable workspace for:
- Intermediate results
- Logs
- Partial outputs
- Planning artifacts

Files are inspectable and deterministic.

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
✅ State persisted to scratchpad

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

## Example Use Cases

- Saving progress on long-running analysis
- Checkpointing before risky operations
- Creating resumable multi-step tasks
- Preserving context for tomorrow
- Sharing work state with other sessions

Execute state persistence now.
