#!/bin/bash
set -e

# System Cache Cleanup
# Removes system caches, browser caches, development caches, temp files, and old logs.
#
# Every deletion goes through safe_trash / safe_trash_contents in _helpers.sh,
# which enforces the protection list (references/protected_patterns.txt), the
# whitelist, dry-run, and the per-item operations log.

export CLEANUP_MODE=system
source "$(dirname "$0")/_helpers.sh"

HOME_DIR="$HOME"

echo "=== System Cache Cleanup ==="
echo ""
start_run
echo "Disk usage before cleanup:"
df -h "$HOME_DIR" | head -2
echo ""

# Report Trash size (never auto-empty)
TRASH_DIR="$HOME_DIR/.Trash"
if [ -d "$TRASH_DIR" ]; then
  TRASH_SIZE=$(safe_size "$TRASH_DIR")
  echo "Current Trash size: $(format_size "$TRASH_SIZE")"
  echo "(Trash is not emptied automatically — empty via Finder when ready)"
  echo ""
fi

# 1. User Library Caches (preserving files modified in last 7 days)
# Apple caches are skipped by default (system-managed, frequently locked) except
# for an allowlist that is pure regenerable content. Browsers, messaging, and
# proxy caches are covered by the protection list. Anything whose owning
# process is running — or whose state cannot be determined — is left alone.
section "User Library Caches"
CACHE_DIR="$HOME_DIR/Library/Caches"
SAFE_APPLE_CACHES="
com.apple.helpd com.apple.QuickLook.thumbnailcache com.apple.iconservices
com.apple.iconservices.store com.apple.photoanalysisd com.apple.rosetta.update
com.apple.amp.mediasevicesd com.apple.WebKit.Networking
"
if [ -d "$CACHE_DIR" ]; then
  CACHE_SIZE=$(safe_size "$CACHE_DIR")
  echo "Total cache size: $(format_size "$CACHE_SIZE")"
  CACHE_RUNNING=0
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    cache_name=$(basename "$dir")
    case "$cache_name" in
      com.apple.*)
        echo "$SAFE_APPLE_CACHES" | grep -qw -- "$cache_name" || continue
        ;;
      # Handled surgically in section 4 (subdirectories only).
      Homebrew|pip|pypoetry|composer|org.swift.swiftpm|ms-playwright*) continue ;;
    esac
    if ! cache_owner_idle "$cache_name"; then
      CACHE_RUNNING=$((CACHE_RUNNING + 1))
      note_skip "$dir" "owner running or unknown"
      continue
    fi
    safe_trash "$dir"
  done < <(find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d -not -newermt "7 days ago" 2>/dev/null)
  echo "  Cleared caches older than 7 days (skipped $CACHE_RUNNING with a running owner)."
else
  echo "  No user cache directory found."
fi
echo ""

# 2. Application Support crash reports + auto-updater download caches
section "Application Support Caches"
CRASH_DIR="$HOME_DIR/Library/Application Support/CrashReporter"
[ -d "$CRASH_DIR" ] && safe_trash_contents "$CRASH_DIR"
# Sparkle/Squirrel updater caches (*-updater) hold downloaded update payloads.
# They regenerate on the next update check and hold no user or auth data.
# Only trash ones idle >30 days so an in-progress update is never interrupted.
UPDATER_DIR="$HOME_DIR/Library/Application Support/Caches"
if [ -d "$UPDATER_DIR" ]; then
  while IFS= read -r upd; do
    [ -z "$upd" ] && continue
    is_recently_modified "$upd" 30 && continue
    safe_trash "$upd"
  done < <(find "$UPDATER_DIR" -mindepth 1 -maxdepth 1 -type d -name "*-updater" 2>/dev/null)
