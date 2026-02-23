#!/bin/bash
set -e

# Session Artifact Cleanup
# Removes Claude session artifacts, debug logs, stale caches, and temp files.

source "$(dirname "$0")/_helpers.sh"

HOME_DIR="$HOME"
LOG_FILE="$HOME_DIR/.claude/cleanup-log.txt"

echo "=== Session Artifact Cleanup ==="
echo ""

# 1. Scratchpad directories under /private/tmp/claude-*
# IMPORTANT: Skip the current session's temp dir (/private/tmp/claude-<UID>/)
# because Claude Code uses it for Bash tool output capture and task files.
# Moving it mid-execution destroys all stdout from the running command.
echo "--- Scratchpad Directories ---"
SCRATCHPAD_BASE="/private/tmp"
CURRENT_CLAUDE_TMP="$SCRATCHPAD_BASE/claude-$(id -u)"
if ls -d "$SCRATCHPAD_BASE"/claude-* 1>/dev/null 2>&1; then
  for dir in "$SCRATCHPAD_BASE"/claude-*/; do
    [ -d "$dir" ] || continue
    # Normalize trailing slash for comparison
    dir_clean="${dir%/}"
    if [ "$dir_clean" = "$CURRENT_CLAUDE_TMP" ]; then
      echo "  Skipping active session: $dir_clean"
      continue
    fi
    safe_trash "$dir"
  done
else
  echo "  No scratchpad directories found."
fi
echo ""

# 2. Claude debug logs (older than 7 days)
echo "--- Debug Logs ---"
DEBUG_DIR="$HOME_DIR/.claude/debug"
if [ -d "$DEBUG_DIR" ]; then
  OLD_COUNT=0
  while IFS= read -r f; do
    safe_trash "$f"
    OLD_COUNT=$((OLD_COUNT + 1))
  done < <(find "$DEBUG_DIR" -type f -not -newermt "7 days ago" 2>/dev/null)
  echo "  Removed $OLD_COUNT debug files older than 7 days."
else
  echo "  No debug directory found."
fi
echo ""

# 3. Claude desktop app cache
echo "--- Claude Desktop Cache ---"
CLAUDE_CACHE="$HOME_DIR/Library/Application Support/Claude/Cache"
if [ -d "$CLAUDE_CACHE" ]; then
  size=$(safe_size "$CLAUDE_CACHE")
  echo "  Cache size: $(format_size "$size")"
  safe_trash_contents "$CLAUDE_CACHE"
else
  echo "  No Claude desktop cache found."
fi
echo ""

