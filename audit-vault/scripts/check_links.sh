#!/bin/bash
set -e

VAULT="/Users/hsp/Library/Mobile Documents/iCloud~md~obsidian/Documents"

echo "=== Broken Wikilink Check ==="
echo ""

ISSUES=0

# Build index of all .md basenames (without extension) into a temp file
INDEX_FILE=$(mktemp)
trap 'rm -f "$INDEX_FILE"' EXIT

find "$VAULT" -name '*.md' -not -path '*/.*' -print0 | while IFS= read -r -d '' file; do
  basename "$file" .md
done | sort -uf > "$INDEX_FILE"

# Process each .md file for wikilinks
while IFS= read -r -d '' file; do
  rel_path="${file#"$VAULT"/}"

  # Remove code blocks before extracting links
  content=$(awk '
    /^```/ { in_code = !in_code; next }
    !in_code { print }
  ' "$file")

  # Extract all [[wikilinks]] — handle [[link|alias]] by taking the link part
  links=$(echo "$content" | grep -oE '\[\[[^]]+\]\]' | sed 's/\[\[//;s/\]\]//' | sed 's/|.*//' | sed 's/#.*//' | sort -u || true)

  while IFS= read -r link; do
    [ -z "$link" ] && continue
    # Skip links to non-md files (images, etc.)
    echo "$link" | grep -qiE '\.(png|jpg|jpeg|gif|svg|pdf|mp3|mp4|webp|css)$' && continue

    target=$(basename "$link")
    # Remove .md extension if present for matching
    target_no_ext="${target%.md}"

    # Case-insensitive grep against the index
    if ! grep -iq "^${target_no_ext}$" "$INDEX_FILE" 2>/dev/null; then
      echo "[BROKEN] $rel_path -> [[$link]]"
      ISSUES=$((ISSUES + 1))
    fi
  done <<< "$links"
done < <(find "$VAULT" -name '*.md' -not -path '*/.*' -print0)

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo "No broken wikilinks found."
else
  echo "$ISSUES broken wikilink(s) found."
fi

exit 0
