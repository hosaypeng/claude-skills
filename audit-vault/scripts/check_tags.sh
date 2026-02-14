#!/bin/bash
set -e

VAULT="/Users/hsp/Library/Mobile Documents/iCloud~md~obsidian/Documents"

VALID_TAGS="ai biography books business china coding crypto economics film finance geopolitics health history literature personal philosophy productivity self_improvement tech journal index"

echo "=== Tag Validity Check ==="
echo ""

ISSUES=0

# Process all .md files with frontmatter
while IFS= read -r -d '' file; do
  # Extract frontmatter (between first --- and second ---)
  in_frontmatter=false
  in_tags=false
  while IFS= read -r line; do
    if [ "$line" = "---" ]; then
      if [ "$in_frontmatter" = true ]; then
        break
      else
        in_frontmatter=true
        continue
      fi
    fi
    [ "$in_frontmatter" = true ] || continue

    # Check for tags array start
    if echo "$line" | grep -qE '^tags:'; then
      in_tags=true
      # Handle inline tags: tags: [tag1, tag2] or tags: tag1
      inline_tags=$(echo "$line" | sed 's/^tags: *//' | tr -d '[],' | xargs)
      if [ -n "$inline_tags" ] && [ "$inline_tags" != "" ]; then
        for tag in $inline_tags; do
          tag=$(echo "$tag" | tr -d '"'"'" | sed 's/^#//')
          if ! echo "$VALID_TAGS" | grep -qw "$tag"; then
            rel_path="${file#"$VAULT"/}"
            echo "[INVALID] Tag '$tag' in $rel_path"
            ISSUES=$((ISSUES + 1))
          fi
        done
      fi
      continue
    fi

    # Check for YAML array items under tags:
    if [ "$in_tags" = true ]; then
      if echo "$line" | grep -qE '^  *- '; then
        tag=$(echo "$line" | sed 's/^  *- *//' | tr -d '"'"'" | sed 's/^#//' | xargs)
        if [ -n "$tag" ] && ! echo "$VALID_TAGS" | grep -qw "$tag"; then
          rel_path="${file#"$VAULT"/}"
          echo "[INVALID] Tag '$tag' in $rel_path"
          ISSUES=$((ISSUES + 1))
        fi
      else
        in_tags=false
      fi
    fi
  done < "$file"
done < <(find "$VAULT" -name '*.md' -not -path '*/.*' -print0)

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo "All tags are valid."
else
  echo "$ISSUES invalid tag(s) found."
fi

exit 0
