#!/bin/bash
set -e

# System Cache Cleanup
# Removes system caches, browser caches, development caches, temp files, and old logs.

source "$(dirname "$0")/_helpers.sh"

HOME_DIR="$HOME"
LOG_FILE="$HOME_DIR/.claude/system-cleanup-log.txt"

echo "=== System Cache Cleanup ==="
echo ""
echo "Disk usage before cleanup:"
df -h "$HOME_DIR" | head -2
echo ""

# Report Trash size (never auto-empty)
TRASH_DIR="$HOME_DIR/.Trash"
if [ -d "$TRASH_DIR" ]; then
  TRASH_SIZE=$(safe_size "$TRASH_DIR")
  echo "Current Trash size: $(format_size $TRASH_SIZE)"
  echo "(Trash is not emptied automatically — empty via Finder when ready)"
  echo ""
fi

# 1. User Library Caches (preserving files modified in last 7 days)
# Skip caches for browsers, messaging apps, and other daily-use apps
# whose auth/session state may live in cache directories.
echo "--- User Library Caches ---"
CACHE_DIR="$HOME_DIR/Library/Caches"
if [ -d "$CACHE_DIR" ]; then
  CACHE_SIZE=$(safe_size "$CACHE_DIR")
  echo "Total cache size: $(format_size $CACHE_SIZE)"
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    cache_name=$(basename "$dir")
    # Skip browsers (report-only in section 3)
    case "$cache_name" in
      *Google*|*Chrome*|*Safari*|*Firefox*|*Brave*) continue ;;
    esac
    # Skip messaging apps (auth tokens often in cache)
    case "$cache_name" in
      *whatsapp*|*WhatsApp*|*telegram*|*Telegram*|*tencent*|*WeChat*) continue ;;
      *Signal*|*discord*|*Discord*|*Slack*|*slack*) continue ;;
    esac
    # Skip other daily-use apps
    case "$cache_name" in
      *Surge*|*surge*) continue ;;
    esac
    safe_trash "$dir"
  done < <(find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d -not -newermt "7 days ago" 2>/dev/null)
  echo "  Cleared caches older than 7 days (skipped browsers, messaging, and daily apps)."
else
  echo "  No user cache directory found."
fi
echo ""

# 2. Application Support crash reports
echo "--- Application Support Caches ---"
CRASH_DIR="$HOME_DIR/Library/Application Support/CrashReporter"
[ -d "$CRASH_DIR" ] && safe_trash_contents "$CRASH_DIR"
echo ""

# 3. Browser Caches (report only — clearing these degrades daily browsing performance)
echo "--- Browser Caches ---"
for browser_cache in \
  "$HOME_DIR/Library/Caches/Google/Chrome" \
  "$HOME_DIR/Library/Caches/com.apple.Safari" \
  "$HOME_DIR/Library/Caches/BraveSoftware" \
  "$HOME_DIR/Library/Caches/Firefox"; do
  if [ -d "$browser_cache" ]; then
    size=$(safe_size "$browser_cache")
    echo "  $(basename "$(dirname "$browser_cache")")/$(basename "$browser_cache"): $(format_size $size) (report only — clear manually if needed)"
  fi
done
# Chrome per-profile caches (Service Worker, GPUCache, GrShaderCache)
CHROME_DIR="$HOME_DIR/Library/Application Support/Google/Chrome"
if [ -d "$CHROME_DIR" ]; then
  CHROME_PROFILE_TOTAL=0
  while IFS= read -r cache_dir; do
    [ -z "$cache_dir" ] && continue
    size=$(safe_size "$cache_dir")
    CHROME_PROFILE_TOTAL=$((CHROME_PROFILE_TOTAL + size))
  done < <(find "$CHROME_DIR" -maxdepth 3 -type d \( -name "CacheStorage" -o -name "GPUCache" -o -name "GrShaderCache" -o -name "Code Cache" \) 2>/dev/null)
  if [ "$CHROME_PROFILE_TOTAL" -gt 0 ]; then
    echo "  Chrome profile caches (all profiles): $(format_size $CHROME_PROFILE_TOTAL) (report only — clear via Chrome settings)"
  fi
fi
echo ""

# 4. Development Caches
echo "--- Development Caches ---"

