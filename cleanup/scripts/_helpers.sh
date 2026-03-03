#!/bin/bash
set -e
# Shared helpers for cleanup scripts.
# Source this file: source "$(dirname "$0")/_helpers.sh"

TOTAL_FREED=0
WHITELIST_FILE="$HOME/.claude/cleanup-whitelist.txt"

# Check if a path matches any whitelist pattern.
# Returns 0 (true) if whitelisted, 1 (false) if not.
is_whitelisted() {
  local path="$1"
  [ ! -f "$WHITELIST_FILE" ] && return 1
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    [[ "$pattern" == \#* ]] && continue
    # shellcheck disable=SC2254
    case "$path" in
      $pattern) return 0 ;;
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
    TOTAL_FREED=$((TOTAL_FREED + size))
    local basename
    basename=$(basename "$path")
    local dest="$HOME/.Trash/${basename}.$(date +%s%N 2>/dev/null || date +%s)"
    mv -n "$path" "$dest" 2>/dev/null && {
      echo "  Trashed: $path (${size}K)"
    } || {
      echo "  FAILED to trash: $path (permission denied or locked)" >&2
    }
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
    local size
    size=$(safe_size "$dir")
    local count=0
    for item in "$dir"/* "$dir"/.*; do
      [ -e "$item" ] || continue
      local bn
      bn=$(basename "$item")
      [ "$bn" = "." ] || [ "$bn" = ".." ] && continue
      local dest="$HOME/.Trash/${bn}.$(date +%s%N 2>/dev/null || date +%s)"
      mv -n "$item" "$dest" 2>/dev/null && count=$((count + 1)) || true
    done
    if [ "$count" -gt 0 ]; then
      TOTAL_FREED=$((TOTAL_FREED + size))
      echo "  Trashed $count items from $dir ($((size / 1024))MB)"
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
