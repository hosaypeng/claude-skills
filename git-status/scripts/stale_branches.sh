#!/bin/bash
set -e

# Check all branches in a repo for staleness (no commits in N+ days)
# Usage: stale_branches.sh <repo_path> [days_threshold]
# Output: one line per stale branch with last commit date and age

repo_path="$1"
threshold="${2:-7}"

if [ -z "$repo_path" ] || [ ! -d "$repo_path" ]; then
  echo "Error: provide a valid repo path" >&2
  exit 1
fi

now=$(date +%s)

# List all local branches
git -C "$repo_path" for-each-ref --format='%(refname:short) %(committerdate:unix) %(committerdate:short)' refs/heads/ 2>/dev/null | while read -r branch epoch date; do
  if [ -z "$epoch" ]; then
    continue
  fi
  age_days=$(( (now - epoch) / 86400 ))
  if [ "$age_days" -ge "$threshold" ]; then
    echo "${age_days}d|${branch}|${date}"
  fi
done | sort -t'|' -k1 -rn