# Homebrew
BREW_CACHE="$HOME_DIR/Library/Caches/Homebrew"
if [ -d "$BREW_CACHE" ]; then
  size=$(safe_size "$BREW_CACHE")
  safe_trash_contents "$BREW_CACHE"
fi

# pip
PIP_CACHE="$HOME_DIR/Library/Caches/pip"
[ -d "$PIP_CACHE" ] && safe_trash "$PIP_CACHE"

# npm
NPM_CACHE="$HOME_DIR/.npm/_cacache"
[ -d "$NPM_CACHE" ] && safe_trash "$NPM_CACHE"

# npx cached packages
NPX_CACHE="$HOME_DIR/.npm/_npx"
[ -d "$NPX_CACHE" ] && safe_trash "$NPX_CACHE"

# Yarn
for yarn_cache in "$HOME_DIR/.cache/yarn" "$HOME_DIR/.yarn/cache"; do
  [ -d "$yarn_cache" ] && safe_trash "$yarn_cache"
done

# pnpm
PNPM_CACHE="$HOME_DIR/.local/share/pnpm/store"
[ -d "$PNPM_CACHE" ] && safe_trash "$PNPM_CACHE"

# Go modules
GO_CACHE="$HOME_DIR/go/pkg/mod/cache"
[ -d "$GO_CACHE" ] && safe_trash "$GO_CACHE"

# Rust/Cargo registry
CARGO_CACHE="$HOME_DIR/.cargo/registry"
[ -d "$CARGO_CACHE" ] && safe_trash "$CARGO_CACHE"

# Maven
MAVEN_CACHE="$HOME_DIR/.m2/repository"
[ -d "$MAVEN_CACHE" ] && safe_trash "$MAVEN_CACHE"

# Gradle
GRADLE_CACHE="$HOME_DIR/.gradle/caches"
[ -d "$GRADLE_CACHE" ] && safe_trash "$GRADLE_CACHE"

# CocoaPods (cache only — repos and config must be preserved)
COCOAPODS_CACHE="$HOME_DIR/.cocoapods/cache"
[ -d "$COCOAPODS_CACHE" ] && safe_trash "$COCOAPODS_CACHE"

# Composer
COMPOSER_CACHE="$HOME_DIR/.composer/cache"
[ -d "$COMPOSER_CACHE" ] && safe_trash "$COMPOSER_CACHE"

# uv (Python)
UV_CACHE="$HOME_DIR/.cache/uv"
[ -d "$UV_CACHE" ] && safe_trash "$UV_CACHE"

# Ruby Bundler
BUNDLER_CACHE="$HOME_DIR/.bundle/cache"
[ -d "$BUNDLER_CACHE" ] && safe_trash "$BUNDLER_CACHE"

# Xcode DerivedData
XCODE_DD="$HOME_DIR/Library/Developer/Xcode/DerivedData"
if [ -d "$XCODE_DD" ]; then
  safe_trash_contents "$XCODE_DD"
fi

# Xcode Archives
XCODE_ARCH="$HOME_DIR/Library/Developer/Xcode/Archives"
if [ -d "$XCODE_ARCH" ]; then
  size=$(safe_size "$XCODE_ARCH")
  echo "  Xcode Archives: $(format_size $size) (report only — delete manually if not needed)"
fi

# CoreSimulator
CORE_SIM="$HOME_DIR/Library/Developer/CoreSimulator"
if [ -d "$CORE_SIM" ]; then
  size=$(safe_size "$CORE_SIM")
  echo "  CoreSimulator: $(format_size $size) (report only — use 'xcrun simctl delete unavailable' to prune)"
fi

# Playwright (browser binaries for testing)
for pw_cache in "$HOME_DIR/Library/Caches/ms-playwright" "$HOME_DIR/Library/Caches/ms-playwright-go"; do
  [ -d "$pw_cache" ] && safe_trash "$pw_cache"
done

# Hugging Face (ML model cache)
HF_CACHE="$HOME_DIR/.cache/huggingface"
[ -d "$HF_CACHE" ] && safe_trash "$HF_CACHE"

# Gemini CLI browser profile (report only — contains OAuth tokens and auth state)
GEMINI_BROWSER="$HOME_DIR/.gemini/antigravity-browser-profile"
if [ -d "$GEMINI_BROWSER" ]; then
  size=$(safe_size "$GEMINI_BROWSER")
  echo "  Gemini browser profile: $(format_size $size) (report only — contains auth state, delete manually if needed)"
