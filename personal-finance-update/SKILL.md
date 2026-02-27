---
name: personal-finance-update
description: "Run the finance pipeline, extract numbers from master CSVs, diff against Obsidian note, and update stale tables. Use when user says '/personal-finance-update'."
user-invocable: true
---

# Finance Pipeline Refresh

Run the full finance pipeline, extract current numbers from master CSVs, diff them against the Obsidian personal finance note, and update any stale tables in-place.

---

## Phase 0: Pre-flight

1. Read `~/.claude/skills/personal-finance-update/config.json`.
2. Validate every value path exists on disk.
3. If any path is missing: **STOP.** Report `MISSING: <key>: <path>` to the user and do not proceed. Do not attempt to infer a new location or continue with partial data.

---

## Phase 1: Pipeline

1. Run the finance pipeline:
   ```bash
   bash /Users/hsp/scripts/run_finance_pipeline.sh --quick
   ```
2. Check the exit code:
   - **Exit 0**: Continue silently to Phase 2.
   - **Exit 1**: Warn the user about validation warnings, then continue to Phase 2.
   - **Exit 2**: STOP. Report validation failures to the user and do not proceed.

---

## Phase 2: Extract

1. Run the extraction script:
   ```bash
   python3 ~/.claude/skills/personal-finance-update/scripts/finance_extract.py
   ```
2. Capture the JSON output from stdout.
3. Save the JSON to a temp file (e.g., `/tmp/finance_extract_output.json`) for use in the next phase.

---

## Phase 3: Diff

1. Run the diff script against the Obsidian note:
   ```bash
   python3 ~/.claude/skills/personal-finance-update/scripts/finance_diff.py /tmp/finance_extract_output.json "/Users/hsp/Library/Mobile Documents/iCloud~md~obsidian/Documents/20_areas/personal/personal_finance.md"
   ```
2. Capture the JSON output.
3. If `cells_changed` is 0: report "All tables up to date -- 0 changes" and skip directly to Phase 6.

---

## Phase 4: Update

For each table in `tables_changed`:

1. Use the Edit tool to replace the section in the Obsidian note.
2. The `old_string` is everything from the `heading` line through the end of the `postscript`.
3. The `new_string` is the regenerated heading + preamble + table + postscript from `new_markdown_sections`.
4. Only touch tables that actually changed. Leave unchanged tables alone.

---

## Phase 5: Verify

1. Run `finance_extract.py` again:
   ```bash
   python3 ~/.claude/skills/personal-finance-update/scripts/finance_extract.py
   ```
2. Save to a new temp file and run the diff again:
   ```bash
   python3 ~/.claude/skills/personal-finance-update/scripts/finance_diff.py /tmp/finance_extract_verify.json "/Users/hsp/Library/Mobile Documents/iCloud~md~obsidian/Documents/20_areas/personal/personal_finance.md"
   ```
3. If `cells_changed` is 0: good, continue to Phase 6.
4. If non-zero: warn the user about the discrepancy and flag for manual review, but continue.

---

## Phase 6: Audit

From the extract JSON and pipeline output, flag:

1. **Uncategorized transactions** from validation notes.
2. **Large transactions** over $5,000 that may need review.
3. **Category distribution warnings** (unusual spikes or missing categories).
4. **Partial-year status** for the current year (note how many months of data exist).

---

## Phase 7: Report

Present a summary to the user:

1. **Tables updated**: count of tables changed.
2. **Cells changed**: total number of cell-level changes.
3. **Specific changes**: list each change from the diff output `changes` array (table name, field, old value, new value).
4. **Audit findings**: any flags from Phase 6.

---

## Troubleshooting

- **Pipeline script not found**: Verify `/Users/hsp/scripts/run_finance_pipeline.sh` exists and is executable.
- **No master CSVs found**: Check `/Users/hsp/Sync/personal_finance/master/` has `*_master.csv` files.
- **Obsidian note not found**: iCloud sync may be delayed -- check the path exists.
- **Table not found in note**: The diff script couldn't find the expected `###` heading -- check the Obsidian note structure hasn't changed.
