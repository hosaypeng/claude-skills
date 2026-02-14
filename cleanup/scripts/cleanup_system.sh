#!/bin/bash
set -e

# System Cache Cleanup
# Removes system caches, browser caches, development caches, temp files, and old logs.

HOME_DIR="$HOME"
LOG_FILE="$HOME_DIR/.claude/system-cleanup-log.txt"
TOTAL_FREED=0

safe_size() {
  # Returns size in KB for a path, 0 if missing
  if [ -e "$1" ]; then
    du -sk "$1" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

safe_rm() {
  # Remove path and track freed space
  local path="$1"
  if [ -e "$path" ]; then
    local size
    size=$(safe_size "$path")
    TOTAL_FREED=$((TOTAL_FREED + size))
    rm -rf "$path"
    echo "  Removed: $path (${size}K)"
  fi
}

echo "=== System Cache Cleanup ==="
echo ""
echo "Disk usage before cleanup:"
df -h "$HOME_DIR" | head -2
echo ""

# 1. User Library Caches (preserving files modified in last 7 days)
echo "--- User Library Caches ---"
CACHE_DIR="$HOME_DIR/Library/Caches"
if [ -d "$CACHE_DIR" ]; then
  CACHE_SIZE=$(safe_size "$CACHE_DIR")
  echo "Total cache size: $((CACHE_SIZE / 1024))MB"
  # Remove items older than 7 days
  find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d -not -newermt "7 days ago" 2>/dev/null | while read -r dir; do
    size=$(safe_size "$dir")
    TOTAL_FREED=$((TOTAL_FREED + size))
    rm -rf "$dir" 2>/dev/null || true
  done
  echo "Cleared caches older than 7 days."
else
  echo "No user cache directory found."
fi
echo ""

# 2. Application Support caches
echo "--- Application Support Caches ---"
CRASH_DIR="$HOME_DIR/Library/Application Support/CrashReporter"
if [ -d "$CRASH_DIR" ]; then
  safe_rm "$CRASH_DIR"
fi
echo ""

# 3. Browser Caches
echo "--- Browser Caches ---"
for browser_cache in \
  "$HOME_DIR/Library/Caches/Google/Chrome" \
  "$HOME_DIR/Library/Caches/com.apple.Safari" \
  "$HOME_DIR/Library/Caches/Firefox"; do
  if [ -d "$browser_cache" ]; then
    size=$(safe_size "$browser_cache")
    TOTAL_FREED=$((TOTAL_FREED + size))
    rm -rf "$browser_cache" 2>/dev/null || true
    echo "  Cleared: $browser_cache ($((size / 1024))MB)"
  fi
done
echo ""

# 4. Development Caches
echo "--- Development Caches ---"
# Homebrew
BREW_CACHE="$HOME_DIR/Library/Caches/Homebrew"
if [ -d "$BREW_CACHE" ]; then
  size=$(safe_size "$BREW_CACHE")
  TOTAL_FREED=$((TOTAL_FREED + size))
  rm -rf "$BREW_CACHE"/* 2>/dev/null || true
  echo "  Homebrew cache cleared ($((size / 1024))MB)"
fi

# pip
PIP_CACHE="$HOME_DIR/Library/Caches/pip"
if [ -d "$PIP_CACHE" ]; then
  size=$(safe_size "$PIP_CACHE")
  TOTAL_FREED=$((TOTAL_FREED + size))
  rm -rf "$PIP_CACHE" 2>/dev/null || true
  echo "  pip cache cleared ($((size / 1024))MB)"
fi

# npm
NPM_CACHE="$HOME_DIR/.npm"
if [ -d "$NPM_CACHE" ]; then
  size=$(safe_size "$NPM_CACHE")
  TOTAL_FREED=$((TOTAL_FREED + size))
  rm -rf "$NPM_CACHE"/_cacache 2>/dev/null || true
  echo "  npm cache cleared ($((size / 1024))MB)"
fi

# Xcode DerivedData
XCODE_DD="$HOME_DIR/Library/Developer/Xcode/DerivedData"
if [ -d "$XCODE_DD" ]; then
  size=$(safe_size "$XCODE_DD")
  TOTAL_FREED=$((TOTAL_FREED + size))
  rm -rf "$XCODE_DD"/* 2>/dev/null || true
  echo "  Xcode DerivedData cleared ($((size / 1024))MB)"
fi
echo ""

# 5. System Temp Files
echo "--- System Temp Files ---"
TEMP_COUNT=0
for pattern in "$HOME_DIR/Downloads"/*.tmp "$HOME_DIR/Downloads"/*.crdownload; do
  if [ -f "$pattern" ]; then
    size=$(safe_size "$pattern")
    TOTAL_FREED=$((TOTAL_FREED + size))
    rm -f "$pattern"
    TEMP_COUNT=$((TEMP_COUNT + 1))
  fi
done
echo "Removed $TEMP_COUNT temp/partial download files."
echo ""

# 6. Old Logs (older than 30 days)
echo "--- Old Logs ---"
LOG_DIR="$HOME_DIR/Library/Logs"
if [ -d "$LOG_DIR" ]; then
  OLD_LOG_SIZE=0
  find "$LOG_DIR" -type f -not -newermt "30 days ago" 2>/dev/null | while read -r f; do
    size=$(du -sk "$f" 2>/dev/null | awk '{print $1}')
    OLD_LOG_SIZE=$((OLD_LOG_SIZE + size))
    rm -f "$f" 2>/dev/null || true
  done
  echo "Cleared logs older than 30 days."
fi
echo ""

# Summary
FREED_MB=$((TOTAL_FREED / 1024))
echo "=== System Cache Cleanup Complete ==="
echo "Space recovered: approximately ${FREED_MB}MB (${TOTAL_FREED}K)"
echo ""
echo "Disk usage after cleanup:"
df -h "$HOME_DIR" | head -2

# Log
mkdir -p "$(dirname "$LOG_FILE")"
cat >> "$LOG_FILE" <<LOGEOF
========================================
System Cleanup: $(date '+%Y-%m-%d %H:%M:%S')
========================================
Space Recovered: ${FREED_MB}MB (${TOTAL_FREED}K)
Categories: User caches, browser caches, dev caches, temp files, old logs
Status: Success
========================================

LOGEOF

echo ""
echo "Log appended to $LOG_FILE"