fi
# GoogleUpdater keeps downloaded CRX payloads in crx_cache and leaves superseded
# updater builds beside the Current symlink. Both regenerate on the next update
# check. crx_cache is rewritten on every check, so a 7-day idle guard is enough.
GU_DIR="$HOME_DIR/Library/Application Support/Google/GoogleUpdater"
if [ -d "$GU_DIR" ]; then
  if [ -d "$GU_DIR/crx_cache" ] && ! is_recently_modified "$GU_DIR/crx_cache" 7; then
    safe_trash_contents "$GU_DIR/crx_cache"
  fi
  GU_CURRENT=$(readlink "$GU_DIR/Current" 2>/dev/null || true)
  if [ -n "$GU_CURRENT" ]; then
    for gu_ver in "$GU_DIR"/[0-9]*.[0-9]*/; do
      [ -d "$gu_ver" ] || continue
      [ "$(basename "$gu_ver")" = "$GU_CURRENT" ] && continue
      safe_trash "${gu_ver%/}"
    done
  fi
fi
# Saved window/document state — regenerated on next launch. 30-day idle guard
# so an app you have not opened recently still restores its windows.
SAVED_STATE="$HOME_DIR/Library/Saved Application State"
if [ -d "$SAVED_STATE" ]; then
  SS_COUNT=0
  while IFS= read -r ss; do
    [ -z "$ss" ] && continue
    safe_trash "$ss" >/dev/null
    SS_COUNT=$((SS_COUNT + 1))
  done < <(find "$SAVED_STATE" -mindepth 1 -maxdepth 1 -name "*.savedState" -not -newermt "30 days ago" 2>/dev/null)
  echo "  Saved Application State: trashed $SS_COUNT idle >30 days."
fi
echo ""

# 3. Browser Caches (report only — clearing these degrades daily browsing performance)
section "Browser Caches"
for browser_cache in \
  "$HOME_DIR/Library/Caches/Google/Chrome" \
  "$HOME_DIR/Library/Caches/com.apple.Safari" \
  "$HOME_DIR/Library/Caches/BraveSoftware" \
  "$HOME_DIR/Library/Caches/Firefox"; do
  if [ -d "$browser_cache" ]; then
    size=$(safe_size "$browser_cache")
    echo "  $(basename "$(dirname "$browser_cache")")/$(basename "$browser_cache"): $(format_size "$size") (report only — clear manually if needed)"
  fi
done
# Chrome per-profile caches (Service Worker, GPUCache, GrShaderCache)
CHROME_DIR="$HOME_DIR/Library/Application Support/Google/Chrome"
if [ -d "$CHROME_DIR" ]; then
  CHROME_PROFILE_TOTAL=0
  while IFS= read -r cache_dir; do
    [ -z "$cache_dir" ] && continue
    size=$(safe_size "$cache_dir")
    _add_size CHROME_PROFILE_TOTAL "$size"
  done < <(find "$CHROME_DIR" -maxdepth 3 -type d \( -name "CacheStorage" -o -name "GPUCache" -o -name "GrShaderCache" -o -name "Code Cache" \) 2>/dev/null)
  if [ "$CHROME_PROFILE_TOTAL" -gt 0 ]; then
    echo "  Chrome profile caches (all profiles): $(format_size "$CHROME_PROFILE_TOTAL") (report only — clear via Chrome settings)"
  fi
fi
echo ""

# 4. Development Caches
section "Development Caches"

# Homebrew: only downloads/ is a pure download cache. api/ is the formula
# index every brew command reads, bootsnap/ the Ruby load cache, locks/ live
# lock files — trashing those slows the next brew invocation for nothing.
BREW_CACHE="$HOME_DIR/Library/Caches/Homebrew"
[ -d "$BREW_CACHE/downloads" ] && safe_trash_contents "$BREW_CACHE/downloads"

