#!/bin/bash
set -e

# match_ioc_files.sh — Check file system for known IOC paths and hashes

REFS_DIR="$(cd "$(dirname "$0")/../references" && pwd)"

echo "=== IOC File Path Scan ==="

for pattern in "ioc_pegasus_" "ioc_candiru_"; do
  ioc_file=$(ls "$REFS_DIR"/${pattern}*.txt 2>/dev/null | sort | tail -1 || true)
  if [ -z "$ioc_file" ]; then
    echo "  SKIPPED: No ${pattern}* file found"
    continue
  fi

  # Staleness
  ioc_date=$(basename "$ioc_file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "unknown")
  if [ "$ioc_date" != "unknown" ]; then
    days_old=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$ioc_date" +%s 2>/dev/null || echo "0")) / 86400 ))
    echo "  $(basename "$ioc_file"): $ioc_date ($days_old days ago)"
  fi

  # Path checks
  grep "^path|" "$ioc_file" 2>/dev/null | cut -d'|' -f2 | while read -r ioc_path; do
    [ -z "$ioc_path" ] && continue
    if [ -e "$ioc_path" ]; then
      desc=$(grep "^path|$ioc_path|" "$ioc_file" | cut -d'|' -f3 || echo "unknown")
      echo "  [CRITICAL] IOC path exists: $ioc_path ($desc)"
      # Hash verification if file
      if [ -f "$ioc_path" ]; then
        file_hash=$(shasum -a 256 "$ioc_path" 2>/dev/null | awk '{print $1}' || true)
        echo "    SHA256: $file_hash"
        if grep -q "hash_sha256|$file_hash" "$ioc_file" 2>/dev/null; then
          echo "    [CRITICAL] Hash matches known IOC!"
        fi
      fi
    fi
  done
done

echo "  Scan complete"
