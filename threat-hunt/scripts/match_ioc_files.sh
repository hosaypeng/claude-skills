#!/bin/bash
# match_ioc_files.sh — Check the file system for known IOC paths and hashes
# Probe script: try each check, print what works, never abort on a failed sub-check.
source "$(dirname "$0")/_lib.sh"

echo "=== IOC File Path Scan ==="
total_hits=0
for prefix in ioc_pegasus_ ioc_candiru_; do
  ioc_file=$(latest_ioc "$prefix")
  if [ -z "$ioc_file" ]; then
    echo "  SKIPPED: No ${prefix}* file found"
    continue
  fi
  ioc_staleness "$ioc_file"

  while IFS='|' read -r _ ioc_path desc; do
    [ -z "$ioc_path" ] && continue
    [ -e "$ioc_path" ] || continue
    echo "  [CRITICAL] IOC path exists: $ioc_path ($desc)"
    total_hits=$((total_hits + 1))
    if [ -f "$ioc_path" ]; then
      file_hash=$(shasum -a 256 "$ioc_path" 2>/dev/null | awk '{print $1}')
      echo "    SHA256: $file_hash"
      if grep -qF "hash_sha256|$file_hash" "$ioc_file" 2>/dev/null; then
        echo "    [CRITICAL] Hash matches known IOC"
      fi
    fi
  done < <(grep "^path|" "$ioc_file" 2>/dev/null)
done
echo "  IOC paths matched: $total_hits"

exit 0
