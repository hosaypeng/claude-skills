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

      if ! head -1 "$script" | grep -qE '^#!(\/bin\/bash|\/usr\/bin\/env bash)'; then
        echo "[ISSUE] $skill_name/scripts/$script_basename: Missing shebang (expected #!/bin/bash or #!/usr/bin/env bash)"
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

# Build a regex of known filesystem prefixes to skip
fs_prefixes='^(bin|dev|etc|home|opt|private|proc|run|sbin|srv|sys|tmp|usr|var|Users|Applications|Library|System|Volumes|nix|snap|mnt|media)'

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  # Scan all markdown files in the skill directory (not just top-level)
  while IFS= read -r -d '' file; do
    # Match slash-commands: `/skill-name` patterns (backtick-wrapped or preceded by invocation verbs)
    # Pattern 1: backtick-wrapped `/name` — e.g., `\`/audit-skills\``
    backtick_refs=$(grep -oE '`/[a-z][a-z0-9_-]+`' "$file" 2>/dev/null | sed 's/`//g;s|^/||' | sort -u || true)
    # Pattern 2: invocation verb + /name — e.g., "run /audit-skills"
    verb_refs=$(grep -oE '(run|use|call|try|see|invoke|launch|execute)\s+/[a-z][a-z0-9_-]+' "$file" 2>/dev/null | grep -oE '/[a-z][a-z0-9_-]+' | sed 's|^/||' | sort -u || true)

    for ref_name in $backtick_refs $verb_refs; do
      # Skip filesystem paths and dotted names (likely file extensions)
      echo "$ref_name" | grep -qE "$fs_prefixes" && continue
      echo "$ref_name" | grep -qE '\.' && continue
      # Skip very long names unlikely to be skills
      [ ${#ref_name} -ge 40 ] && continue

      if ! echo "$all_skill_names" | grep -qx "$ref_name"; then
        echo "[WARN] $skill_name: References /$ref_name but no such skill exists"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
      fi
    done
  done < <(find "$skill_dir" -name '*.md' -print0 2>/dev/null)
done

echo ""
echo "=== References Validation ==="
echo ""

# Check that files referenced in SKILL.md references/ sections actually exist
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  [ -f "$skill_md" ] || continue

  # Find references/ paths mentioned in SKILL.md
  ref_paths=$(grep -oE 'references/[A-Za-z0-9_/.-]+' "$skill_md" 2>/dev/null | sort -u || true)
  for ref_path in $ref_paths; do
    full_path="$skill_dir/$ref_path"
    if [ ! -e "$full_path" ]; then
      echo "[ISSUE] $skill_name: SKILL.md references '$ref_path' but it does not exist"
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done
done

echo ""
echo "=== Summary ==="
if [ "$ISSUES_FOUND" -eq 0 ]; then
  echo "All skills pass audit checks."
else
  echo "$ISSUES_FOUND issue(s) found."
  exit 1
fi
