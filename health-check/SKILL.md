---
name: health-check
description: "Check system health across LaunchAgents, git repos, vault backup, and habits pipeline. Only alerts on failures. Use when user says 'health check', 'is everything working', 'check my systems', or 'anything broken'."
---

# Health Check

Run the health check script:

```bash
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Documents/Code/peng-ai && source .venv/bin/activate && python3 scripts/health_check.py --dry-run
```

## What it checks

- **LaunchAgents**: Are key agents loaded? Any non-zero exit codes?
- **Git repos**: Any unpushed commits across all 8+ repos?
- **Backup recency**: Has the obsidian vault been backed up in the last 24h?
- **Habits pipeline**: Does habits.json exist and have valid structure?

## Interpreting results

- If all checks pass, report "All systems healthy" to the user
- If failures are found, present them grouped by category with suggested fixes
- The `--dry-run` flag prevents Slack alerts — remove it to send a real alert

## Automated schedule

Runs daily at 07:30 via `com.hosaypeng.pengai-healthcheck` LaunchAgent. Silent on success, posts to `#daily-summary` on failure.
