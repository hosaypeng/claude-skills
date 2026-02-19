#!/bin/bash
# Shared helpers for cleanup scripts.
# Source this file: source "$(dirname "$0")/_helpers.sh"

TOTAL_FREED=0

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
    local size
    size=$(safe_size "$path")
    TOTAL_FREED=$((TOTAL_FREED + size))
    local basename
    basename=$(basename "$path")
    local dest="$HOME/.Trash/${basename}.$(date +%s%N 2>/dev/null || date +%s)"
    mv "$path" "$dest" 2>/dev/null && {
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
    local size
    size=$(safe_size "$dir")
    local count=0
    for item in "$dir"/* "$dir"/.*; do
      [ -e "$item" ] || continue
      local bn
      bn=$(basename "$item")
      [ "$bn" = "." ] || [ "$bn" = ".." ] && continue
      local dest="$HOME/.Trash/${bn}.$(date +%s%N 2>/dev/null || date +%s)"
      mv "$item" "$dest" 2>/dev/null && count=$((count + 1)) || true
    done
    if [ "$count" -gt 0 ]; then
      TOTAL_FREED=$((TOTAL_FREED + size))
      echo "  Trashed $count items from $dir ($((size / 1024))MB)"
    fi
  fi
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
