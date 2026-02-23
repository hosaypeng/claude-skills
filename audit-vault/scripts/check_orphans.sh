#!/bin/bash
set -e

VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"

echo "=== Orphan Notes & Empty Files Check ==="
echo ""

# Build set of all referenced targets from wikilinks into a temp file
REF_FILE=$(mktemp)
trap 'rm -f "$REF_FILE"' EXIT

find "$VAULT" -name '*.md' -not -path '*/.*' -print0 | while IFS= read -r -d '' file; do
  grep -oE '\[\[[^]]+\]\]' "$file" 2>/dev/null | sed 's/\[\[//;s/\]\]//' | sed 's/|.*//' | sed 's/#.*//' || true
done | while IFS= read -r link; do
  [ -z "$link" ] && continue
  target=$(basename "$link")
  target_no_ext="${target%.md}"
  echo "$target_no_ext"
done | sort -uf > "$REF_FILE"

# Find orphan files
echo "--- Orphan Notes (not linked from anywhere) ---"
ORPHAN_COUNT=0
while IFS= read -r -d '' file; do
  rel_path="${file#"$VAULT"/}"

  # Skip excluded directories
  echo "$rel_path" | grep -qE '^(10_journal/|40_indexes/|50_system/|60_archive/)' && continue
  # Skip _index.md files
  [ "$(basename "$file")" = "_index.md" ] && continue
  # Skip CLAUDE.md
  [ "$(basename "$file")" = "CLAUDE.md" ] && continue

  base=$(basename "$file" .md)

  if ! grep -iq "^${base}$" "$REF_FILE" 2>/dev/null; then
    echo "[ORPHAN] $rel_path"
    ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
  fi
done < <(find "$VAULT" -name '*.md' -not -path '*/.*' -print0 | sort -z)

echo ""
echo "$ORPHAN_COUNT orphan note(s) found."
echo ""

# Find near-empty files (fewer than 3 lines of content after frontmatter)
echo "--- Near-Empty Files (< 3 lines of content) ---"
EMPTY_COUNT=0
while IFS= read -r -d '' file; do
  rel_path="${file#"$VAULT"/}"

  # Skip excluded directories
  echo "$rel_path" | grep -qE '^(50_system/|60_archive/)' && continue
  # Skip _index.md
  [ "$(basename "$file")" = "_index.md" ] && continue

  # Count content lines (excluding frontmatter and blank lines)
  content_lines=$(awk '
    BEGIN { in_fm=0; fm_done=0; count=0 }
    /^---$/ { if(!fm_done) { in_fm=!in_fm; if(!in_fm) fm_done=1; next } }
    in_fm { next }
    /^[[:space:]]*$/ { next }
    { count++ }
    END { print count }
  ' "$file")

  if [ "$content_lines" -lt 3 ]; then
    echo "[EMPTY] $rel_path ($content_lines content line(s))"
    EMPTY_COUNT=$((EMPTY_COUNT + 1))
  fi
done < <(find "$VAULT" -name '*.md' -not -path '*/.*' -print0 | sort -z)

echo ""
echo "$EMPTY_COUNT near-empty file(s) found."

exit 0
