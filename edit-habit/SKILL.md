---
name: edit-habit
description: "Add, remove, or rename habits across all entries in all_habits.md. Use when user says 'add a habit', 'remove a habit', 'rename a habit', 'edit my habits', 'change habit name', or needs to modify the habit tracker structure."
user-invocable: true
---

Bulk-edit habits in `all_habits.md` using `edit_habit.py`.

1. Ask the user what operation they want:
   - **add** — Add a new habit under a category
   - **remove** — Remove a habit from all entries
   - **rename** — Rename a habit across all entries

2. Gather required parameters:
   - For **add**: category name and habit name
   - For **remove**: habit name
   - For **rename**: current name and new name

3. Run a dry-run first to preview:
   ```
   cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Documents/Code/hosaypenggithubio && python3 scripts/edit_habit.py --dry-run <command> <args...>
   ```

4. Show the user the dry-run output (number of entries affected)

5. If the user confirms, run for real (without `--dry-run`):
   ```
   cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Documents/Code/hosaypenggithubio && python3 scripts/edit_habit.py <command> <args...>
   ```

6. Show the summary of changes

7. Ask the user if they want to run `/update-habits` to push the changes to GitHub Pages

Base directory: /Users/hsp/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code/hosaypenggithubio

Examples:
```
python3 scripts/edit_habit.py add Diet "No processed food"
python3 scripts/edit_habit.py remove "Intermittent fasting"
python3 scripts/edit_habit.py rename "Mobility" "Yoga / mobility"
```

## Troubleshooting

**Error: Python script fails with ModuleNotFoundError or syntax error**
Cause: Wrong Python version or missing dependencies.
Fix: Verify `python3 --version` is 3.8+. Run from the correct base directory (`hosaypenggithubio`).

**Error: `all_habits.md` not found**
Cause: File was moved, renamed, or the working directory is wrong.
Fix: Confirm the base directory path is correct and that `all_habits.md` exists at the expected location within the repo.

**Error: Habit name not found (for remove/rename)**
Cause: The habit name doesn't match exactly — check for typos, extra spaces, or case differences.
Fix: Open `all_habits.md` and search for the habit name. Use the exact string as it appears in the file, including capitalization.
