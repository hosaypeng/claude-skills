#!/bin/bash
# audit_paths_watcher.sh — Triggered by LaunchAgent when vault dirs change
# Runs audit, logs results. Only writes log if dead paths found.

LOGFILE="${HOME}/.claude/skills/audit-paths/last_audit.log"
SCRIPT="${HOME}/.claude/skills/audit-paths/scripts/audit_paths.sh"

output=$(bash "$SCRIPT" all 2>&1)
# grep -c already prints 0 on no match; an `|| echo 0` here yields "0\n0" and breaks -gt.
dead_count=$(echo "$output" | grep -c "^DEAD" || true)

if [ "$dead_count" -gt 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') — ${dead_count} dead path(s):" > "$LOGFILE"
  echo "$output" | grep "^DEAD" >> "$LOGFILE"
fi