# Package-manager and tool caches that regenerate on next use. Each entry is
# a directory whose contents are trashed; the directory itself stays.
REGENERABLE_CACHE_DIRS="
$HOME_DIR/Library/Caches/pip
$HOME_DIR/.npm/_cacache
$HOME_DIR/.npm/_npx
$HOME_DIR/.npm/_logs
$HOME_DIR/.npm/_prebuilds
$HOME_DIR/.cache/yarn
$HOME_DIR/.yarn/cache
$HOME_DIR/.local/share/pnpm/store
$HOME_DIR/Library/pnpm/store
$HOME_DIR/.cache/node/corepack
$HOME_DIR/.bun/install/cache
$HOME_DIR/.turbo/cache
$HOME_DIR/.cache/typescript
$HOME_DIR/.cache/electron
$HOME_DIR/.cache/node-gyp
$HOME_DIR/.node-gyp
$HOME_DIR/.cache/vite
$HOME_DIR/.cache/webpack
$HOME_DIR/.cache/eslint
$HOME_DIR/.cache/prettier
$HOME_DIR/.cache/puppeteer
$HOME_DIR/.cache/uv
$HOME_DIR/.cache/ruff
$HOME_DIR/.cache/mypy
$HOME_DIR/.cache/poetry
$HOME_DIR/Library/Caches/pypoetry/artifacts
$HOME_DIR/Library/Caches/pypoetry/cache
$HOME_DIR/.cache/pre-commit
$HOME_DIR/.pyenv/cache
$HOME_DIR/.cocoapods/cache
$HOME_DIR/.composer/cache
$HOME_DIR/Library/Caches/composer
$HOME_DIR/.bundle/cache
$HOME_DIR/.gem/specs
$HOME_DIR/go/pkg/mod/cache
$HOME_DIR/.rustup/downloads
$HOME_DIR/.cache/swift-package-manager
$HOME_DIR/Library/Caches/org.swift.swiftpm
$HOME_DIR/.docker/buildx/cache
$HOME_DIR/.kube/cache
$HOME_DIR/.aws/cli/cache
$HOME_DIR/.config/gcloud/logs
$HOME_DIR/.azure/logs
$HOME_DIR/.cache/curl
$HOME_DIR/.cache/wget
$HOME_DIR/.oh-my-zsh/cache
$HOME_DIR/Library/Caches/ms-playwright
$HOME_DIR/Library/Caches/ms-playwright-go
"
for cdir in $REGENERABLE_CACHE_DIRS; do
  [ -d "$cdir" ] && safe_trash_contents "$cdir"
done

# Cargo: registry/cache holds compressed crate downloads (re-fetched on demand);
# registry/src and git/ are the unpacked sources builds link against, so those
# stay report-only. Skipped entirely while cargo or rustc is running.
CARGO_HOME="${CARGO_HOME:-$HOME_DIR/.cargo}"
if [ -d "$CARGO_HOME/registry" ]; then
  if app_is_idle cargo && app_is_idle rustc; then
    [ -d "$CARGO_HOME/registry/cache" ] && safe_trash_contents "$CARGO_HOME/registry/cache"
  else
    echo "  cargo/rustc running or unknown — skipping ~/.cargo/registry/cache"
  fi
  for keep in "$CARGO_HOME/registry/src" "$CARGO_HOME/git"; do
    [ -d "$keep" ] && echo "  ${keep/#$HOME_DIR/~}: $(format_size "$(safe_size "$keep")") (report only — unpacked sources)"
  done
fi

# Gradle: build-cache-*, daemon logs, workers, notifications regenerate.
# caches/modules-* is the dependency store — report only.
if [ -d "$HOME_DIR/.gradle" ]; then
  if app_is_idle gradle && app_is_idle java; then
    for g in "$HOME_DIR/.gradle/daemon" "$HOME_DIR/.gradle/workers" "$HOME_DIR/.gradle/notifications"; do
      [ -d "$g" ] && safe_trash_contents "$g"
    done
    for g in "$HOME_DIR/.gradle/caches"/build-cache-*; do
      [ -d "$g" ] && safe_trash_contents "$g"
    done
  else
    echo "  gradle/java running or unknown — skipping ~/.gradle caches"
  fi
  for keep in "$HOME_DIR/.gradle/caches"/modules-*; do
    [ -d "$keep" ] && echo "  ${keep/#$HOME_DIR/~}: $(format_size "$(safe_size "$keep")") (report only — dependency store)"
  done
fi

