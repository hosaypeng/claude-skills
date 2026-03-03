#!/bin/bash
set -eo pipefail

# Standardize filenames: generate rename plan, validate, and execute safely
# Usage: standardize.sh <directory> [--recursive] [--dry-run|--execute]
#
# Compatible with macOS bash 3.2+ and BSD sed.
#
# Modes:
#   (default)   Print rename plan for review. No files are touched.
#   --dry-run   Same as default — print plan, validate collisions, exit.
#   --execute   Execute the rename plan with mv -n (no-clobber).
#
# The script applies conventions from conventions.md:
#   - Lowercase only
#   - Spaces/hyphens -> underscores (except in dates)
#   - Remove special characters
#   - Collapse multiple underscores
#   - Remove leading/trailing underscores
#   - Preserve file extensions
#
# Date normalization (YYYYMMDD -> YYYY-MM-DD, YYYY_MM_DD -> YYYY-MM-DD)
# is handled here. Complex date extraction (month names, content-based dates)
# is left to the AI agent calling this script.

# --- Argument parsing ---
TARGET_DIR=""
MAX_DEPTH=1
MODE="plan"  # plan | execute

for arg in "$@"; do
  case "$arg" in
    --recursive|-r) MAX_DEPTH=999 ;;
    --dry-run)      MODE="plan" ;;
    --execute)      MODE="execute" ;;
    -*)             echo "Error: Unknown flag '$arg'" >&2; exit 1 ;;
    *)
      if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$arg"
      else
        echo "Error: Unexpected argument '$arg'" >&2; exit 1
      fi
      ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-.}"
TARGET_DIR_ORIG="$TARGET_DIR"
TARGET_DIR=$(cd "$TARGET_DIR" 2>/dev/null && pwd) || {
  echo "Error: Invalid directory '$TARGET_DIR_ORIG'" >&2
  exit 1
}

