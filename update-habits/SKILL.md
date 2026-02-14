---
name: update-habits
description: Parse habits from Obsidian all_habits.md and push updated heatmap to GitHub Pages. Use when user says 'update heatmap', 'push habits', 'sync habits to site', or after checking habit boxes in Obsidian.
user-invocable: true
---

Update the habits heatmap on GitHub Pages after checking boxes in Obsidian.

## Execution

Run the update script:

```
bash ~/.claude/skills/update-habits/scripts/update_habits.sh
```

The script handles the full pipeline: parse habits, check for changes, commit, and push. Exit code 0 means success (including "no changes detected").

## After the script runs

- If the output says "No habit changes detected", tell the user no changes were found.
- If the push succeeded, confirm the heatmap has been updated on GitHub Pages.
- If the script fails (non-zero exit), report the error output to the user.

Base directory: /Users/hsp/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code/hosaypenggithubio
