#!/usr/bin/env bash
# Audit all iCloud containers in ~/Library/Mobile Documents/
# Reports: artifacts (junk metadata), per-container file counts and sizes,
# not-yet-downloaded placeholders, and empty containers.
#
# Environment:
#   ICLOUD_AUDIT_SUMMARY=1   container totals only — skip per-file listings
#   ICLOUD_AUDIT_TSV=<path>  also write each artifact as kind<TAB>bytes<TAB>path
#                            (consumed by `audit-icloud clean`)
#
# Always exits 0 unless the iCloud mirror is missing. Never modifies anything.

set -euo pipefail

BASE="$HOME/Library/Mobile Documents"
SUMMARY="${ICLOUD_AUDIT_SUMMARY:-0}"
TSV="${ICLOUD_AUDIT_TSV:-}"
LIST_LIMIT=50                            # more files than this → grouped by top-level item
NO_LIST_CONTAINERS="iCloud~md~obsidian"  # count/size only; vault files have their own audit

# Artifact patterns. Files and directories are matched separately because a
# `find -type f` never sees the directory ones (.Trashes, __MACOSX, ...).
ARTIFACT_FILES=(.DS_Store Thumbs.db '*.tmp' '._*')
ARTIFACT_DIRS=('.Spotlight-*' .Trashes __MACOSX .fseventsd .TemporaryItems)

# awk-side size formatter, shared by every listing so all tiers agree.
AWK_FMT='function fmt(b) {
  if (b >= 1073741824) return sprintf("%.1f GB", b / 1073741824)
  if (b >= 1048576)    return sprintf("%.1f MB", b / 1048576)
  if (b >= 1024)       return sprintf("%.0f KB", b / 1024)
  return sprintf("%d B", b)
}'

fmt_bytes() { awk -v b="$1" "$AWK_FMT"'BEGIN { print fmt(b) }'; }
plural()    { if [ "$1" -eq 1 ]; then echo "$1 file"; else echo "$1 files"; fi; }

# Build "( -name p1 -o -name p2 ... )" as a find expression array in NAME_EXPR.
build_name_expr() {
  local -a out=( '(' )
  local p first=1
  for p in "$@"; do
    [ "$first" = 1 ] || out+=( -o )
    out+=( -name "$p" )
    first=0
  done
  out+=( ')' )
  NAME_EXPR=( "${out[@]}" )
}
build_name_expr "${ARTIFACT_FILES[@]}"; FILE_EXPR=( "${NAME_EXPR[@]}" )
build_name_expr "${ARTIFACT_DIRS[@]}";  DIR_EXPR=( "${NAME_EXPR[@]}" )

if [ ! -d "$BASE" ]; then
  echo "ERROR: $BASE does not exist" >&2
  exit 1
fi

echo "========================================="
if [ "$SUMMARY" = 1 ]; then
  echo "  iCloud Audit (summary)"
else
  echo "  iCloud Full Audit"
fi
echo "========================================="
echo ""

# --- Artifact scan -----------------------------------------------------------
echo "=== Artifacts & Metadata ==="
artifact_count=0
artifact_bytes=0
[ -z "$TSV" ] || : > "$TSV"

emit_artifact() {  # $1 kind (file|dir), $2 bytes, $3 path
  artifact_count=$((artifact_count + 1))
  artifact_bytes=$((artifact_bytes + $2))
  echo "[ARTIFACT] $3 ($(fmt_bytes "$2"))"
  if [ -n "$TSV" ]; then
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$TSV"
  fi
}

# Artifact directories first (pruned, so their contents are not double-counted).
while IFS= read -r path; do
  [ -n "$path" ] || continue
  kb=$(du -sk "$path" 2>/dev/null | cut -f1)
  emit_artifact dir "$(( ${kb:-0} * 1024 ))" "$path"
done < <(find "$BASE" -type d "${DIR_EXPR[@]}" -prune -print 2>/dev/null || true)

# Artifact files, skipping anything inside an artifact directory.
while IFS=$'\t' read -r bytes path; do
  [ -n "$path" ] || continue
  emit_artifact file "$bytes" "$path"
done < <(find "$BASE" \( -type d "${DIR_EXPR[@]}" -prune \) -o \
  \( -type f "${FILE_EXPR[@]}" -exec stat -f '%z%t%N' {} + \) 2>/dev/null || true)