# --- Filename transformation ---
# Applies conventions.md rules to a single filename (without extension).
# Complex transformations (date extraction from content, semantic structuring)
# are handled by the AI agent — this covers mechanical normalization.
transform_stem() {
  local stem="$1"

  # Lowercase
  stem=$(echo "$stem" | tr '[:upper:]' '[:lower:]')

  # Protect date patterns by replacing hyphens/separators with placeholder XDSX
  # (alphabetic-only placeholder survives special character removal step)
  # YYYY-MM-DD
  stem=$(echo "$stem" | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\1XDSX\2XDSX\3/g')
  # YYYY-MM (only when followed by non-digit or end)
  stem=$(echo "$stem" | sed -E 's/([0-9]{4})-([0-9]{2})(([^0-9])|$)/\1XDSX\2\3/g')

  # Normalize YYYYMMDD -> YYYYXDSXMMXDSXDD
  stem=$(echo "$stem" | sed -E 's/([0-9]{4})([0-9]{2})([0-9]{2})/\1XDSX\2XDSX\3/g')

  # Normalize YYYY_MM_DD -> YYYYXDSXMMXDSXDD
  stem=$(echo "$stem" | sed -E 's/([0-9]{4})_([0-9]{2})_([0-9]{2})/\1XDSX\2XDSX\3/g')

  # Replace spaces with underscores
  stem=$(echo "$stem" | tr ' ' '_')

  # Replace hyphens with underscores (dates already protected)
  stem=$(echo "$stem" | tr '-' '_')

  # Remove special characters one class at a time (BSD sed compatible)
  stem=$(echo "$stem" | sed 's/[()]/_/g')
  stem=$(echo "$stem" | sed 's/\[/_/g; s/\]/_/g')
  stem=$(echo "$stem" | sed 's/[{}]/_/g')
  stem=$(echo "$stem" | sed "s/[!@#\$%^&*+=;:'\",<>?]/_/g")
  stem=$(echo "$stem" | sed 's/[/\\|]/_/g')

  # Restore date hyphens from placeholder
  stem=$(echo "$stem" | sed 's/XDSX/-/g')

  # Collapse multiple underscores
  stem=$(echo "$stem" | sed -E 's/_+/_/g')

  # Remove leading/trailing underscores
  stem=$(echo "$stem" | sed -E 's/^_+//; s/_+$//')

  echo "$stem"
}

# --- Build rename plan ---
# Store plan in temp files (bash 3.2 compatible — no associative arrays)
PLAN_SRC=$(mktemp /tmp/std_src.XXXXXX)
PLAN_DST=$(mktemp /tmp/std_dst.XXXXXX)
PLAN_SRC_NAMES=$(mktemp /tmp/std_srcn.XXXXXX)
PLAN_DST_NAMES=$(mktemp /tmp/std_dstn.XXXXXX)
ALL_EXISTING=$(mktemp /tmp/std_exist.XXXXXX)

cleanup_temps() {
  rm -f "$PLAN_SRC" "$PLAN_DST" "$PLAN_SRC_NAMES" "$PLAN_DST_NAMES" "$ALL_EXISTING"
}
trap cleanup_temps EXIT

skipped=0
planned=0

# Collect all existing filenames for collision detection
find "$TARGET_DIR" -maxdepth "$MAX_DEPTH" -type f -not -name ".*" | sort > "$ALL_EXISTING"

while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue

  dir=$(dirname "$filepath")
  filename=$(basename "$filepath")

  # Split into stem and extension
  case "$filename" in
    *.*)
      ext=".${filename##*.}"
      stem="${filename%.*}"
      ;;
    *)
      ext=""
      stem="$filename"
      ;;
  esac

  # Also lowercase the extension
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  new_stem=$(transform_stem "$stem")
  new_name="${new_stem}${ext}"

  if [ "$filename" = "$new_name" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  echo "$filepath" >> "$PLAN_SRC"
  echo "${dir}/${new_name}" >> "$PLAN_DST"
  echo "$filename" >> "$PLAN_SRC_NAMES"
  echo "$new_name" >> "$PLAN_DST_NAMES"
  planned=$((planned + 1))

done < "$ALL_EXISTING"

# --- Collision detection ---
# Two cases require two-pass rename (via .tmp intermediary):
#   1. Overlap collision: target name matches a DIFFERENT existing source file
#   2. Case-only rename on case-insensitive FS (macOS HFS+/APFS):
#      "FOO.txt" -> "foo.txt" fails with mv -n because the FS sees them as same file.
#      We detect this via inode comparison (same inode, different path string).
needs_two_pass=false

if [ "$planned" -gt 0 ]; then
  line_num=0
  while IFS= read -r dst; do
    line_num=$((line_num + 1))
    src=$(sed -n "${line_num}p" "$PLAN_SRC")

    if [ "$dst" != "$src" ] && [ -e "$dst" ]; then
      src_inode=$(stat -f '%i' "$src" 2>/dev/null || echo "src_none")
      dst_inode=$(stat -f '%i' "$dst" 2>/dev/null || echo "dst_none")
      if [ "$src_inode" = "$dst_inode" ]; then
        # Case-only rename on case-insensitive FS — needs two-pass
        needs_two_pass=true
        break
      else
        # True overlap collision — different file exists at target path
        needs_two_pass=true
        break
      fi
    fi
  done < "$PLAN_DST"
fi

# Check 2: Resolve conflicts by appending _2, _3, etc.
# Conflicts include:
#   - Two plan entries mapping to the same target (plan-internal duplicate)
#   - A plan entry mapping to a target that already exists on disk as a different file
if [ "$planned" -gt 0 ]; then
  DST_RESOLVED=$(mktemp /tmp/std_dstr.XXXXXX)
  DST_NAMES_RESOLVED=$(mktemp /tmp/std_dstnr.XXXXXX)

  line_num=0
  while IFS= read -r dst; do
    line_num=$((line_num + 1))
    src=$(sed -n "${line_num}p" "$PLAN_SRC")
    dst_name=$(sed -n "${line_num}p" "$PLAN_DST_NAMES")
    needs_dedup=false

    # Check for plan-internal duplicates (same target appeared earlier)
    if [ "$line_num" -gt 1 ]; then
      prior_count=$(head -n "$((line_num - 1))" "$PLAN_DST" | grep -c "^${dst}$" 2>/dev/null || true)
      if [ "$prior_count" -gt 0 ]; then
        needs_dedup=true
      fi
    fi

    # Check for existing-file collision (target exists on disk as a different file)
    if ! $needs_dedup && [ "$dst" != "$src" ] && [ -e "$dst" ]; then
      src_inode=$(stat -f '%i' "$src" 2>/dev/null || echo "src_none")
      dst_inode=$(stat -f '%i' "$dst" 2>/dev/null || echo "dst_none")
      if [ "$src_inode" != "$dst_inode" ]; then
        needs_dedup=true
      fi
    fi

    # Also check if this target was already claimed in the resolved list
    if ! $needs_dedup && grep -q "^${dst}$" "$DST_RESOLVED" 2>/dev/null; then
      needs_dedup=true
    fi

    if $needs_dedup; then
      dir=$(dirname "$dst")
      case "$dst_name" in
        *.*)
          ext=".${dst_name##*.}"
          stem="${dst_name%.*}"
          ;;
        *)
          ext=""
          stem="$dst_name"
          ;;
      esac
      counter=2
      candidate="${dir}/${stem}_${counter}${ext}"
      while [ -e "$candidate" ] || grep -q "^${candidate}$" "$DST_RESOLVED" 2>/dev/null; do
        counter=$((counter + 1))
        candidate="${dir}/${stem}_${counter}${ext}"
      done
      echo "$candidate" >> "$DST_RESOLVED"
      echo "$(basename "$candidate")" >> "$DST_NAMES_RESOLVED"
    else
      echo "$dst" >> "$DST_RESOLVED"
      echo "$dst_name" >> "$DST_NAMES_RESOLVED"
    fi
  done < "$PLAN_DST"

  # Replace plan files with resolved versions
  mv -f "$DST_RESOLVED" "$PLAN_DST"
  mv -f "$DST_NAMES_RESOLVED" "$PLAN_DST_NAMES"
