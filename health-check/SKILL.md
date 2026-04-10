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
- **Git repos**: Any unpushed commits across all repos?
- **Vault**: Is the Obsidian vault accessible?
- **Habits pipeline**: Does habits.json exist and is it recent?
- **Path audit**: Any dead paths in CLAUDE.md, MEMORY.md, or LaunchAgent plists?
- **Recovery repo drift**: Brewfile missing installed formulae/casks? repos.txt missing cloned repos or listing deleted ones?
- **Large log files**: Any log files over 100MB in home directory? Catches unbounded log growth before it eats disk.
- **Claude config sync**: Is the sync-claude-config LaunchAgent loaded? Do settings.json, hooks, and commands match the recovery repo?

## CLAUDE.md audit

After the script, manually verify both CLAUDE.md files:

1. **`~/.claude/CLAUDE.md`** — Check that any referenced skill names (e.g., `/audit-skills`) still exist in `~/.claude/skills/`.
2. **Vault `CLAUDE.md`** — For each concrete path referenced (vault dirs, templates, quick references, related repos):
   - Verify the path exists on disk
   - Verify the tag list matches `40_indexes/*.md` (excluding `_index.md`)
   - Verify template names match `templates/*.md`
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

- **`brew leaves` slow**: First run may take a few seconds; subsequent runs are faster.
- **LaunchAgent reported as "not loaded"**: Reload with `launchctl load ~/Library/LaunchAgents/<plist-name>`.
