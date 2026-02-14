---
name: track-cost
description: "Analyze Claude agent resource usage, tool call frequency, and token consumption patterns. Use when user says 'how much did that cost', 'track usage', 'show tool usage', 'cost report', or to review session efficiency and spending."
---

# Cost Tracking Analysis Task

You are executing the `/track-cost` skill to analyze autonomous agent resource usage.

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

📊 TOOL USAGE
- Total calls: [N]
- Most used: [Tool name] ([N] calls)
- Tool breakdown:
  • Bash: [N] calls
  • Read: [N] calls
  • Edit: [N] calls
  • Task: [N] calls
  [etc.]

💰 ESTIMATED COSTS
- Light operations (Bash, Edit): [N] calls
- Medium operations (Read, Grep): [N] calls
- Heavy operations (Task, WebFetch): [N] calls

📈 PATTERNS
- Peak usage times: [analysis]
- Common workflows: [patterns detected]
- Optimization opportunities: [suggestions]

⚠️  ALERTS
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

Execute the cost analysis now.
