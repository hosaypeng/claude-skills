#!/bin/bash
set -e

# Project Artifact Purge
# Scans code directories for stale build artifacts (node_modules, target/, .build/, etc.)
# and moves them to Trash. Only targets artifacts older than 30 days by default.

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

# Artifact patterns to look for (directory name -> description)
# Only target directories that are unambiguously generated artifacts.
# Excluded: build, dist, .output, coverage — too generic, often git-tracked.
declare -A ARTIFACT_NAMES=(
  [node_modules]="Node.js dependencies"
  [.next]="Next.js build"
  [target]="Rust/Java build"
  [.build]="Swift build"
  [__pycache__]="Python bytecode"
  [.pytest_cache]="Pytest cache"
  [.mypy_cache]="Mypy cache"
  [.ruff_cache]="Ruff cache"
  [.tox]="Tox environments"
  [.venv]="Python virtualenv"
  [venv]="Python virtualenv"
  [.gradle]="Gradle cache"
  [.parcel-cache]="Parcel bundler cache"
  [.turbo]="Turborepo cache"
  [.angular]="Angular cache"
  [.nuxt]="Nuxt build"
  [.svelte-kit]="SvelteKit build"
  [.expo]="Expo cache"
)

ARTIFACT_COUNT=0
TOTAL_SIZE=0

for scan_dir in "${SCAN_DIRS[@]}"; do
  echo "--- Scanning: $scan_dir ---"

  for artifact_name in "${!ARTIFACT_NAMES[@]}"; do
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
      echo "  $project/$artifact_name ($(format_size $size)) — ${ARTIFACT_NAMES[$artifact_name]}"
      safe_trash "$found_dir"
      ARTIFACT_COUNT=$((ARTIFACT_COUNT + 1))
      TOTAL_SIZE=$((TOTAL_SIZE + size))
    done < <(find "$scan_dir" -maxdepth 4 -type d -name "$artifact_name" 2>/dev/null)
  done

  echo ""
done

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
