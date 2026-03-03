#!/usr/bin/env bash
# Audit all iCloud containers in ~/Library/Mobile Documents/
# Reports: containers with files, file counts, sizes, artifacts, and empty containers

set -euo pipefail

BASE="$HOME/Library/Mobile Documents"

if [ ! -d "$BASE" ]; then
  echo "ERROR: $BASE does not exist"
  exit 1
fi

echo "========================================="
echo "  iCloud Full Audit"
echo "========================================="
echo ""

# --- Artifact scan ---
echo "=== Artifacts & Metadata ==="
artifact_count=0
while IFS= read -r f; do
  artifact_count=$((artifact_count + 1))
  size=$(stat -f "%z" "$f" 2>/dev/null || echo "0")
  echo "[ARTIFACT] $f ($size B)"
done < <(find "$BASE" -type f \( \
  -name ".DS_Store" -o \
  -name "Thumbs.db" -o \
  -name "*.tmp" -o \
  -name ".Spotlight-*" -o \
  -name ".Trashes" -o \
  -name "__MACOSX" -o \
  -name "._*" -o \
  -name ".fseventsd" -o \
  -name ".TemporaryItems" \
\) 2>/dev/null)

if [ "$artifact_count" -eq 0 ]; then
  echo "No artifacts found."
fi
echo ""
echo "$artifact_count artifact(s) found."
echo ""
echo "-----------------------------------------"
echo ""

# --- Per-container inventory ---
echo "=== Container Inventory ==="
echo ""

total_files=0
total_bytes=0
containers_with_files=0
containers_empty=0

for dir in "$BASE"/*/; do
  [ -d "$dir" ] || continue
  container=$(basename "$dir")

  # Count files (excluding .DS_Store and .hidden)
  count=$(find "$dir" -type f -not -name ".DS_Store" -not -name ".hidden" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$count" -gt 0 ]; then
    containers_with_files=$((containers_with_files + 1))
    # Calculate total size
    bytes=$(find "$dir" -type f -not -name ".DS_Store" -not -name ".hidden" -exec stat -f "%z" {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
    total_files=$((total_files + count))
    total_bytes=$((total_bytes + bytes))

    # Format size
    if [ "$bytes" -gt 1048576 ]; then
      size=$(echo "$bytes" | awk '{printf "%.1f MB", $1/1048576}')
    elif [ "$bytes" -gt 1024 ]; then
      size=$(echo "$bytes" | awk '{printf "%.0f KB", $1/1024}')
    else
      size="${bytes} B"
    fi

    echo "--- $container ($count files, $size) ---"

    # List files with sizes (for containers with < 50 files, list individually)
    if [ "$count" -le 50 ]; then
      find "$dir" -type f -not -name ".DS_Store" -not -name ".hidden" 2>/dev/null | sort | while IFS= read -r f; do
        rel="${f#$dir}"
        fsize=$(stat -f "%z" "$f" 2>/dev/null || echo "0")
        if [ "$fsize" -gt 1048576 ]; then
          fsz=$(echo "$fsize" | awk '{printf "%.1f MB", $1/1048576}')
        elif [ "$fsize" -gt 1024 ]; then
          fsz=$(echo "$fsize" | awk '{printf "%.0f KB", $1/1024}')
        else
          fsz="${fsize} B"
        fi
        printf "  %-80s %10s\n" "$rel" "$fsz"
      done
    else
      # For large containers (e.g., iBooks), group by top-level subfolder
      echo "  (Grouped by top-level item — too many files to list individually)"
      find "$dir" -type f -not -name ".DS_Store" -not -name ".hidden" 2>/dev/null | while IFS= read -r f; do
        rel="${f#$dir}"
        # Get top-level grouping (first path component under Documents/ or root)
        if [[ "$rel" == Documents/* ]]; then
          item=$(echo "$rel" | sed 's|^Documents/||' | cut -d'/' -f1)
        else
          item=$(echo "$rel" | cut -d'/' -f1)
        fi
        fsize=$(stat -f "%z" "$f" 2>/dev/null || echo "0")
        echo "$item $fsize"
      done | awk '{
        items[$1] += $2
        counts[$1]++
      } END {
        for (item in items) {
          size = items[item]
          count = counts[item]
          if (size > 1048576)
            printf "  %-70s %4d files  %10.1f MB\n", item, count, size/1048576
          else if (size > 1024)
            printf "  %-70s %4d files  %10.0f KB\n", item, count, size/1024
          else
            printf "  %-70s %4d files  %10d B\n", item, count, size
        }
      }' | sort -t'M' -k1 -rn
    fi
    echo ""
  else
    containers_empty=$((containers_empty + 1))
  fi
done

echo "-----------------------------------------"
echo ""

# Format total size
if [ "$total_bytes" -gt 1073741824 ]; then
  total_size=$(echo "$total_bytes" | awk '{printf "%.1f GB", $1/1073741824}')
elif [ "$total_bytes" -gt 1048576 ]; then
  total_size=$(echo "$total_bytes" | awk '{printf "%.1f MB", $1/1048576}')
else
  total_size=$(echo "$total_bytes" | awk '{printf "%.0f KB", $1/1024}')
fi

echo "=== Summary ==="
echo "Total files:              $total_files"
echo "Total size:               $total_size"
echo "Containers with files:    $containers_with_files"
echo "Empty containers:         $containers_empty"
echo "Artifacts found:          $artifact_count"
echo ""
echo "========================================="
echo "  Audit Complete"
echo "========================================="
