---
name: track-cost
description: "Analyze Claude agent session activity, tool call frequency, and resource usage patterns. Use when user says 'how much did that cost', 'track usage', 'show tool usage', 'cost report', or to review session efficiency."
user-invocable: true
---

# Session Activity Analysis Task

## Objectives

Provide visibility into tool usage patterns and session activity to help optimize agent workflows and estimate resource consumption.

## What to Analyze

1. **Current Session Activity**:
   - Count tool calls made in this conversation (Read, Edit, Bash, Grep, Glob, WebFetch, etc.)
   - Categorize operations by type (file reads, file edits, shell commands, searches)
   - Note which files were touched and how many times

2. **Tool Call Breakdown**:
   - Which tools were used most frequently
   - Categorize by cost weight:
     - **Light**: Glob, Grep, Read (small files), Edit
     - **Medium**: Read (large files), Bash (fast commands)
     - **Heavy**: Bash (long-running), WebFetch, WebSearch
   - Identify redundant or repeated operations

3. **Optimization Recommendations**:
   - Suggest ways to reduce unnecessary tool calls
   - Identify patterns like re-reading the same file multiple times
   - Recommend batching strategies (e.g., parallel reads vs. sequential)
   - Flag expensive operations that could be replaced with lighter alternatives

## Output Format

Present a clear report with:

```
=== Session Activity Report ===
Session: [Date]

[INFO] TOOL USAGE
- Total calls: [N]
- Most used: [Tool name] ([N] calls)
- Tool breakdown:
  - Bash: [N] calls
  - Read: [N] calls
  - Edit: [N] calls
  - Grep: [N] calls
  - Glob: [N] calls
  [etc.]

[COST] ESTIMATED RESOURCE WEIGHT
- Light operations (Glob, Grep, Edit): [N] calls
- Medium operations (Read, Bash): [N] calls
- Heavy operations (WebFetch, WebSearch): [N] calls
- Note: These are rough heuristics based on tool call counts,
  not actual token or dollar measurements.

[OPTIMIZE] RECOMMENDATIONS
- [Actionable suggestions based on observed patterns]
- [Redundancy or inefficiency callouts]
```

## Important Caveats

- **No direct cost data is available.** This analysis is based on tool call counts and heuristic weights, not actual token consumption or API billing data.
- Token and dollar cost estimates are rough approximations at best. Do not present them as measurements.
- The analysis covers only what is observable from the current conversation context.

## Acceptance Criteria

- Summary is easy to read
- Tool call counts are based on actual session activity
- Provides actionable optimization suggestions
- Is transparent about what is estimated vs. measured

## Constraints

- Focus on clarity over completeness
- Be honest about limitations -- never fabricate data
- Suggest optimizations if patterns detected
- Don't overanalyze -- keep it practical

## Troubleshooting

**Error: Unable to count tool calls accurately**
Cause: Conversation context may be truncated after compaction or in very long sessions.
Fix: Report on whatever is observable and note that the counts may be incomplete. State the portion of the session that was analyzed.

**Error: User expects exact dollar costs**
Cause: The skill name or description set expectations for precise billing data.
Fix: Explain that exact costs require Anthropic's usage dashboard or API billing endpoints. This skill provides activity-based heuristics only.

Execute the session activity analysis now.
