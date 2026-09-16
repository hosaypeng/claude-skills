#!/bin/bash
set -e
# Shared helpers for cleanup scripts.
# Source this file: source "$(dirname "$0")/_helpers.sh"

TOTAL_FREED=0
TOTAL_FAILED=0
TOTAL_REPORTED=0
REPORTED_COUNT=0
WHITELIST_FILE="$HOME/.claude/cleanup-whitelist.txt"

# Report a candidate for removal without deleting it. Used by orphan detection,
# where bundle-ID matching produces false positives for CLI tools, group
# containers, and system frameworks that own no .app bundle.
report_candidate() {
  local path="$1"
  local note="${2:-}"
  local size
  size=$(safe_size "$path")
  TOTAL_REPORTED=$((TOTAL_REPORTED + size))
  REPORTED_COUNT=$((REPORTED_COUNT + 1))
  if [ -n "$note" ]; then
    echo "  $path ($(format_size "$size")) — $note"
  else
    echo "  $path ($(format_size "$size"))"
  fi
}

# True if the path was modified within the last N days. A live app rewrites its
# support files constantly, so this catches false-positive orphans regardless of
# whether bundle-ID matching got the name right.
is_recently_modified() {
  local path="$1"
  local days="${2:-30}"
  [ -e "$path" ] || return 1
  find "$path" -maxdepth 0 -newermt "$days days ago" -print -quit 2>/dev/null | grep -q .
}

# Check if a path matches any whitelist pattern.
# Returns 0 (true) if whitelisted, 1 (false) if not.
is_whitelisted() {
  local path="$1"
  [ ! -f "$WHITELIST_FILE" ] && return 1
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    [[ "$pattern" == \#* ]] && continue
    local expanded_pattern="${pattern/#\~/$HOME}"
    # shellcheck disable=SC2254
    case "$path" in
      $expanded_pattern) return 0 ;;
    esac
  done < "$WHITELIST_FILE"
  return 1
}

# Returns size in KB for a path, 0 if missing.
safe_size() {
  if [ -e "$1" ]; then
    local result
    result=$(du -sk "$1" 2>/dev/null | awk '{print $1}')
    echo "${result:-0}"
  else
    echo 0
  fi
}

# Move path to Trash instead of rm -rf. Appends timestamp to avoid collisions.
safe_trash() {
  local path="$1"
  if [ -e "$path" ]; then
    if is_whitelisted "$path"; then
      echo "  Skipped (whitelisted): $path"
      return 0
    fi
    local size
    size=$(safe_size "$path")
    local basename
    basename=$(basename "$path")
    local dest="$HOME/.Trash/${basename}.$(date +%s%N 2>/dev/null || date +%s)"
    if mv -n "$path" "$dest" 2>/dev/null; then
      TOTAL_FREED=$((TOTAL_FREED + size))
      echo "  Trashed: $path (${size}K)"
    else
      TOTAL_FAILED=$((TOTAL_FAILED + 1))
      echo "  FAILED to trash: $path (permission denied or locked)" >&2
    fi
  fi
}

# Move contents of a directory to Trash (keeps the directory itself).
safe_trash_contents() {
  local dir="$1"
  if [ -d "$dir" ]; then
    if is_whitelisted "$dir"; then
      echo "  Skipped (whitelisted): $dir"
      return 0
    fi
    local count=0
    local freed=0
    local failed=0
    local skipped=0
    for item in "$dir"/* "$dir"/.*; do
      [ -e "$item" ] || continue
      local bn
      bn=$(basename "$item")
      case "$bn" in
        .|..) continue ;;
      esac
      if is_whitelisted "$item"; then
        skipped=$((skipped + 1))
        continue
      fi
      local item_size
      item_size=$(safe_size "$item")
      local dest="$HOME/.Trash/${bn}.$(date +%s%N 2>/dev/null || date +%s)"
      if mv -n "$item" "$dest" 2>/dev/null; then
        count=$((count + 1))
        freed=$((freed + item_size))
      else
        failed=$((failed + 1))
      fi
    done
    if [ "$count" -gt 0 ]; then
      TOTAL_FREED=$((TOTAL_FREED + freed))
      echo "  Trashed $count items from $dir ($(format_size $freed))"
    fi
    if [ "$skipped" -gt 0 ]; then
      echo "  Skipped $skipped whitelisted item(s) in $dir"
    fi
    if [ "$failed" -gt 0 ]; then
      TOTAL_FAILED=$((TOTAL_FAILED + failed))
      echo "  FAILED to trash $failed item(s) in $dir (permission denied or locked)" >&2
    fi
  fi
}

# Check if an app is running by process name.
# Returns 0 (true) if running, 1 (false) if not.
is_app_running() {
  pgrep -xiq "$1" 2>/dev/null
}

# Format KB as human-readable.
format_size() {
  local kb=$1
  if [ "$kb" -ge 1048576 ]; then
    echo "$((kb / 1048576))GB"
  elif [ "$kb" -ge 1024 ]; then
    echo "$((kb / 1024))MB"
  else
    echo "${kb}KB"
  fi
}