# Claude Code native installs. The active version is whatever ~/.local/bin/claude
# resolves to — authoritative, so no mtime guard: a superseded binary is stale
# the moment the symlink moves, even if it was downloaded yesterday.
CLAUDE_VERSIONS="$HOME_DIR/.local/share/claude/versions"
if [ -d "$CLAUDE_VERSIONS" ]; then
  CLAUDE_ACTIVE=$(readlink -f "$HOME_DIR/.local/bin/claude" 2>/dev/null || true)
  case "$CLAUDE_ACTIVE" in
    "$CLAUDE_VERSIONS"/*)
      if [ -e "$CLAUDE_ACTIVE" ]; then
        for cv in "$CLAUDE_VERSIONS"/*; do
          [ -e "$cv" ] || continue
          [ "$cv" = "$CLAUDE_ACTIVE" ] && continue
          safe_trash "$cv"
        done
      else
        echo "  Claude Code: active version missing on disk — skipped"
      fi
      ;;
    *) echo "  Claude Code: active version unknown — skipped" ;;
  esac
fi
# Claude Desktop's bundled Claude Code runtimes. No symlink or config names the
# active one, so all but the highest version are report-only.
for cc_dir in "$HOME_DIR/Library/Application Support/Claude/claude-code-vm" \
              "$HOME_DIR/Library/Application Support/Claude/claude-code"; do
  [ -d "$cc_dir" ] || continue
  CC_NEWEST=$(ls "$cc_dir" 2>/dev/null | sort -V | tail -1)
  for cc_ver in "$cc_dir"/*/; do
    [ -d "$cc_ver" ] || continue
    [ "$(basename "$cc_ver")" = "$CC_NEWEST" ] && continue
    report_candidate "${cc_ver%/}" "Claude Desktop runtime — verify in Claude Desktop before deleting"
  done
done

# Expensive-to-rebuild caches are report-only. The Maven repository in
# particular can hold locally-built artifacts (mvn install) that exist nowhere
# else and cannot be re-downloaded.
for expensive in \
  "$HOME_DIR/.m2/repository" \
  "$HOME_DIR/.ivy2/cache" \
  "$HOME_DIR/.nuget/packages"; do
  if [ -d "$expensive" ]; then
    size=$(safe_size "$expensive")
    echo "  ${expensive/#$HOME_DIR/~}: $(format_size "$size") (report only — slow or impossible to rebuild)"
  fi
done

# Xcode. DerivedData is always regenerable. DeviceSupport keeps symbol files
# per connected-device OS version — the newest two are kept so a current and
# previous device still debug without a re-download. Simulator logs and the
# Xcode cache are only touched when no build tooling is running.
XCODE_DD="$HOME_DIR/Library/Developer/Xcode/DerivedData"
[ -d "$XCODE_DD" ] && safe_trash_contents "$XCODE_DD"
XCODE_IDLE=1
for xp in Xcode xcodebuild xctest XCTRunner Simulator XCBBuildService; do
  app_is_idle "$xp" || XCODE_IDLE=0
