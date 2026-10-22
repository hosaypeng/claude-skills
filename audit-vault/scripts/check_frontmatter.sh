#!/bin/bash
set -e

VAULT="$HOME/Documents/obsidian"

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

require_dir() {
  if [ ! -d "$1" ]; then
    echo "[ERROR] Expected folder not found: ${1#"$VAULT"/}"
    exit 1
  fi
}

require_dir "$VAULT/30_knowledge"
require_dir "$VAULT/00_inbox"

# 30_knowledge (all subfolders): files with a source field are articles
# (tags, title, source, author, published, created); the rest are notes (tags, description, type, status).
# Reference notes (type: reference) and AI-generated notes (origin: ai) are always checked as notes.
echo "--- 30_knowledge/ ---"
article_count=0
note_count=0
while IFS= read -r -d '' file; do
  basename=$(basename "$file")
  [ "$basename" = "_index.md" ] && continue
  frontmatter=$(awk 'BEGIN{f=0} /^---$/{f++; if(f==2) exit; next} f==1{print}' "$file")
  if echo "$frontmatter" | grep -qE '^source:' && ! echo "$frontmatter" | grep -qE '^(type: *reference|origin: *ai)'; then
    check_fields "$file" tags title source author published created
    article_count=$((article_count + 1))
  else
    check_fields "$file" tags description type status
    note_count=$((note_count + 1))
  fi
done < <(find "$VAULT/30_knowledge" -name '*.md' -print0)
echo "Checked $article_count articles and $note_count notes in 30_knowledge/"

# Check for summary on long notes
echo ""
echo "--- 30_knowledge/ summary check (hand-written notes > 200 lines) ---"
summary_issues=0
while IFS= read -r -d '' file; do
  basename=$(basename "$file")
  [ "$basename" = "_index.md" ] && continue
  line_count=$(wc -l < "$file" | tr -d ' ')
  if [ "$line_count" -gt 200 ]; then
    frontmatter=$(awk 'BEGIN{f=0} /^---$/{f++; if(f==2) exit; next} f==1{print}' "$file")
    # Articles (source) and AI-generated notes (origin: ai) don't carry a hand-written summary
    if echo "$frontmatter" | grep -qE '^(source:|origin: *ai)'; then
      continue
    fi
    if ! echo "$frontmatter" | grep -qE '^summary:'; then
      rel_path="${file#"$VAULT"/}"
      echo "[MISSING] $rel_path: Note has $line_count lines but no summary field"
      ISSUES=$((ISSUES + 1))
      summary_issues=$((summary_issues + 1))
    fi
  fi
done < <(find "$VAULT/30_knowledge" -name '*.md' -print0)
echo "$summary_issues long notes missing summary."
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
