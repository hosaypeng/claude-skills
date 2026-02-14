#!/bin/bash
set -e

VAULT="/Users/hsp/Library/Mobile Documents/iCloud~md~obsidian/Documents"

echo "=== Frontmatter Compliance Check ==="
echo ""

ISSUES=0

check_fields() {
  local file="$1"
  shift
  local required_fields=("$@")
  local rel_path="${file#"$VAULT"/}"

  # Check if file has frontmatter at all
  first_line=$(head -1 "$file" 2>/dev/null | tr -d '[:space:]')
  if [ "$first_line" != "---" ]; then
    echo "[MISSING] $rel_path: No frontmatter found"
    ISSUES=$((ISSUES + 1))
    return
  fi

  # Extract frontmatter content
  frontmatter=$(awk 'BEGIN{f=0} /^---$/{f++; if(f==2) exit; next} f==1{print}' "$file")

  local missing=()
  for field in "${required_fields[@]}"; do
    if ! echo "$frontmatter" | grep -qE "^${field}:"; then
      missing+=("$field")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "[MISSING] $rel_path: Missing fields: ${missing[*]}"
    ISSUES=$((ISSUES + 1))
  fi
}

# 31_articles: tags, title, source, author, published, created
echo "--- 31_articles/ ---"
article_count=0
while IFS= read -r -d '' file; do
  basename=$(basename "$file")
  [ "$basename" = "_index.md" ] && continue
  check_fields "$file" tags title source author published created
  article_count=$((article_count + 1))
done < <(find "$VAULT/31_articles" -name '*.md' -maxdepth 1 -print0 2>/dev/null)
echo "Checked $article_count files in 31_articles/"
echo ""

# 30_notes: tags
echo "--- 30_notes/ ---"
note_count=0
while IFS= read -r -d '' file; do
  basename=$(basename "$file")
  [ "$basename" = "_index.md" ] && continue
  check_fields "$file" tags
  note_count=$((note_count + 1))
done < <(find "$VAULT/30_notes" -name '*.md' -maxdepth 1 -print0 2>/dev/null)
echo "Checked $note_count files in 30_notes/"
echo ""

# 00_inbox: tags
echo "--- 00_inbox/ ---"
inbox_count=0
while IFS= read -r -d '' file; do
  basename=$(basename "$file")
  [ "$basename" = "_index.md" ] && continue
  check_fields "$file" tags
  inbox_count=$((inbox_count + 1))
done < <(find "$VAULT/00_inbox" -name '*.md' -maxdepth 1 -print0 2>/dev/null)
echo "Checked $inbox_count files in 00_inbox/"

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo "All files have compliant frontmatter."
else
  echo "$ISSUES frontmatter issue(s) found."
fi

exit 0