# 4. Old Claude VM bundles (keep only the latest)
echo "--- Claude VM Bundles ---"
VM_DIR="$HOME_DIR/Library/Application Support/Claude/vm_bundles"
if [ -d "$VM_DIR" ]; then
  BUNDLE_COUNT=$(find "$VM_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$BUNDLE_COUNT" -gt 1 ]; then
    total_size=$(safe_size "$VM_DIR")
    echo "  Found $BUNDLE_COUNT VM bundles ($(format_size "$total_size") total)"
    # Keep only the newest bundle, trash the rest
    LATEST=$(find "$VM_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null | xargs -0 ls -dt | head -1)
    echo "  Keeping latest: $(basename "$LATEST")"
    for bundle in "$VM_DIR"/*/; do
      [ -d "$bundle" ] || continue
      [ "$bundle" = "$LATEST/" ] && continue
      safe_trash "$bundle"
    done
  else
    echo "  Only 1 VM bundle found, nothing to prune."
  fi
else
  echo "  No VM bundles directory found."
fi
echo ""

# 5. Stale project caches (projects that no longer exist on disk)
echo "--- Stale Project Caches ---"
PROJECTS_DIR="$HOME_DIR/.claude/projects"
if [ -d "$PROJECTS_DIR" ]; then
  STALE_COUNT=0
  # Each subdir maps to a filesystem path (encoded)
  for proj_dir in "$PROJECTS_DIR"/*/; do
    [ -d "$proj_dir" ] || continue
    # The directory name encodes the original path
    dir_name=$(basename "$proj_dir")
    # Decode: replace hyphens-at-start with /, internal hyphens may be path separators
    # Check if a CLAUDE.md exists inside — if the project cache has no recent activity, flag it
    LATEST_FILE=$(find "$proj_dir" -type f -exec stat -f '%m' {} \; 2>/dev/null | sort -rn | head -1)
    if [ -n "$LATEST_FILE" ]; then
      # Check if newest file is older than 30 days
      THIRTY_DAYS_AGO=$(date -v-30d +%s 2>/dev/null || date -d "30 days ago" +%s 2>/dev/null || echo 0)
      if [ "$LATEST_FILE" -lt "$THIRTY_DAYS_AGO" ] 2>/dev/null; then
        safe_trash "$proj_dir"
        STALE_COUNT=$((STALE_COUNT + 1))
      fi
    fi
  done
  echo "  Removed $STALE_COUNT stale project caches (>30 days inactive)."
else
  echo "  No projects directory found."
fi
echo ""

# 6. Claude backups (older than 30 days)
echo "--- Old Backups ---"
BACKUPS_DIR="$HOME_DIR/.claude/backups"
if [ -d "$BACKUPS_DIR" ]; then
  OLD_COUNT=0
  while IFS= read -r f; do
    safe_trash "$f"
    OLD_COUNT=$((OLD_COUNT + 1))
  done < <(find "$BACKUPS_DIR" -type f -not -newermt "30 days ago" 2>/dev/null)
  echo "  Removed $OLD_COUNT backup files older than 30 days."
else
  echo "  No backups directory found."
fi
echo ""

# 7. File history and paste/image caches (older than 30 days)
echo "--- Session Caches ---"
for cache_name in "file-history" "image-cache" "paste-cache"; do
  CACHE_PATH="$HOME_DIR/.claude/$cache_name"
  if [ -d "$CACHE_PATH" ]; then
    OLD_COUNT=0
    while IFS= read -r f; do
      safe_trash "$f"
      OLD_COUNT=$((OLD_COUNT + 1))
    done < <(find "$CACHE_PATH" -type f -not -newermt "30 days ago" 2>/dev/null)
    [ "$OLD_COUNT" -gt 0 ] && echo "  $cache_name: removed $OLD_COUNT old files."
  fi
done
echo ""

# 8. Orphaned Claude processes (detect only)
echo "--- Orphaned Processes ---"
ORPHANED=$(ps aux 2>/dev/null | grep -i "claude" | grep -v grep | grep -v "$$" || true)
if [ -n "$ORPHANED" ]; then
  echo "  Found potentially orphaned Claude processes:"
  echo "$ORPHANED" | sed 's/^/    /'
  echo "  (Not killing automatically — review and kill manually if needed)"
else
  echo "  No orphaned Claude processes found."
fi
echo ""

# 9. Stale lock files
echo "--- Stale Lock Files ---"
LOCK_COUNT=0
for lockfile in /tmp/claude-*.lock /tmp/claude-*.tmp; do
  if [ -f "$lockfile" ]; then
    safe_trash "$lockfile"
    LOCK_COUNT=$((LOCK_COUNT + 1))
  fi
done
[ "$LOCK_COUNT" -eq 0 ] && echo "  No stale lock files found."
echo ""

# 10. Temporary downloads
echo "--- Temporary Downloads ---"
TEMP_COUNT=0
for pattern in "$HOME_DIR/Downloads"/*.tmp "$HOME_DIR/Downloads"/*.crdownload "$HOME_DIR/Downloads"/*.part; do
  if [ -f "$pattern" ]; then
    safe_trash "$pattern"
    TEMP_COUNT=$((TEMP_COUNT + 1))
  fi
done
[ "$TEMP_COUNT" -eq 0 ] && echo "  No temporary downloads found."
echo ""

# Summary
FREED_MB=$((TOTAL_FREED / 1024))
echo "=== Session Cleanup Complete ==="
echo "Space recovered: approximately $(format_size $TOTAL_FREED)"

# Log
mkdir -p "$(dirname "$LOG_FILE")"
cat >> "$LOG_FILE" <<LOGEOF
========================================
Session Cleanup: $(date '+%Y-%m-%d %H:%M:%S')
========================================
Space Recovered: $(format_size $TOTAL_FREED)
Status: Success
========================================

LOGEOF

echo "Log appended to $LOG_FILE"
