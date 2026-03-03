---
name: health-check
description: "Check system health across LaunchAgents, git repos, vault backup, and habits pipeline. Only alerts on failures. Use when user says 'health check', 'is everything working', 'check my systems', or 'anything broken'."
user-invocable: true
---

# Health Check

Run the health check script:

```bash
# Dry-run (default) — no Slack alerts
bash ~/.claude/skills/health-check/scripts/run_health_check.sh

# Live mode — sends real Slack alerts on failure
bash ~/.claude/skills/health-check/scripts/run_health_check.sh --alert
```

## What it checks

- **LaunchAgents**: Are key agents loaded? Any non-zero exit codes?
- **Git repos**: Any unpushed commits across all 8+ repos?
- **Backup recency**: Has the obsidian vault been backed up in the last 24h?
- **Habits pipeline**: Does habits.json exist and have valid structure?
- **CLAUDE.md staleness**: Verify all paths, skill names, and file references in `~/.claude/CLAUDE.md` and the vault's `CLAUDE.md` still exist. Flag dead paths, references to deleted skills, and stale tag/index lists.

## CLAUDE.md audit

After the script, manually verify both CLAUDE.md files:

1. **`~/.claude/CLAUDE.md`** — Check that any referenced skill names (e.g., `/audit-skills`) still exist in `~/.claude/skills/`.
2. **Vault `CLAUDE.md`** — For each concrete path referenced (vault dirs, templates, quick references, related repos):
   - Verify the path exists on disk
   - Verify the tag list matches `40_indexes/*.md` (excluding `_index.md`)
   - Verify template names match `50_system/templates/*.md`
3. Report any stale references found. Auto-fix non-destructive issues (update counts, fix paths). Ask before removing rules or references.

## Interpreting results

- If all checks pass (script + CLAUDE.md audit), report "All systems healthy" to the user
- If failures are found, present them grouped by category. For each failure, include the specific remediation command (e.g., 'Run git push in ~/repo' for unpushed commits, 'Run /update-habits' for stale habits, edit CLAUDE.md for stale references).
- By default the script runs with `--dry-run` (no Slack alerts)
- Pass `--alert` to send real Slack alerts on failure: `bash ~/.claude/skills/health-check/scripts/run_health_check.sh --alert`

## Automated schedule

Runs daily at 07:30 via `com.hosaypeng.pengai-healthcheck` LaunchAgent. Silent on success, posts to `#daily-summary` on failure.

## See also

- **`/git-status`** — Focused check for unpushed commits and dirty working trees across repos. Health-check includes a simpler version of this; use `/git-status` for detailed repo-by-repo status.
- **`/audit-skills`** — Validates skill definitions, dead references, and CLAUDE.md consistency. Health-check includes a CLAUDE.md staleness check; use `/audit-skills` for a full skill-level audit.

## Troubleshooting

- **Python venv not found**: Recreate with `python3 -m venv .venv && pip install -r requirements.txt` in the peng-ai directory.
- **Script fails with import errors**: Activate the venv and run `pip install -r requirements.txt`.
- **LaunchAgent reported as "not loaded"**: Reload with `launchctl load ~/Library/LaunchAgents/<plist-name>`.
