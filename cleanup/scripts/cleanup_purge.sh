#!/bin/bash
set -e

# Project Artifact Purge
# Scans code directories for stale build artifacts (node_modules, target/, .build/, etc.)
# and moves them to Trash. Only targets artifacts older than 30 days by default.
# Compatible with macOS bash 3.2 (no associative arrays).

export CLEANUP_MODE=purge
source "$(dirname "$0")/_helpers.sh"

HOME_DIR="$HOME"
PATHS_FILE="$HOME_DIR/.claude/cleanup-purge-paths.txt"
MIN_AGE_DAYS=30
MAX_DEPTH=6
# Any directory carrying this file declares itself a regenerable cache
# (https://bford.info/cachedir/), whatever it is named.
CACHEDIR_SIG="Signature: 8a477f597d28d172789f06886806bc55"

echo "=== Project Artifact Purge ==="
echo ""
start_run

# Load scan paths from config or use defaults
SCAN_DIRS=()
if [ -f "$PATHS_FILE" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue
    expanded="${line/#\~/$HOME_DIR}"
    [ -d "$expanded" ] && SCAN_DIRS+=("$expanded")
  done < "$PATHS_FILE"
fi

# Defaults if no config or all paths invalid. Agent worktrees are checkouts
# nobody opens by hand and accumulate full node_modules per branch.
if [ ${#SCAN_DIRS[@]} -eq 0 ]; then
  for d in \
    "$HOME_DIR/Code" \
    "$HOME_DIR/Projects" \
    "$HOME_DIR/dev" \
    "$HOME_DIR/GitHub" \
    "$HOME_DIR/Repos" \
    "$HOME_DIR/Workspace" \
    "$HOME_DIR/Development" \
    "$HOME_DIR/.claude/worktrees" \
    "$HOME_DIR/.codex/worktrees"; do
    [ -d "$d" ] && SCAN_DIRS+=("$d")
  done
fi

if [ ${#SCAN_DIRS[@]} -eq 0 ]; then
  echo "No code directories found to scan."
  echo "Create $PATHS_FILE with one directory per line to configure."
  finish_run
  exit 0
fi

echo "Scanning directories:"
for d in "${SCAN_DIRS[@]}"; do
  echo "  $d"
done
echo ""

# Artifact patterns (bash 3.2 compatible — no associative arrays)
# Only unambiguously generated artifacts.
# Excluded: build, dist, coverage — too generic, often git-tracked.
# bin and vendor are conditional (see is_purge_target).
ARTIFACT_NAMES=(
  node_modules .next .nuxt .output target .build
  __pycache__ .pytest_cache .mypy_cache .ruff_cache .tox .nox .eggs
  .venv venv
  .gradle .parcel-cache .turbo .angular .svelte-kit .astro .expo
  .terragrunt-cache .zig-cache zig-out .cxx
  Pods .dart_tool bin vendor
)

# Cloud-synced trees are never purged: a trashed node_modules re-syncs from
# the other end, and the sync client fights the move. Physical path decides,
# so the ~/gdrive-* symlinks resolve correctly. Covers both File Provider
# mounts (~/Library/CloudStorage) and mirror folders (~/My Drive, ~/Sync).
is_cloud_synced() {
  local physical
  physical=$(cd "$1" 2>/dev/null && /bin/pwd -P) || return 1
  case "$physical" in
    "$HOME_DIR/Library/CloudStorage"/*|"$HOME_DIR/Library/Mobile Documents"/*) return 0 ;;
    "$HOME_DIR/My Drive"*|"$HOME_DIR/Google Drive"*|"$HOME_DIR/Dropbox"*|"$HOME_DIR/OneDrive"*) return 0 ;;
    "$HOME_DIR/Sync"|"$HOME_DIR/Sync"/*|"$HOME_DIR/iCloud Drive"*) return 0 ;;
  esac
  return 1
}

has_cachedir_tag() {
  [ -f "$1/CACHEDIR.TAG" ] || return 1
  [ "$(head -c 43 "$1/CACHEDIR.TAG" 2>/dev/null)" = "$CACHEDIR_SIG" ]
}

# Name-based targets are unconditional except:
#   bin     only a .NET build output (a *.csproj/.fsproj/.vbproj sibling and a
#           Debug/ or Release/ child) — Go and scripts keep sources in bin/
#   vendor  only Composer's (composer.json sibling) — Go and Rails vendor source
is_purge_target() {
  local dir="$1" name parent
  name=$(basename "$dir")
  parent=$(dirname "$dir")
  case "$name" in
    bin)
      local proj found=0
      for proj in "$parent"/*.csproj "$parent"/*.fsproj "$parent"/*.vbproj; do
        [ -e "$proj" ] && { found=1; break; }
      done
      [ "$found" = 1 ] || return 1
      [ -d "$dir/Debug" ] || [ -d "$dir/Release" ] || return 1
      ;;
    vendor)
      [ -f "$parent/composer.json" ] || return 1
      ;;
  esac
  return 0
}

# A tracked file anywhere inside the artifact means the repo ships it (the
# .gitignore does not cover it) — never purge those. A nested .git means it is
# a project of its own, not an artifact.
is_git_tracked() {
  local dir="$1"
  [ -e "$dir/.git" ] && return 0
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  git -C "$dir" ls-files --error-unmatch -- . >/dev/null 2>&1
}

# Emit candidate directories under a root: every ARTIFACT_NAMES match plus any
# dir with a CACHEDIR.TAG. fd prunes matched trees so nested artifacts are not
# listed twice; the find fallback does the same with -prune.
find_candidates() {
  local root="$1"
  local name_args=() first=1 n
  if command -v fd >/dev/null 2>&1; then
    local pat=""
    for n in "${ARTIFACT_NAMES[@]}"; do
      pat="${pat:+$pat|}$(printf '%s' "$n" | sed 's/\./\\./g')"
    done
    fd --hidden --no-ignore --type d --min-depth 1 --max-depth "$MAX_DEPTH" --prune \
       --exclude .git --exclude .Trash --absolute-path \
       "^($pat)$" "$root" 2>/dev/null
    fd --hidden --no-ignore --type f --min-depth 2 --max-depth $((MAX_DEPTH + 1)) \
       --exclude .git --exclude .Trash --absolute-path \
       '^CACHEDIR\.TAG$' "$root" 2>/dev/null -x dirname {}
  else
    for n in "${ARTIFACT_NAMES[@]}"; do
      if [ "$first" = 1 ]; then name_args+=(-name "$n"); first=0
      else name_args+=(-o -name "$n"); fi
    done
    find "$root" -maxdepth "$MAX_DEPTH" -name .git -prune -o \
      -type d \( "${name_args[@]}" \) -print -prune 2>/dev/null
    find "$root" -maxdepth $((MAX_DEPTH + 1)) -name .git -prune -o \
      -type f -name CACHEDIR.TAG -exec dirname {} \; 2>/dev/null
  fi
}

ARTIFACT_COUNT=0
TOTAL_SIZE=0
CLOUD_SKIPPED=0

for scan_dir in "${SCAN_DIRS[@]}"; do
  section "Scanning: $scan_dir"
  if is_cloud_synced "$scan_dir"; then
    echo "  cloud-synced root — skipped"
    note_skip "$scan_dir" "cloud-synced"
    continue
  fi

  while IFS= read -r found_dir; do
    [ -z "$found_dir" ] && continue
    [ -d "$found_dir" ] || continue
    found_dir="${found_dir%/}"
    artifact_name=$(basename "$found_dir")

    if has_cachedir_tag "$found_dir"; then
      : # explicit cache marker — always a target
    else
      is_purge_target "$found_dir" || continue
    fi

    if is_cloud_synced "$found_dir"; then
      CLOUD_SKIPPED=$((CLOUD_SKIPPED + 1))
      note_skip "$found_dir" "cloud-synced"
      continue
    fi

    # Skip if modified recently
    if find "$found_dir" -maxdepth 0 -newermt "$MIN_AGE_DAYS days ago" -print -quit 2>/dev/null | grep -q .; then
      continue
    fi

    if is_git_tracked "$found_dir"; then
      note_skip "$found_dir" "git-tracked"
      continue
    fi

    size=$(safe_size "$found_dir")
    # Skip tiny directories (< 1MB); unknown size (-1) still qualifies
    [ "$size" -ge 0 ] && [ "$size" -lt 1024 ] && continue

    project=$(basename "$(dirname "$found_dir")")
    echo "  $project/$artifact_name ($(format_size "$size"))"
    safe_trash "$found_dir"
    ARTIFACT_COUNT=$((ARTIFACT_COUNT + 1))
    _add_size TOTAL_SIZE "$size"
  done < <(find_candidates "$scan_dir" | sort -u)

  echo ""
done
[ "$CLOUD_SKIPPED" -gt 0 ] && echo "Skipped $CLOUD_SKIPPED cloud-synced artifact(s)." && echo ""

# Centralized venvs — regenerable from the project's requirements/lockfile.
# Trashed when idle > VENV_IDLE_DAYS (site-packages mtime, not just the dir);
# younger ones are reported. Whitelist a venv to keep it regardless of age.
section "Centralized Virtual Environments"
VENVS_DIR="$HOME_DIR/.venvs"
VENV_IDLE_DAYS=90
if [ -d "$VENVS_DIR" ]; then
  VENV_COUNT=0
  while IFS= read -r venv_dir; do
    [ -z "$venv_dir" ] && continue
    name=$(basename "$venv_dir")
    size=$(safe_size "$venv_dir")
    [ "$size" -ge 0 ] && [ "$size" -lt 1024 ] && continue
    VENV_COUNT=$((VENV_COUNT + 1))
    # Activation touches bin/ and pyvenv.cfg; installs touch lib/. Any recent
    # write anywhere inside the venv counts as in-use.
    if find "$venv_dir" -newermt "$VENV_IDLE_DAYS days ago" -print -quit 2>/dev/null | grep -q .; then
      mod=$(stat -f "%Sm" -t "%Y-%m-%d" "$venv_dir" 2>/dev/null || echo "unknown")
      echo "  $name: $(format_size "$size"), last modified $mod (in use — kept)"
      continue
    fi
    echo "  $name: $(format_size "$size"), idle > $VENV_IDLE_DAYS days"
    safe_trash "$venv_dir"
    ARTIFACT_COUNT=$((ARTIFACT_COUNT + 1))
    _add_size TOTAL_SIZE "$size"
  done < <(find "$VENVS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
  [ "$VENV_COUNT" -eq 0 ] && echo "  No centralized venvs found."
else
  echo "  No ~/.venvs directory."
fi
echo ""

# Summary
echo "=== Project Artifact Purge Complete ==="
if [ "$DRY_RUN" = "1" ]; then
  echo "Artifacts that would be removed: $ARTIFACT_COUNT"
  echo "Would recover: approximately $(format_size "$TOTAL_SIZE")"
else
  echo "Artifacts removed: $ARTIFACT_COUNT"
  echo "Space recovered: approximately $(format_size "$TOTAL_SIZE")"
fi
if [ "$TOTAL_FAILED" -gt 0 ]; then
  echo "Failed to trash: $TOTAL_FAILED item(s) — see errors above"
fi
echo ""
echo "Configure scan paths: $PATHS_FILE (one directory per line)"
echo "Per-item log: $OPLOG"

finish_run
