#!/bin/bash
set -e

# Session Artifact Cleanup
# Removes Claude session artifacts, orphaned processes, stale locks, and temp downloads.

HOME_DIR="$HOME"
LOG_FILE="$HOME_DIR/.claude/cleanup-log.txt"
TOTAL_FREED=0

echo "=== Session Artifact Cleanup ==="
echo ""

# 1. Clean scratchpad directories under /private/tmp/claude-*
echo "--- Scratchpad Directories ---"
SCRATCHPAD_BASE="/private/tmp"
if ls -d "$SCRATCHPAD_BASE"/claude-* 1>/dev/null 2>&1; then
  for dir in "$SCRATCHPAD_BASE"/claude-*/; do
    if [ -d "$dir" ]; then
      size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
      TOTAL_FREED=$((TOTAL_FREED + size))
      echo "Removing: $dir (${size}K)"
      rm -rf "$dir"
    fi
  done
else
  echo "No scratchpad directories found."
fi
echo ""

# 2. Check for orphaned Claude-related processes
echo "--- Orphaned Processes ---"
ORPHANED=$(ps aux 2>/dev/null | grep -i "claude" | grep -v grep | grep -v "$$" || true)
if [ -n "$ORPHANED" ]; then
  echo "Found potentially orphaned Claude processes:"
  echo "$ORPHANED"
  echo "(Not killing automatically -- review and kill manually if needed)"
else
  echo "No orphaned Claude processes found."
fi
echo ""

# 3. Remove stale lock files
echo "--- Stale Lock Files ---"
LOCK_COUNT=0
for lockfile in /tmp/*.lock /tmp/claude-*.tmp; do
  if [ -f "$lockfile" ]; then
    size=$(du -sk "$lockfile" 2>/dev/null | awk '{print $1}')
    TOTAL_FREED=$((TOTAL_FREED + size))
    echo "Removing: $lockfile"
    rm -f "$lockfile"
    LOCK_COUNT=$((LOCK_COUNT + 1))
  fi
done
if [ "$LOCK_COUNT" -eq 0 ]; then
  echo "No stale lock files found."
fi
echo ""

# 4. Remove temporary downloads in common locations
echo "--- Temporary Downloads ---"
TEMP_COUNT=0
for pattern in "$HOME_DIR/Downloads"/*.tmp "$HOME_DIR/Downloads"/*.crdownload "$HOME_DIR/Downloads"/*.part; do
  if [ -f "$pattern" ]; then
    size=$(du -sk "$pattern" 2>/dev/null | awk '{print $1}')
    TOTAL_FREED=$((TOTAL_FREED + size))
    echo "Removing: $pattern (${size}K)"
    rm -f "$pattern"
    TEMP_COUNT=$((TEMP_COUNT + 1))
  fi
done
if [ "$TEMP_COUNT" -eq 0 ]; then
  echo "No temporary downloads found."
fi
echo ""

# 5. Summary
FREED_MB=$((TOTAL_FREED / 1024))
echo "=== Session Cleanup Complete ==="
echo "Space recovered: approximately ${FREED_MB}MB (${TOTAL_FREED}K)"

# 6. Log
mkdir -p "$(dirname "$LOG_FILE")"
cat >> "$LOG_FILE" <<LOGEOF
========================================
Session Cleanup: $(date '+%Y-%m-%d %H:%M:%S')
========================================
Space Recovered: ${FREED_MB}MB (${TOTAL_FREED}K)
Scratchpad dirs removed: $(ls -d "$SCRATCHPAD_BASE"/claude-* 2>/dev/null | wc -l || echo 0) (already cleaned)
Lock files removed: ${LOCK_COUNT}
Temp downloads removed: ${TEMP_COUNT}
Status: Success
========================================

LOGEOF

echo "Log appended to $LOG_FILE"
