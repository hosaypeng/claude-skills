---
name: health-check
description: "Check system health across LaunchAgents, git repos, vault backup, and habits pipeline. Only alerts on failures. Use when user says 'health check', 'is everything working', 'check my systems', or 'anything broken'."
user-invocable: true
---

# Health Check

Run the health check script:

```bash
bash ~/.claude/skills/health-check/scripts/run_health_check.sh
```

## What it checks

- **LaunchAgents**: Are key agents loaded? Any non-zero exit codes?
- **Git repos**: Any unpushed commits across all 8+ repos?
- **Backup recency**: Has the obsidian vault been backed up in the last 24h?
- **Habits pipeline**: Does habits.json exist and have valid structure?

## Interpreting results

- If all checks pass, report "All systems healthy" to the user
- If failures are found, present them grouped by category. For each failure, include the specific remediation command (e.g., 'Run git push in ~/repo' for unpushed commits, 'Run /update-habits' for stale habits).
- The `--dry-run` flag prevents Slack alerts — remove it to send a real alert

## Automated schedule

Runs daily at 07:30 via `com.hosaypeng.pengai-healthcheck` LaunchAgent. Silent on success, posts to `#daily-summary` on failure.

## Troubleshooting

- **Python venv not found**: Recreate with `python3 -m venv .venv && pip install -r requirements.txt` in the peng-ai directory.
- **Script fails with import errors**: Activate the venv and run `pip install -r requirements.txt`.
- **LaunchAgent reported as "not loaded"**: Reload with `launchctl load ~/Library/LaunchAgents/<plist-name>`.
