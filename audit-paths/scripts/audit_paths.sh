#!/bin/bash
set -e

# audit_paths.sh — Scan CLAUDE.md, MEMORY.md, memory files, and LaunchAgent plists for dead paths
# Usage: bash audit_paths.sh [memory|launchagents|all]

MODE="${1:-all}"
VAULT="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents"
PROJECT_MEMORY="${HOME}/.claude/projects/-Users-hsp-Library-Mobile-Documents-iCloud-md-obsidian-Documents/memory"
LAUNCH_AGENTS="${HOME}/Library/LaunchAgents"

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
echo "0 0" > "$TMPFILE"

increment() {
  local field="$1"  # "alive" or "dead"
  read -r alive dead < "$TMPFILE"
  if [ "$field" = "alive" ]; then
    echo "$((alive + 1)) $dead" > "$TMPFILE"
  else
    echo "$alive $((dead + 1))" > "$TMPFILE"
  fi
}

get_counts() {
  read -r alive dead < "$TMPFILE"
  echo "$alive $dead"
}

check_path() {
  local file="$1"
  local raw_path="$2"

  # Expand ~ and $HOME
  local expanded
  expanded=$(echo "$raw_path" | sed "s|^~/|${HOME}/|" | sed "s|\\\${HOME}|${HOME}|g" | sed "s|\\\$HOME|${HOME}|g")

  # Skip URLs
  case "$expanded" in
    http://*|https://*|mailto:*) return ;;
  esac

  # Skip slash commands (e.g. /audit-skills) — single slash, no deeper path
  if [[ "$raw_path" =~ ^/[a-z_-]+$ ]]; then
    return
  fi

  # Skip PATH-style colon-separated values
  [[ "$expanded" == *:* ]] && return

  # Must contain a slash to be a path
  [[ "$expanded" != */* ]] && return

  # Skip relative paths that don't start with ~, /, or $
  [[ "$raw_path" != /* && "$raw_path" != ~* && "$raw_path" != \$* ]] && return

  # Skip short absolute paths (e.g. /csv/) — real absolute paths are longer
  if [[ "$raw_path" == /* && "$raw_path" != ~* ]]; then
    [[ ${#raw_path} -lt 10 ]] && return
  fi

  if [ -e "$expanded" ]; then
    increment alive
  elif [ -e "${VAULT}/${raw_path}" ]; then
    increment alive
  else
    echo "DEAD | $(basename "$file") | $raw_path"
    increment dead
  fi
}

scan_markdown_files() {
  echo "=== Scanning Memory & Config Files ==="
  echo ""

  # Reset counters
  echo "0 0" > "$TMPFILE"

  local files=()
  [ -f "${VAULT}/CLAUDE.md" ] && files+=("${VAULT}/CLAUDE.md")
  [ -f "${HOME}/.claude/CLAUDE.md" ] && files+=("${HOME}/.claude/CLAUDE.md")
  [ -f "${PROJECT_MEMORY}/MEMORY.md" ] && files+=("${PROJECT_MEMORY}/MEMORY.md")

  if [ -d "${PROJECT_MEMORY}" ]; then
    while IFS= read -r f; do
      [ "$f" != "${PROJECT_MEMORY}/MEMORY.md" ] && files+=("$f")
    done < <(find "${PROJECT_MEMORY}" -name '*.md' -maxdepth 1 2>/dev/null)
  fi

  for file in "${files[@]}"; do
    # Extract backtick-quoted paths that start with ~, /, or $
    grep -oE '`[~/\$][^`]{2,}`' "$file" 2>/dev/null | sed 's/^`//;s/`$//' | while IFS= read -r candidate; do
      # Skip commands
      case "$candidate" in
        git\ *|npm\ *|pip\ *|claude\ *|source\ *|python\ *|bash\ *|launchctl\ *|mv\ *|rm\ *|cp\ *|find\ *|grep\ *|cat\ *) continue ;;
        *\**) continue ;;
      esac
      check_path "$file" "$candidate"
    done
  done

  read -r alive dead < "$TMPFILE"
  echo ""
  echo "Memory/config: ${alive} alive, ${dead} dead"
}

scan_launchagents() {
  echo "=== Scanning LaunchAgent Plists ==="
  echo ""

  # Reset counters
  echo "0 0" > "$TMPFILE"

  if [ ! -d "$LAUNCH_AGENTS" ]; then
    echo "No LaunchAgents directory found"
    return
  fi

  for plist in "${LAUNCH_AGENTS}"/*.plist; do
    [ -f "$plist" ] || continue
    local plist_name
    plist_name=$(basename "$plist")

    # Extract <string> values that are absolute paths (skip colon-separated PATH values)
    grep -oE '<string>/[^<]+</string>' "$plist" 2>/dev/null | sed 's/<string>//;s/<\/string>//' | while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      # Skip PATH env vars (contain colons)
      [[ "$path" == *:* ]] && continue
      if [ -e "$path" ]; then
        increment alive
      else
        echo "DEAD | ${plist_name} | $path"
        increment dead
      fi
    done
  done

  read -r alive dead < "$TMPFILE"
  echo ""
  echo "LaunchAgents: ${alive} alive, ${dead} dead"
}

# Main
echo "==============================="
echo "  Path Audit"
echo "==============================="
echo ""

TOTAL_DEAD=0

case "$MODE" in
  memory)
    scan_markdown_files
    read -r _ dead < "$TMPFILE"
    TOTAL_DEAD=$dead
    ;;
  launchagents)
    scan_launchagents
    read -r _ dead < "$TMPFILE"
    TOTAL_DEAD=$dead
    ;;
  all|*)
    scan_markdown_files
    read -r _ dead1 < "$TMPFILE"
    echo ""
    scan_launchagents
    read -r _ dead2 < "$TMPFILE"
    TOTAL_DEAD=$((dead1 + dead2))
    ;;
esac

echo ""
echo "==============================="
if [ "$TOTAL_DEAD" -eq 0 ]; then
  echo "  All paths valid"
else
  echo "  ${TOTAL_DEAD} dead path(s) found"
fi
echo "==============================="