done
if [ "$XCODE_IDLE" = "1" ]; then
  for ds in "$HOME_DIR/Library/Developer/Xcode"/{iOS,watchOS,tvOS,visionOS}" DeviceSupport"; do
    [ -d "$ds" ] || continue
    KEEP=$(ls "$ds" 2>/dev/null | sort -V | tail -2)
    for ver in "$ds"/*/; do
      [ -d "$ver" ] || continue
      echo "$KEEP" | grep -qxF -- "$(basename "$ver")" && continue
      safe_trash "${ver%/}"
    done
  done
  [ -d "$HOME_DIR/Library/Logs/CoreSimulator" ] && safe_trash_contents "$HOME_DIR/Library/Logs/CoreSimulator"
  [ -d "$HOME_DIR/Library/Caches/com.apple.dt.Xcode" ] && safe_trash_contents "$HOME_DIR/Library/Caches/com.apple.dt.Xcode"
elif [ -d "$HOME_DIR/Library/Developer/Xcode" ]; then
  echo "  Xcode tooling running or unknown — skipping DeviceSupport, simulator logs, Xcode cache"
fi
XCODE_ARCH="$HOME_DIR/Library/Developer/Xcode/Archives"
if [ -d "$XCODE_ARCH" ]; then
  size=$(safe_size "$XCODE_ARCH")
  echo "  Xcode Archives: $(format_size "$size") (report only — delete manually if not needed)"
fi
CORE_SIM="$HOME_DIR/Library/Developer/CoreSimulator"
if [ -d "$CORE_SIM" ]; then
  size=$(safe_size "$CORE_SIM")
  echo "  CoreSimulator: $(format_size "$size") (report only — use 'xcrun simctl delete unavailable' to prune)"
fi

# Hugging Face (ML model cache — multi-GB re-downloads, report only)
HF_CACHE="$HOME_DIR/.cache/huggingface"
if [ -d "$HF_CACHE" ]; then
  size=$(safe_size "$HF_CACHE")
  echo "  ~/.cache/huggingface: $(format_size "$size") (report only — multi-GB model re-downloads)"
fi

# Gemini CLI browser profile (report only — contains OAuth tokens and auth state)
GEMINI_BROWSER="$HOME_DIR/.gemini/antigravity-browser-profile"
if [ -d "$GEMINI_BROWSER" ]; then
  size=$(safe_size "$GEMINI_BROWSER")
  echo "  Gemini browser profile: $(format_size "$size") (report only — contains auth state, delete manually if needed)"
fi

# Homebrew old formula versions (safe) and orphaned deps (report only)
if command -v brew &>/dev/null; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "  Homebrew: would run 'brew cleanup --prune=7' (skipped in dry-run)"
  else
    brew cleanup --prune=7 2>/dev/null || true
    echo "  Homebrew: cleaned old downloads (--prune=7)"
  fi
  # autoremove is report-only — can silently remove packages the user depends on
  ORPHANS=$(brew autoremove --dry-run 2>&1 | grep -E "^Uninstalling" || true)
  if [ -n "$ORPHANS" ]; then
    echo "  Homebrew orphaned deps (report only — run 'brew autoremove' manually):"
    echo "$ORPHANS" | sed 's/^/    /'
  fi
fi

# VS Code / Cursor extensions (report only)
for ext_dir in "$HOME_DIR/.vscode/extensions" "$HOME_DIR/.cursor/extensions"; do
  if [ -d "$ext_dir" ]; then
    size=$(safe_size "$ext_dir")
    count=$(find "$ext_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "  ${ext_dir/#$HOME_DIR/~}: $count installed, $(format_size "$size") (report only — uninstall unused via the editor)"
  fi
done

# Python venvs (report only here; purge mode trashes idle ones)
VENVS_DIR="$HOME_DIR/.venvs"
if [ -d "$VENVS_DIR" ]; then
  size=$(safe_size "$VENVS_DIR")
  count=$(find "$VENVS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo "  Python venvs: $count environments, $(format_size "$size") (report only — /cleanup purge trashes ones idle >90d)"
fi

# Docker (report only)
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  echo "  Docker disk usage:"
  docker system df 2>/dev/null | sed 's/^/    /'
  echo "  (Run 'docker system prune' manually to reclaim)"
fi
echo ""

# 5. Abandoned Dotdirs
# Scans ~ for dotdirs from tools no longer in use.
#
# Two tiers:
#   - REGENERABLE_DOTDIRS is an explicit allowlist of AI-agent / CLI-tool state
#     dirs that hold only caches, session logs, and settings that the tool
#     recreates on next launch. These are trashed when idle > DOTDIR_IDLE_DAYS.
#   - Everything else not in ACTIVE_DOTDIRS is report-only. The allowlist is
#     deliberately deny-by-default: a dotdir must be named here to be deleted,
#     because ~/.gnupg, ~/.ssh, ~/.ollama etc. hold keys or multi-GB models.
section "Abandoned Dotdirs"
# Known active dotdirs that should never be flagged
ACTIVE_DOTDIRS="
.cache .claude .config .cups .docker .gemini .local .mcp-auth .npm .ssh
.venvs .vscode .zsh_sessions .arxiv-mcp-server .Trash .git .gitconfig
.gitignore_global .zshrc .zprofile .zsh_history .CFUserTextEncoding
.bash_history .bash_profile .bashrc .profile .hushlogin .lesshst
.python_history .node_repl_history .wget-hsts .gnupg .ollama .lmstudio
"
# Agent/CLI tool state dirs — safe to trash once idle. Never add anything
# that stores keys, models, or user-authored content.
REGENERABLE_DOTDIRS="
.agent-manager .agents .cagent .codex .conductor .cursor .factory .grok
.grokbot .hermes .interpreter .kimi-code .kiro .mastracode .omp .paperclip
.pi .vibe .warp
"
DOTDIR_IDLE_DAYS=180
ABANDONED_TOTAL=0
ABANDONED_COUNT=0
DOTDIR_TRASHED=0
while IFS= read -r dotdir; do
  [ -z "$dotdir" ] && continue
  dirname=$(basename "$dotdir")
  [ -d "$dotdir" ] || continue
  if echo "$ACTIVE_DOTDIRS" | grep -qw "$dirname"; then
    continue
  fi
  size=$(safe_size "$dotdir")
  [ "$size" -ne 0 ] || continue
  if echo "$REGENERABLE_DOTDIRS" | grep -qw "$dirname" \
     && ! is_recently_modified "$dotdir" "$DOTDIR_IDLE_DAYS"; then
    safe_trash "$dotdir"
    DOTDIR_TRASHED=$((DOTDIR_TRASHED + 1))
    continue
  fi
  echo "  $dirname: $(format_size "$size")"
  _add_size ABANDONED_TOTAL "$size"
  ABANDONED_COUNT=$((ABANDONED_COUNT + 1))
done < <(find "$HOME_DIR" -maxdepth 1 -name ".*" -not -name "." -not -name ".." 2>/dev/null | sort)
[ "$DOTDIR_TRASHED" -gt 0 ] && echo "  Trashed $DOTDIR_TRASHED regenerable dotdir(s) idle > $DOTDIR_IDLE_DAYS days."
if [ "$ABANDONED_COUNT" -gt 0 ]; then
  echo "  Total: $ABANDONED_COUNT abandoned dotdir(s), $(format_size "$ABANDONED_TOTAL")"
  echo "  (report only — review and delete manually with: mv ~/.<name> ~/.Trash/)"
else
  echo "  No abandoned dotdirs found."
fi
echo ""

# 6. Sandboxed App Caches (Apple apps only — third-party caches can contain auth tokens)
# Always-resident analysis daemons recompute their caches on demand; those are
# cleared even while running (Mole does the same). Everything else waits for
# its owner to be idle.
section "Sandboxed App Caches"
SANDBOX_DIR="$HOME_DIR/Library/Containers"
ALWAYS_SAFE_CONTAINERS="
com.apple.mediaanalysisd com.apple.photoanalysisd com.apple.geod
com.apple.AMPArtworkAgent com.apple.AppleMediaServices
"
if [ -d "$SANDBOX_DIR" ]; then
  SANDBOX_TOTAL=0
  for cache_dir in "$SANDBOX_DIR"/*/Data/Library/Caches; do
    [ -d "$cache_dir" ] || continue
    container_id=$(echo "$cache_dir" | sed "s|$SANDBOX_DIR/||" | cut -d/ -f1)
    [[ "$container_id" != com.apple.* ]] && continue
    if ! echo "$ALWAYS_SAFE_CONTAINERS" | grep -qw -- "$container_id" \
       && ! cache_owner_idle "$container_id"; then
      note_skip "$cache_dir" "owner running or unknown"
      continue
    fi
    size=$(safe_size "$cache_dir")
    [ "$size" -gt 100 ] && safe_trash_contents "$cache_dir"
    _add_size SANDBOX_TOTAL "$size"
  done
  echo "  Sandboxed caches scanned (Apple apps only): $(format_size "$SANDBOX_TOTAL")"
