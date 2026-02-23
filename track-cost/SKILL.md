---
name: track-cost
description: "Analyze Claude agent resource usage, tool call frequency, and token consumption patterns. Use when user says 'how much did that cost', 'track usage', 'show tool usage', 'cost report', or to review session efficiency and spending."
user-invocable: true
---

# Cost Tracking Analysis Task

## Objectives

Provide visibility into token consumption and tool usage patterns to help plan for sustained autonomous agent operations.

## What to Analyze

1. **Current Session**:
   - Read cost summary: `~/.claude/session-env/cost-summary.txt`
   - Parse detailed log: `~/.claude/session-env/cost-tracker-YYYYMMDD.jsonl`

2. **Historical Trends**:
   - Compare with previous days
   - Identify usage patterns
   - Spot cost spikes

3. **Tool Breakdown**:
   - Which tools are used most frequently
   - Estimated token consumption by tool type
   - Expensive operations (Read, Bash, etc.)

## Output Format

Present a clear report with:

```
=== Cost Analysis Report ===
Session: [Date]
Period: [Time range]

[INFO] TOOL USAGE
- Total calls: [N]
- Most used: [Tool name] ([N] calls)
- Tool breakdown:
  • Bash: [N] calls
  • Read: [N] calls
  • Edit: [N] calls
  • Task: [N] calls
  [etc.]

[COST] ESTIMATED COSTS
- Light operations (Bash, Edit): [N] calls
- Medium operations (Read, Grep): [N] calls
- Heavy operations (Task, WebFetch): [N] calls

[TREND] PATTERNS
- Peak usage times: [analysis]
- Common workflows: [patterns detected]
- Optimization opportunities: [suggestions]

[WARN] ALERTS
[Any concerning patterns or budget warnings]
```

## Acceptance Criteria

- Summary is easy to read
- Shows both current session and historical context
- Provides actionable insights for cost optimization
- Identifies expensive operations

## Constraints

- Focus on clarity over completeness
- Highlight anomalies or concerns
- Suggest optimizations if patterns detected
- Don't overanalyze - keep it practical

## Troubleshooting

**Error: No cost log files found**
Cause: The expected files at `~/.claude/session-env/` don't exist — either the session logger isn't configured or the directory path changed.
Fix: Check if the directory exists with `ls ~/.claude/session-env/`. If missing, inform the user that cost tracking data isn't available and suggest verifying the session logger setup.

**Error: Empty or malformed session data**
Cause: The JSONL log file exists but contains no entries or has corrupted lines.
Fix: Skip malformed lines and report on whatever valid data exists. If the file is entirely empty, report that no usage data was recorded for the session.

**Error: Historical log files missing for trend comparison**
Cause: Old log files were cleaned up or this is the first session.
Fix: Skip the historical trends section and report only on the current session. Note that trend data will become available after multiple sessions.

Execute the cost analysis now.
