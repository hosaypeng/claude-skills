#!/bin/bash
set -e

# Cleanup History
# Reads the per-item operations log written by every /cleanup mode and prints
# recent sessions plus, for anything still sitting in ~/.Trash, the exact mv
# that puts it back.
#
# Usage: cleanup_history.sh [N]   — show the last N sessions (default 5)

OPLOG="$HOME/.claude/cleanup-operations.log"
LIMIT="${1:-5}"

if [ ! -f "$OPLOG" ]; then
  echo "No operations log at $OPLOG — nothing has run through /cleanup yet."
  exit 0
fi

# Combine the rotated file (if any) so a session split across rotation is whole.
LOG_INPUT=$(mktemp "${TMPDIR:-/tmp}/cleanup-history.XXXXXX")
trap 'rm -f "$LOG_INPUT"' EXIT
[ -f "$OPLOG.old" ] && cat "$OPLOG.old" >> "$LOG_INPUT"
cat "$OPLOG" >> "$LOG_INPUT"

echo "=== Cleanup History (last $LIMIT sessions) ==="
echo ""

# Session boundaries are the "# ==== <mode> started ..." lines. Walk them from
# the end and take the last LIMIT.
STARTS=$(grep -n '^# ==== .* started' "$LOG_INPUT" | tail -n "$LIMIT" | cut -d: -f1)
if [ -z "$STARTS" ]; then
  echo "No sessions recorded."
  exit 0
fi

TOTAL_LINES=$(wc -l < "$LOG_INPUT" | tr -d ' ')
prev_end=$TOTAL_LINES
# Process newest first: read the start lines in reverse.
for start in $(echo "$STARTS" | sort -rn); do
  block=$(sed -n "${start},${prev_end}p" "$LOG_INPUT")
  prev_end=$((start - 1))
  header=$(echo "$block" | head -1)
  mode=$(echo "$header" | sed -E 's/^# ==== ([a-z]+) started.*/\1/')
  started=$(echo "$header" | sed -E 's/.* at ([0-9-]+ [0-9:]+).*/\1/')
  dry=""; echo "$header" | grep -q "dry-run" && dry=" (dry-run)"
  ended=$(echo "$block" | grep '^# ==== .* ended' | head -1 | sed -E 's/.* ended at ([0-9-]+ [0-9:]+), (.*) ====/\1 — \2/')
  trashed=$(echo "$block" | grep -c '\] TRASHED ' || true)
  would=$(echo "$block" | grep -c '\] WOULD_TRASH ' || true)
  skipped=$(echo "$block" | grep -c '\] SKIPPED ' || true)
  failed=$(echo "$block" | grep -c '\] FAILED ' || true)
  reported=$(echo "$block" | grep -c '\] REPORTED ' || true)
  echo "$mode$dry — $started"
  [ -n "$ended" ] && echo "  ended: $ended" || echo "  ended: (no end marker — interrupted?)"
  echo "  trashed $trashed · would-trash $would · skipped $skipped · failed $failed · reported $reported"
  echo ""
done

# Restore hints: TRASHED lines carry "src -> dest"; only list dests that still
# exist, since an emptied Trash cannot be restored from here.
echo "=== Restorable items still in ~/.Trash ==="
RESTORABLE=0
while IFS= read -r line; do
  src=$(echo "$line" | sed -E 's/^\[[^]]+\] \[[a-z]+\] TRASHED (.*) -> (.*) \([^)]*\)$/\1/')
  dest=$(echo "$line" | sed -E 's/^\[[^]]+\] \[[a-z]+\] TRASHED (.*) -> (.*) \([^)]*\)$/\2/')
  [ -e "$dest" ] || continue
  RESTORABLE=$((RESTORABLE + 1))
  [ "$RESTORABLE" -le 40 ] && echo "  mv -n \"$dest\" \"$src\""
done < <(grep '\] TRASHED ' "$LOG_INPUT" | tail -n 2000)
if [ "$RESTORABLE" -eq 0 ]; then
  echo "  (none — Trash emptied or nothing trashed yet)"
elif [ "$RESTORABLE" -gt 40 ]; then
  echo "  ... and $((RESTORABLE - 40)) more. Full list: grep '\\] TRASHED ' $OPLOG"
fi
echo ""
echo "Log: $OPLOG"
