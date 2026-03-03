#!/bin/bash
set -e

# Project Artifact Purge
# Scans code directories for stale build artifacts (node_modules, target/, .build/, etc.)
# and moves them to Trash. Only targets artifacts older than 30 days by default.
# Compatible with macOS bash 3.2 (no associative arrays).

source "$(dirname "$0")/_helpers.sh"

HOME_DIR="$HOME"
LOG_FILE="$HOME_DIR/.claude/purge-projects-log.txt"
PATHS_FILE="$HOME_DIR/.claude/cleanup-purge-paths.txt"
MIN_AGE_DAYS=30

echo "=== Project Artifact Purge ==="
echo ""

# Load scan paths from config or use defaults
SCAN_DIRS=()
if [ -f "$PATHS_FILE" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue
    # Expand ~ to $HOME
    expanded="${line/#\~/$HOME_DIR}"
    [ -d "$expanded" ] && SCAN_DIRS+=("$expanded")
  done < "$PATHS_FILE"
fi

# Defaults if no config or all paths invalid
if [ ${#SCAN_DIRS[@]} -eq 0 ]; then
  for d in \
    "$HOME_DIR/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code" \
    "$HOME_DIR/Projects" \
    "$HOME_DIR/Code" \
    "$HOME_DIR/dev" \
    "$HOME_DIR/GitHub" \
    "$HOME_DIR/Repos"; do
    [ -d "$d" ] && SCAN_DIRS+=("$d")
  done
fi

if [ ${#SCAN_DIRS[@]} -eq 0 ]; then
  echo "No code directories found to scan."
  echo "Create $PATHS_FILE with one directory per line to configure."
  exit 0
fi

echo "Scanning directories:"
for d in "${SCAN_DIRS[@]}"; do
  echo "  $d"
done
echo ""

# Artifact patterns (bash 3.2 compatible — no associative arrays)
# Only unambiguously generated artifacts.
# Excluded: build, dist, .output, coverage — too generic, often git-tracked.
ARTIFACT_NAMES=(
  node_modules .next target .build
  __pycache__ .pytest_cache .mypy_cache .ruff_cache .tox .eggs
  .venv venv
  .gradle .parcel-cache .turbo .angular .nuxt .svelte-kit .expo
  Pods .dart_tool
)

ARTIFACT_COUNT=0
TOTAL_SIZE=0

for scan_dir in "${SCAN_DIRS[@]}"; do
  echo "--- Scanning: $scan_dir ---"

  for artifact_name in "${ARTIFACT_NAMES[@]}"; do
    while IFS= read -r found_dir; do
      [ -z "$found_dir" ] && continue

      # Check age: skip if modified recently
      if find "$found_dir" -maxdepth 0 -newermt "$MIN_AGE_DAYS days ago" -print -quit 2>/dev/null | grep -q .; then
        continue
      fi

      # Skip if git-tracked (the project's .gitignore doesn't exclude it)
      parent=$(dirname "$found_dir")
      if git -C "$parent" ls-files --error-unmatch "$artifact_name" &>/dev/null; then
        continue
      fi

      size=$(safe_size "$found_dir")
      # Skip tiny directories (< 1MB)
      [ "$size" -lt 1024 ] && continue

      project=$(basename "$parent")
      echo "  $project/$artifact_name ($(format_size $size))"
      safe_trash "$found_dir"
      ARTIFACT_COUNT=$((ARTIFACT_COUNT + 1))
      TOTAL_SIZE=$((TOTAL_SIZE + size))
    done < <(find "$scan_dir" -maxdepth 4 -type d -name "$artifact_name" 2>/dev/null)
  done

  echo ""
done

# Centralized venvs (report only — can't verify if parent project still exists)
echo "--- Centralized Virtual Environments ---"
VENVS_DIR="$HOME_DIR/.venvs"
if [ -d "$VENVS_DIR" ]; then
  VENV_COUNT=0
  while IFS= read -r venv_dir; do
    [ -z "$venv_dir" ] && continue
    name=$(basename "$venv_dir")
    size=$(safe_size "$venv_dir")
    [ "$size" -lt 1024 ] && continue
    mod=$(stat -f "%Sm" -t "%Y-%m-%d" "$venv_dir" 2>/dev/null || echo "unknown")
    echo "  $name: $(format_size $size), last modified $mod (report only)"
    VENV_COUNT=$((VENV_COUNT + 1))
  done < <(find "$VENVS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
  [ "$VENV_COUNT" -eq 0 ] && echo "  No centralized venvs found."
else
  echo "  No ~/.venvs directory."
fi
echo ""

# Summary
echo "=== Project Artifact Purge Complete ==="
echo "Artifacts removed: $ARTIFACT_COUNT"
echo "Space recovered: approximately $(format_size $TOTAL_SIZE)"
echo ""
echo "Configure scan paths: $PATHS_FILE (one directory per line)"

# Log
mkdir -p "$(dirname "$LOG_FILE")"
cat >> "$LOG_FILE" <<LOGEOF
========================================
Project Purge: $(date '+%Y-%m-%d %H:%M:%S')
========================================
Artifacts Removed: $ARTIFACT_COUNT
Space Recovered: $(format_size $TOTAL_SIZE)
Directories Scanned: ${SCAN_DIRS[*]}
Status: Success
========================================

LOGEOF

echo "Log appended to $LOG_FILE"
