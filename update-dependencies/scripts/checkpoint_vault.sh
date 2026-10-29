#!/bin/bash
set -e

# checkpoint_vault.sh — tag the vault's current state (uncommitted work included) before edits.
# Usage: bash checkpoint_vault.sh [vault_dir]    (default ~/Documents/obsidian)
# Writes to the vault's git repo: stages everything (git add -A, no commit) and creates one
# checkpoint-<timestamp> tag. Run it only after the user confirmed the edits.
# Gitignored private files are not tracked, so a checkpoint does not cover them.
# Tags stay local: obsidian-git-sync.sh pushes only the main branch.
# CHECKPOINT_NOW=HH:MM overrides the clock for the time guard (testing only).

VAULT="${1:-${HOME}/Documents/obsidian}"

# --- Time guard: the vault auto-syncs at 00:00, 06:00, 12:00 and 18:00 ---
# A sync can start late (after the Mac wakes: 00:11-00:15 and 06:15 have been seen), so
# refuse from 10 minutes before a slot until 20 minutes after it.
now="${CHECKPOINT_NOW:-$(date +%H:%M)}"
minute_of_day=$((10#${now%%:*} * 60 + 10#${now##*:}))
slot=$((minute_of_day % 360))
if [ "$slot" -lt 20 ] || [ "$slot" -ge 350 ]; then
  echo "error: ${now} is inside a vault auto-sync window (10 min before to 20 min after 00/06/12/18h)." >&2
  echo "A half-edited tree would be committed and pushed. Wait until it has finished." >&2
  exit 3
fi
minutes_left=$((350 - slot))

# --- Checkpoint ---
if ! git -C "$VAULT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: ${VAULT} is not a git repository" >&2
  exit 2
fi

git -C "$VAULT" add -A
snapshot="$(git -C "$VAULT" stash create)"   # empty when the tree is clean
target="${snapshot:-HEAD}"
base_tag="checkpoint-$(date +%Y%m%d-%H%M%S)"
tag="$base_tag"
n=1
while git -C "$VAULT" rev-parse -q --verify "refs/tags/${tag}" >/dev/null; do
  n=$((n + 1))
  tag="${base_tag}-${n}"
done
git -C "$VAULT" tag "$tag" "$target"

echo "Tagged ${tag} at $(git -C "$VAULT" rev-parse --short "$target")"
echo "Finish the edits within ${minutes_left} minutes: the next auto-sync window starts then."
echo "Restore one file: git -C ${VAULT} checkout ${tag} -- <path>"