fi

# Homebrew old formula versions (safe) and orphaned deps (report only)
if command -v brew &>/dev/null; then
  brew cleanup --prune=7 2>/dev/null || true
  echo "  Homebrew: cleaned old downloads (--prune=7)"
  # autoremove is report-only — can silently remove packages the user depends on
  ORPHANS=$(brew autoremove --dry-run 2>&1 | grep -E "^Uninstalling" || true)
  if [ -n "$ORPHANS" ]; then
    echo "  Homebrew orphaned deps (report only — run 'brew autoremove' manually):"
    echo "$ORPHANS" | sed 's/^/    /'
  fi
fi

# VS Code extensions (report only)
VSCODE_EXT="$HOME_DIR/.vscode/extensions"
if [ -d "$VSCODE_EXT" ]; then
  size=$(safe_size "$VSCODE_EXT")
  count=$(find "$VSCODE_EXT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo "  VS Code extensions: $count installed, $(format_size $size) (report only — uninstall unused via VS Code)"
fi

# Cursor extensions (report only)
CURSOR_EXT="$HOME_DIR/.cursor/extensions"
if [ -d "$CURSOR_EXT" ]; then
  size=$(safe_size "$CURSOR_EXT")
  count=$(find "$CURSOR_EXT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo "  Cursor extensions: $count installed, $(format_size $size) (report only — uninstall unused via Cursor)"
fi

# Python venvs (report only — flag stale ones)
VENVS_DIR="$HOME_DIR/.venvs"
if [ -d "$VENVS_DIR" ]; then
  size=$(safe_size "$VENVS_DIR")
  count=$(find "$VENVS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo "  Python venvs: $count environments, $(format_size $size) (report only — review for stale projects)"
fi

# Docker (report only)
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  echo "  Docker disk usage:"
  docker system df 2>/dev/null | sed 's/^/    /'
  echo "  (Run 'docker system prune' manually to reclaim)"
fi
echo ""

# 5. Sandboxed App Caches (Apple apps only — third-party caches can contain auth tokens)
echo "--- Sandboxed App Caches ---"
SANDBOX_DIR="$HOME_DIR/Library/Containers"
if [ -d "$SANDBOX_DIR" ]; then
  SANDBOX_TOTAL=0
  for cache_dir in "$SANDBOX_DIR"/*/Data/Library/Caches; do
    [ -d "$cache_dir" ] || continue
    # Only clear Apple app caches — third-party apps (WhatsApp, Telegram, etc.)
    # may store session/auth data in their cache directories
    container_id=$(echo "$cache_dir" | sed "s|$SANDBOX_DIR/||" | cut -d/ -f1)
    [[ "$container_id" != com.apple.* ]] && continue
    size=$(safe_size "$cache_dir")
    [ "$size" -gt 100 ] && safe_trash_contents "$cache_dir"
    SANDBOX_TOTAL=$((SANDBOX_TOTAL + size))
  done
  echo "  Sandboxed caches scanned (Apple apps only): $(format_size $SANDBOX_TOTAL)"
else
  echo "  No sandboxed containers found."
fi
echo ""

# 6. App-Specific Caches (non-browser apps)
# Electron apps crash if cache is deleted while running — check first.
echo "--- App-Specific Caches ---"
if is_app_running "Discord"; then
  echo "  Discord is running — skipping cache (quit Discord first)"
else
  for dc in "$HOME_DIR/Library/Application Support/discord/Cache" \
            "$HOME_DIR/Library/Application Support/discord/Code Cache"; do
    [ -d "$dc" ] && safe_trash "$dc"
  done
fi

if is_app_running "Electron" || is_app_running "Code"; then
  echo "  VS Code is running — skipping cache (quit VS Code first)"
else
  for vc in "$HOME_DIR/Library/Application Support/Code/Cache" \
            "$HOME_DIR/Library/Application Support/Code/CachedData" \
            "$HOME_DIR/Library/Application Support/Code/logs"; do
    [ -d "$vc" ] && safe_trash "$vc"
  done
fi

if is_app_running "Slack"; then
  echo "  Slack is running — skipping cache (quit Slack first)"
else
  for sc in "$HOME_DIR/Library/Application Support/Slack/Cache" \
            "$HOME_DIR/Library/Application Support/Slack/Code Cache"; do
    [ -d "$sc" ] && safe_trash "$sc"
  done
fi

# Zoom (handles missing cache gracefully)
ZOOM_CACHE="$HOME_DIR/Library/Application Support/zoom.us/data/zoomcache"
[ -d "$ZOOM_CACHE" ] && safe_trash "$ZOOM_CACHE"
echo ""

# 7. Application Support Logs & Caches
echo "--- Application Support Logs & Caches ---"
AS_DIR="$HOME_DIR/Library/Application Support"
AS_TOTAL=0
if [ -d "$AS_DIR" ]; then
  for app_dir in "$AS_DIR"/*/; do
    [ -d "$app_dir" ] || continue
    app_name=$(basename "$app_dir")
    # Skip Apple system dirs and known important dirs
    [[ "$app_name" == com.apple.* ]] && continue
    [[ "$app_name" == Apple ]] && continue
    [[ "$app_name" == Knowledge ]] && continue
    [[ "$app_name" == MobileSync ]] && continue
    [[ "$app_name" == Claude ]] && continue
    [[ "$app_name" == obsidian ]] && continue
    for sub in "Cache" "Caches" "logs" "Logs" "CachedData" "GPUCache"; do
      subdir="$app_dir$sub"
      if [ -d "$subdir" ]; then
        size=$(safe_size "$subdir")
        if [ "$size" -gt 1024 ]; then
          safe_trash_contents "$subdir"
          AS_TOTAL=$((AS_TOTAL + size))
        fi
      fi
    done
  done
  echo "  Application Support caches/logs cleared: $(format_size $AS_TOTAL)"
fi
echo ""

# 9. iOS Device Backups (report only)
echo "--- iOS Device Backups ---"
BACKUP_DIR="$HOME_DIR/Library/Application Support/MobileSync/Backup"
if [ -d "$BACKUP_DIR" ]; then
  size=$(safe_size "$BACKUP_DIR")
  count=$(find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo "  $count backup(s), $(format_size $size) total (report only — delete via Finder > iPhone settings)"
else
  echo "  No iOS backups found."
fi
echo ""

# 10. System Temp Files
echo "--- System Temp Files ---"
TEMP_COUNT=0
for pattern in "$HOME_DIR/Downloads"/*.tmp "$HOME_DIR/Downloads"/*.crdownload; do
  if [ -f "$pattern" ]; then
    safe_trash "$pattern"
    TEMP_COUNT=$((TEMP_COUNT + 1))
  fi
done
echo "  Removed $TEMP_COUNT temp/partial download files."
echo ""

# 11. Old Logs (older than 30 days)
echo "--- Old Logs ---"
LOG_DIR="$HOME_DIR/Library/Logs"
if [ -d "$LOG_DIR" ]; then
  OLD_COUNT=0
  while IFS= read -r f; do
    safe_trash "$f"
    OLD_COUNT=$((OLD_COUNT + 1))
  done < <(find "$LOG_DIR" -type f -not -newermt "30 days ago" 2>/dev/null)
  echo "  Cleared $OLD_COUNT log files older than 30 days."
fi
echo ""

# 12. Time Machine Local Snapshots (report only)
echo "--- Time Machine Snapshots ---"
SNAPSHOTS=$(tmutil listlocalsnapshots / 2>/dev/null || true)
if [ -n "$SNAPSHOTS" ]; then
  SNAP_COUNT=$(echo "$SNAPSHOTS" | wc -l | tr -d ' ')
  echo "  $SNAP_COUNT local snapshot(s) found (run 'sudo tmutil deletelocalsnapshots <date>' to remove)"
else
  echo "  No local snapshots."
fi
echo ""

# Summary
FREED_MB=$((TOTAL_FREED / 1024))
echo "=== System Cache Cleanup Complete ==="
echo "Space recovered: approximately $(format_size $TOTAL_FREED)"
echo ""
echo "Disk usage after cleanup:"
df -h "$HOME_DIR" | head -2

# Log
mkdir -p "$(dirname "$LOG_FILE")"
cat >> "$LOG_FILE" <<LOGEOF
========================================
System Cleanup: $(date '+%Y-%m-%d %H:%M:%S')
========================================
Space Recovered: $(format_size $TOTAL_FREED)
Categories: User caches, browser caches, dev caches, temp files, old logs
Status: Success
========================================

LOGEOF

echo ""
echo "Log appended to $LOG_FILE"
