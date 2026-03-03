---
name: sync-schedule
description: "Sync schedule.md with live Google Calendar data. Use when user says 'sync schedule', 'update schedule.md', 'sync my calendar', or after making changes to gcal. Pulls live gcal data and rewrites the time tables in schedule.md. gcal is always the source of truth."
user-invocable: true
---

Sync `memory/schedule.md` with live Google Calendar. No prompts — run end-to-end and report changes.

## Step 1 — Pull live gcal data

Read calendar configuration from `~/.claude/skills/sync-schedule/config.json`, which contains:

```json
{
  "timezone": "Asia/Singapore",
  "max_results": 250,
  "schedule_path": "<path to schedule.md>",
  "calendars": [
    { "name": "<calendar name>", "id": "<calendar ID>" }
  ]
}
```

Pull the next full Mon–Sun week from all configured calendars **in parallel**. Use the configured `timezone` and `max_results`.

## Step 2 — Extract recurring blocks per day pattern

From the merged event list:
- **Keep only recurring events** — skip any event without a `recurringEventId`. One-offs don't belong in the schedule template.
- **Skip all-day events** (no `dateTime` in start).
- **Identify day patterns** by which days of the week the recurring event falls on:
  - Base (Mon/Tue/Thu/Fri)
  - Wednesday (differs from base)
  - Saturday
  - Sunday
- For each day pattern, build a time-sorted list of `HH:MM–HH:MM | block name` pairs. Use the block's `summary` from gcal exactly as written (lowercase, no reformatting). Use an en-dash (–) not a hyphen (-) between times.

## Step 3 — Read current schedule.md

Read the file at the `schedule_path` from config.json.

Identify the four time table sections:
- `## Mon / Tue / Thu / Fri (base)`
- `## Wednesday (grocery day)`
- `## Saturday`
- `## Sunday`

Each section contains a markdown table starting with `| Time | Block |`. Replace **only the table rows** in each section with the new gcal data. Preserve verbatim:
- All section headings and prose outside of tables
- `## 1st of Every Month`
- `## Rules`
- `## Recurring Event IDs`

## Step 4 — Write and report

Write the updated file. Then report:
- Blocks added (in gcal, not previously in schedule.md)
- Blocks removed (in schedule.md, no longer in gcal)
- Blocks unchanged
- Any anomalies (e.g. overlapping times, missing day coverage)

## Rules

- gcal is source of truth. Only write what gcal returns — no inference, no gap-filling.
- Never modify the Rules section, Recurring Event IDs section, or any prose outside tables.
- If a block appears on Mon/Tue/Wed/Thu/Fri (all weekdays), put it in the base template and note Wednesday's variation separately.
- If gcal returns zero events for a day, do not erase that section — flag it as a data error instead.

## Troubleshooting

- **gcal returns no events**: Verify the date range covers actual recurring events. Try extending the window by one week.
- **Sections misaligned after write**: Read the file first, locate section boundaries precisely, then do targeted edits rather than a full overwrite.
- **One-off events appearing**: Confirm `recurringEventId` is present before including. Skip if absent.
- **Wednesday table looks like base**: Wednesday groceries shift the walk/reading blocks — verify those events exist in the pull and appear in the Wednesday table.