else
  echo "  No sandboxed containers found."
fi
echo ""

# 7. App-Specific Caches (non-browser apps)
# Electron apps crash if cache is deleted while running — check first. An
# unknown process state counts as running.
section "App-Specific Caches"
if app_is_idle Discord; then
  for dc in "$HOME_DIR/Library/Application Support/discord/Cache" \
            "$HOME_DIR/Library/Application Support/discord/Code Cache"; do
    [ -d "$dc" ] && safe_trash "$dc"
  done
else
  echo "  Discord running or unknown — skipping cache"
fi

if app_is_idle Electron && app_is_idle Code; then
  for vc in "$HOME_DIR/Library/Application Support/Code/Cache" \
            "$HOME_DIR/Library/Application Support/Code/CachedData" \
            "$HOME_DIR/Library/Application Support/Code/CachedExtensionVSIXs" \
            "$HOME_DIR/Library/Application Support/Code/logs"; do
    [ -d "$vc" ] && safe_trash "$vc"
  done
else
  echo "  VS Code running or unknown — skipping cache"
fi

if app_is_idle Slack; then
  for sc in "$HOME_DIR/Library/Application Support/Slack/Cache" \
            "$HOME_DIR/Library/Application Support/Slack/Code Cache"; do
    [ -d "$sc" ] && safe_trash "$sc"
  done
