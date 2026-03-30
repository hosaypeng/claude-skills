#!/bin/bash
set -e

# match_ioc_processes.sh — Check running processes against known spyware process names

REFS_DIR="$(cd "$(dirname "$0")/../references" && pwd)"

echo "=== Known Spyware Process Scan ==="

running_procs=$(ps -eo comm= 2>/dev/null | sort -u)
running_args=$(ps -eo pid,args= 2>/dev/null || true)

match_found=0
for pattern in "ioc_pegasus_" "ioc_candiru_"; do
  ioc_file=$(ls "$REFS_DIR"/${pattern}*.txt 2>/dev/null | sort | tail -1 || true)
  [ -z "$ioc_file" ] && continue

  while read -r line; do
    proc_name=$(echo "$line" | cut -d'|' -f2)
    desc=$(echo "$line" | cut -d'|' -f3)
    [ -z "$proc_name" ] && continue

    # Check against running process names (fixed-string exact match)
    if echo "$running_procs" | grep -qFx "$proc_name"; then
      echo "  [CRITICAL] Spyware process detected: $proc_name ($desc)"
      echo "    PIDs: $(ps -eo pid,comm= 2>/dev/null | grep -F "$proc_name" | awk '{print $1}' | tr '\n' ' ')"
      match_found=1
    fi

    # Check against process arguments (fixed-string match)
    if echo "$running_args" | grep -qF "$proc_name"; then
      matching=$(echo "$running_args" | grep -F "$proc_name" | head -3)
      echo "  [HIGH] Process argument match for '$proc_name':"
      echo "$matching" | sed 's/^/    /'
    fi
  done < <(grep "^process|" "$ioc_file" 2>/dev/null || true)
done

if [ "$match_found" -eq 0 ]; then
  echo "  No known spyware processes detected (good)"
fi