if [ "$artifact_count" -eq 0 ]; then
  echo "No artifacts found."
fi
echo ""
echo "$artifact_count artifact(s) found."
echo ""
echo "-----------------------------------------"
echo ""

# --- Per-container inventory -------------------------------------------------
echo "=== Container Inventory ==="
echo ""

total_files=0
total_bytes=0
total_placeholders=0
containers_with_files=0
containers_empty=0

for dir in "$BASE"/*/; do
  [ -d "$dir" ] || continue
  container=$(basename "$dir")

  # One walk per container: "bytes<TAB>path" for every real file. Artifact
  # files are excluded and artifact directories pruned so they are not counted
  # as content.
  listing=$(find "$dir" \( -type d "${DIR_EXPR[@]}" -prune \) -o \
    \( -type f ! "${FILE_EXPR[@]}" ! -name .hidden -exec stat -f '%z%t%N' {} + \) \
    2>/dev/null || true)

  # ".name.ext.icloud" is a placeholder for a file not downloaded to this Mac;
  # its on-disk size is a stub, so it is counted but never sized.
  placeholders=$(printf '%s\n' "$listing" | grep -c '/\.[^/]*\.icloud$' || true)
  files=$(printf '%s\n' "$listing" | grep -v '/\.[^/]*\.icloud$' || true)
  count=$(printf '%s\n' "$files" | awk 'NF { n++ } END { print n + 0 }')
  bytes=$(printf '%s\n' "$files" | awk -F'\t' 'NF { s += $1 } END { print s + 0 }')

  if [ "$count" -eq 0 ] && [ "$placeholders" -eq 0 ]; then
    containers_empty=$((containers_empty + 1))
    continue
  fi

  containers_with_files=$((containers_with_files + 1))
  total_files=$((total_files + count))
  total_bytes=$((total_bytes + bytes))
  total_placeholders=$((total_placeholders + placeholders))

  header="--- $container ($(plural "$count"), $(fmt_bytes "$bytes")"
  if [ "$placeholders" -gt 0 ]; then
    header="$header, $placeholders not downloaded"
  fi
  echo "$header) ---"

  case "$(printf '%s' "$container" | tr '[:upper:]' '[:lower:]')" in
    *whatsapp*) echo "  (encrypted WhatsApp backup — never modify)" ;;
  esac

  if [ "$SUMMARY" = 1 ] || [ "$count" -eq 0 ]; then
    continue
  fi

  case " $NO_LIST_CONTAINERS " in
    *" $container "*)
      echo "  (files not listed — audit this container with its own tool)"
      echo ""
      continue ;;
  esac

  if [ "$count" -le "$LIST_LIMIT" ]; then
    printf '%s\n' "$files" | sort -t$'\t' -k2 \
      | awk -F'\t' -v dir="$dir" "$AWK_FMT"'NF {
          printf "  %-80s %10s\n", substr($2, length(dir) + 1), fmt($1)
        }'
  else
    echo "  (grouped by top-level item — too many files to list individually)"
    # Group by the first path component under Documents/ (or the root),
    # sum bytes per item, then sort by size before formatting.
    printf '%s\n' "$files" \
      | awk -F'\t' -v dir="$dir" 'NF {
          rel = substr($2, length(dir) + 1)
          sub(/^Documents\//, "", rel)
          split(rel, parts, "/")
          bytes[parts[1]] += $1
          n[parts[1]]++
        } END {
          for (item in bytes) printf "%d\t%d\t%s\n", bytes[item], n[item], item
        }' \
      | sort -t$'\t' -k1,1nr \
      | awk -F'\t' "$AWK_FMT"'{
          printf "  %-70s %4d %-5s  %10s\n", $3, $2, ($2 == 1 ? "file" : "files"), fmt($1)
        }'
  fi
  echo ""
done

echo "-----------------------------------------"
echo ""
echo "=== Summary ==="
echo "Total files:              $total_files"
echo "Total size:               $(fmt_bytes "$total_bytes")"
if [ "$total_placeholders" -gt 0 ]; then
  echo "Not downloaded:           $total_placeholders"
fi
echo "Containers with files:    $containers_with_files"
echo "Empty containers:         $containers_empty"
echo "Artifacts found:          $artifact_count ($(fmt_bytes "$artifact_bytes"))"
echo ""
echo "========================================="
echo "  Audit Complete"
echo "========================================="
