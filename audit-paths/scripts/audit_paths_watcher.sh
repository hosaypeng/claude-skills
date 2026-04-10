#!/bin/bash
# audit_paths_watcher.sh — Triggered by LaunchAgent when vault dirs change
# Runs audit, logs results. Only writes log if dead paths found.

LOGFILE="${HOME}/.claude/skills/audit-paths/last_audit.log"
SCRIPT="${HOME}/.claude/skills/audit-paths/scripts/audit_paths.sh"

output=$(bash "$SCRIPT" all 2>&1)
dead_count=$(echo "$output" | grep -c "^DEAD" || echo 0)

if [ "$dead_count" -gt 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') — ${dead_count} dead path(s):" > "$LOGFILE"
  echo "$output" | grep "^DEAD" >> "$LOGFILE"
fi