else
  echo "  Slack running or unknown — skipping cache"
fi

ZOOM_CACHE="$HOME_DIR/Library/Application Support/zoom.us/data/zoomcache"
if [ -d "$ZOOM_CACHE" ]; then
  if app_is_idle zoom.us; then
    safe_trash "$ZOOM_CACHE"
  else
    echo "  Zoom running or unknown — skipping cache"
  fi
fi
echo ""

# 8. Application Support Logs & Caches
# Chromium leaf directories (GPUCache, Code Cache, Dawn*) are regenerable by
# construction. A directory merely *named* Cache/Caches/CachedData is only
# eligible when a Chromium marker sits beside it — proof of an Electron layout
# rather than an app using "Cache" for real data. Logs are always eligible.
section "Application Support Logs & Caches"
AS_DIR="$HOME_DIR/Library/Application Support"
AS_TOTAL=0
has_chromium_marker() {
  [ -d "$1/Code Cache" ] || [ -d "$1/GPUCache" ] || [ -d "$1/DawnGraphiteCache" ] || [ -d "$1/DawnWebGPUCache" ]
}
# Electron layouts may be per-profile (Codex/Default/GPUCache), so look two deep.
is_electron_app_dir() {
  find "$1" -mindepth 1 -maxdepth 2 -type d \( -name "Code Cache" -o -name "GPUCache" \) -print -quit 2>/dev/null | grep -q .
}
if [ -d "$AS_DIR" ]; then
  for app_dir in "$AS_DIR"/*/; do
    [ -d "$app_dir" ] || continue
    app_name=$(basename "$app_dir")
    # Chrome per-profile caches are report-only in section 3; Claude is
    # session mode's responsibility. Everything else is gated by the
    # protection list inside safe_trash_contents.
    case "$app_name" in
      Google|Claude) continue ;;
    esac
    if is_electron_app_dir "$app_dir" && ! cache_owner_idle "$app_name"; then
      echo "  $app_name running or unknown — skipping cache"
      note_skip "$app_dir" "owner running or unknown"
      continue
    fi
    # Depth 2 catches per-profile dirs (Codex/Default/GPUCache)
    while IFS= read -r subdir; do
      [ -z "$subdir" ] && continue
      case "$(basename "$subdir")" in
        Cache|Caches|CachedData)
          has_chromium_marker "$(dirname "$subdir")" || continue ;;
      esac
      size=$(safe_size "$subdir")
      if [ "$size" -gt 1024 ] || [ "$size" -lt 0 ]; then
        safe_trash_contents "$subdir"
        _add_size AS_TOTAL "$size"
      fi
    done < <(find "$app_dir" -mindepth 1 -maxdepth 2 -type d \( \
      -name "Cache" -o -name "Caches" -o -name "Code Cache" -o -name "logs" -o -name "Logs" \
      -o -name "CachedData" -o -name "GPUCache" -o -name "GPUPersistentCache" -o -name "DawnCache" \
      -o -name "GrShaderCache" -o -name "GraphiteDawnCache" \
      -o -name "DawnGraphiteCache" -o -name "DawnWebGPUCache" \) 2>/dev/null)
    [ -d "$app_dir/Crashpad/completed" ] && safe_trash_contents "$app_dir/Crashpad/completed"
  done
  echo "  Application Support caches/logs cleared: $(format_size "$AS_TOTAL")"
fi
echo ""

# 9. Claude debug/telemetry logs
section "Claude Debug & Telemetry"
for cdir in "$HOME_DIR/.claude/debug" "$HOME_DIR/.claude/telemetry" "$HOME_DIR/.gemini/tmp"; do
  if [ -d "$cdir" ]; then
    size=$(safe_size "$cdir")
    if [ "$size" -gt 100 ] || [ "$size" -lt 0 ]; then
      safe_trash_contents "$cdir"
    fi
  fi
done
echo ""

# 10. iOS Device Backups (report only) and firmware downloads
section "iOS Device Backups & Firmware"
BACKUP_DIR="$HOME_DIR/Library/Application Support/MobileSync/Backup"
if [ -d "$BACKUP_DIR" ]; then
  size=$(safe_size "$BACKUP_DIR")
  count=$(find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo "  $count backup(s), $(format_size "$size") total (report only — delete via Finder > iPhone settings)"
else
  echo "  No iOS backups found."
fi
# .ipsw firmware images are re-downloaded by Finder on the next restore.
IPSW_COUNT=0
for fw_dir in "$HOME_DIR/Library/iTunes"/*" Software Updates"; do
  [ -d "$fw_dir" ] || continue
  for ipsw in "$fw_dir"/*.ipsw; do
    [ -f "$ipsw" ] || continue
    safe_trash "$ipsw"
    IPSW_COUNT=$((IPSW_COUNT + 1))
  done
done
[ "$IPSW_COUNT" -gt 0 ] && echo "  Trashed $IPSW_COUNT firmware image(s)."
echo ""

# 11. Incomplete downloads. A file still held open by a downloader is in
# progress, not abandoned — lsof decides.
section "Incomplete Downloads"
TEMP_COUNT=0
for pattern in "$HOME_DIR/Downloads"/*.tmp "$HOME_DIR/Downloads"/*.crdownload \
               "$HOME_DIR/Downloads"/*.part "$HOME_DIR/Downloads"/*.partial \
               "$HOME_DIR/Downloads"/*.download; do
  [ -e "$pattern" ] || continue
  if lsof -t -- "$pattern" >/dev/null 2>&1; then
    note_skip "$pattern" "open by a process"
    continue
  fi
  safe_trash "$pattern"
  TEMP_COUNT=$((TEMP_COUNT + 1))
done
echo "  Removed $TEMP_COUNT incomplete download(s)."
echo ""

# 12. Old Logs (older than 30 days)
section "Old Logs"
LOG_DIR="$HOME_DIR/Library/Logs"
if [ -d "$LOG_DIR" ]; then
  OLD_COUNT=0
  while IFS= read -r f; do
    safe_trash "$f" >/dev/null
    OLD_COUNT=$((OLD_COUNT + 1))
  done < <(find "$LOG_DIR" -type f -not -newermt "30 days ago" 2>/dev/null)
  echo "  Cleared $OLD_COUNT log files older than 30 days."
fi
echo ""

# 13. Time Machine Local Snapshots (report only)
section "Time Machine Snapshots"
# tmutil always prints a "Snapshots for disk /:" header, so count only the
# com.apple.TimeMachine entries rather than every output line.
SNAP_COUNT=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "com.apple.TimeMachine" || true)
SNAP_COUNT=${SNAP_COUNT:-0}
if [ "$SNAP_COUNT" -gt 0 ]; then
  echo "  $SNAP_COUNT local snapshot(s) found (run 'sudo tmutil deletelocalsnapshots <date>' to remove)"
else
  echo "  No local snapshots."
fi
echo ""

# Summary
echo "=== System Cache Cleanup Complete ==="
if [ "$DRY_RUN" = "1" ]; then
  echo "Would recover: approximately $(format_size "$TOTAL_FREED") ($TRASHED_COUNT items)"
else
  echo "Space recovered: approximately $(format_size "$TOTAL_FREED") ($TRASHED_COUNT items)"
fi
[ "$SKIPPED_COUNT" -gt 0 ] && echo "Skipped (protected/whitelisted/running): $SKIPPED_COUNT item(s) — see $OPLOG"
if [ "$TOTAL_FAILED" -gt 0 ]; then
  echo "Failed to trash: $TOTAL_FAILED item(s) — see errors above"
fi
echo ""
echo "Disk free space is unchanged until the Trash is emptied — everything above"
echo "was moved to ~/.Trash on the same volume, not deleted."
echo "Per-item log: $OPLOG"

finish_run
