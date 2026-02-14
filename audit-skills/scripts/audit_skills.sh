#!/bin/bash
set -e

SKILLS_DIR="$HOME/.claude/skills"
ISSUES_FOUND=0

echo "=== Skill Directory Scan ==="
echo ""

# Check each skill directory
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    echo "[WARN] $skill_name: No SKILL.md found"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    continue
  fi

  # Check for inline bash without scripts/ directory
  has_bash=$(grep -c '```bash' "$skill_md" 2>/dev/null | tr -d '[:space:]' || echo "0")
  has_scripts_dir=false
  if [ -d "$skill_dir/scripts" ]; then
    has_scripts_dir=true
  fi

  if [ "$has_bash" -gt 2 ] && [ "$has_scripts_dir" = false ]; then
    echo "[ISSUE] $skill_name: $has_bash inline bash blocks but no scripts/ directory — extract to .sh files"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi

  # Check scripts for conventions
  if [ "$has_scripts_dir" = true ]; then
    for script in "$skill_dir"/scripts/*.sh; do
      [ -f "$script" ] || continue
      script_basename=$(basename "$script")

      if ! head -1 "$script" | grep -q '#!/bin/bash'; then
        echo "[ISSUE] $skill_name/scripts/$script_basename: Missing #!/bin/bash shebang"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
      fi

      if ! grep -q 'set -e' "$script"; then
        echo "[ISSUE] $skill_name/scripts/$script_basename: Missing 'set -e'"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
      fi

      if [ ! -x "$script" ]; then
        echo "[ISSUE] $skill_name/scripts/$script_basename: Not executable (missing chmod +x)"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
      fi
    done
  fi
done

echo ""
echo "=== SKILL.md Metadata Checks ==="
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  [ -f "$skill_md" ] || continue

  # Check for description field
  if ! grep -q '^description:' "$skill_md"; then
    echo "[ISSUE] $skill_name: Missing 'description:' field"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  else
    desc=$(grep '^description:' "$skill_md" | head -1 | sed 's/^description: *//')
    desc_len=${#desc}
    if [ "$desc_len" -lt 30 ]; then
      echo "[WARN] $skill_name: Description is very short ($desc_len chars) — add trigger phrases"
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  fi

  # Check for underscore naming (should be hyphenated)
  if echo "$skill_name" | grep -q '_'; then
    echo "[ISSUE] $skill_name: Uses underscores — rename to $(echo "$skill_name" | tr '_' '-')"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
done

echo ""
echo "=== Cross-Reference Check ==="
echo ""

# Check for references to non-existent skills
all_skill_names=$(ls -d "$SKILLS_DIR"/*/ 2>/dev/null | xargs -I{} basename {} | sort)
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  # Look for /skill-name references in all files
  for file in "$skill_dir"/*.md "$skill_dir"/prompt.md; do
    [ -f "$file" ] || continue
    # Find /word patterns that look like skill references
    refs=$(grep -oE '/[a-z][a-z0-9_-]+' "$file" 2>/dev/null | sort -u || true)
    for ref in $refs; do
      ref_name=${ref#/}
      # Skip common non-skill paths
      echo "$ref_name" | grep -qE '^(bin|dev|etc|home|opt|private|tmp|usr|var|Users|Applications|Library|System|Volumes)' && continue
      echo "$ref_name" | grep -qE '\.' && continue
      # Check if it's a skill reference that doesn't exist
      if echo "$ref_name" | grep -qE '^[a-z][a-z0-9_-]+$' && [ ${#ref_name} -lt 30 ]; then
        if ! echo "$all_skill_names" | grep -qx "$ref_name"; then
          # Only flag if it looks like a skill invocation (preceded by text context)
          if grep -qE "(run|use|call|try|see|invoke) +$ref" "$file" 2>/dev/null || grep -qE "^\`$ref\`" "$file" 2>/dev/null; then
            echo "[WARN] $skill_name: References /$ref_name but no such skill exists"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
          fi
        fi
      fi
    done
  done
done

echo ""
echo "=== Summary ==="
if [ "$ISSUES_FOUND" -eq 0 ]; then
  echo "All skills pass audit checks."
else
  echo "$ISSUES_FOUND issue(s) found."
fi

exit 0