fi

# --- Output plan ---
echo "=== Filename Standardization Plan ==="
echo "Directory: $TARGET_DIR"
if [ "$MAX_DEPTH" -gt 1 ]; then
  echo "Recursive: yes"
else
  echo "Recursive: no"
fi
echo "Files scanned: $((planned + skipped))"
echo "Files to rename: $planned"
echo "Files already standardized: $skipped"
echo ""

if [ "$planned" -eq 0 ]; then
  echo "Nothing to rename. All filenames are already standardized."
  exit 0
fi

if $needs_two_pass; then
  echo "NOTE: Two-pass rename (via .tmp suffix) will be used."
  echo "      Reason: target names overlap with existing source names, or case-only"
  echo "      renames detected on a case-insensitive filesystem."
  echo ""
fi

echo "--- Rename Plan ---"
line_num=0
while IFS= read -r src_name; do
  line_num=$((line_num + 1))
  dst_name=$(sed -n "${line_num}p" "$PLAN_DST_NAMES")
  echo "  ${src_name}"
  echo "    -> ${dst_name}"
done < "$PLAN_SRC_NAMES"
echo ""

# --- Execution ---
if [ "$MODE" = "plan" ]; then
  echo "Mode: DRY RUN (no files modified)"
  echo "Re-run with --execute to apply renames."
  exit 0
fi

echo "Mode: EXECUTE"
echo ""

failures=0

if $needs_two_pass; then
  # Two-pass rename: first rename all to .tmp, then to final names
  echo "--- Pass 1: Rename to temporary names ---"
  line_num=0
  while IFS= read -r src; do
    line_num=$((line_num + 1))
    dst=$(sed -n "${line_num}p" "$PLAN_DST")
    src_name=$(sed -n "${line_num}p" "$PLAN_SRC_NAMES")
    dst_name=$(sed -n "${line_num}p" "$PLAN_DST_NAMES")
    tmp="${dst}.tmp"
    if ! mv -n "$src" "$tmp"; then
      echo "FAILED (pass 1): $src_name -> ${dst_name}.tmp" >&2
      failures=$((failures + 1))
    else
      echo "  ${src_name} -> ${dst_name}.tmp"
    fi
  done < "$PLAN_SRC"

  echo ""
  echo "--- Pass 2: Rename to final names ---"
  line_num=0
  while IFS= read -r dst; do
    line_num=$((line_num + 1))
    dst_name=$(sed -n "${line_num}p" "$PLAN_DST_NAMES")
    tmp="${dst}.tmp"
    if [ ! -e "$tmp" ]; then
      echo "SKIPPED (pass 2, tmp missing): ${dst_name}.tmp" >&2
      continue
    fi
    if ! mv -n "$tmp" "$dst"; then
      echo "FAILED (pass 2): ${dst_name}.tmp -> ${dst_name}" >&2
      failures=$((failures + 1))
    else
      echo "  ${dst_name}.tmp -> ${dst_name}"
    fi
  done < "$PLAN_DST"
else
  # Single-pass rename with mv -n
  echo "--- Executing renames ---"
  line_num=0
  while IFS= read -r src; do
    line_num=$((line_num + 1))
    dst=$(sed -n "${line_num}p" "$PLAN_DST")
    src_name=$(sed -n "${line_num}p" "$PLAN_SRC_NAMES")
    dst_name=$(sed -n "${line_num}p" "$PLAN_DST_NAMES")
    if ! mv -n "$src" "$dst"; then
      echo "FAILED: ${src_name} -> ${dst_name}" >&2
      failures=$((failures + 1))
    else
      echo "  ${src_name} -> ${dst_name}"
    fi
  done < "$PLAN_SRC"
fi

echo ""
echo "=== Results ==="
echo "Renamed: $((planned - failures)) files"
if [ "$failures" -gt 0 ]; then
  echo "Failed: $failures files"
  echo ""
  echo "IMPORTANT: Some renames failed. Check errors above."
  echo "           mv -n refuses to overwrite — this means a collision was not caught."
  echo "           Inspect the directory manually before retrying."
  exit 1
fi
echo "All renames completed successfully."
