#!/bin/bash
set -e

# Find all git repos under $HOME, excluding noise directories
# Usage: find_repos.sh [repo_path]
#   If repo_path is provided, skip discovery and check only that repo.

echo "=== Git Repo Discovery ==="

# Single-repo fast path: if an argument is passed, just validate and output it
if [ -n "$1" ]; then
  repo_path="$1"
  # Resolve to absolute path
  repo_path=$(cd "$repo_path" 2>/dev/null && pwd) || { echo "Error: '$1' is not a valid directory" >&2; exit 1; }
  if [ -d "$repo_path/.git" ]; then
    echo "$repo_path/.git"
  elif [ -d "$repo_path" ] && git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
    # Could be inside a worktree or bare repo
    echo "$repo_path/.git"
  else
    echo "Error: '$repo_path' is not a git repository" >&2
    exit 1
  fi
  exit 0
fi

# Full discovery: find all git repos under $HOME with targeted exclusions
find "$HOME" -name ".git" -maxdepth 5 -type d \
  -not -path "*/node_modules/*" \
  -not -path "*/.Trash/*" \
  -not -path "*/.local/share/*" \
  -not -path "*/.gemini/*" \
  -not -path "*/.claude/plugins/*" \
  -not -path "*/.cache/*" \
  -not -path "*/.cargo/*" \
  -not -path "*/.rustup/*" \
  -not -path "*/.npm/*" \
  -not -path "*/go/pkg/*" \
  -not -path "*/Library/*" \
  -not -path "*/.Spotlight-*/*" \
  -not -path "*/com~apple~CloudDocs/*" \
  -not -path "*/.icloud/*" \
  2>/dev/null
