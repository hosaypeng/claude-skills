#!/bin/bash
set -e

# match_ioc_shutdown_log.sh — Analyze shutdown.log for Pegasus XPC indicators

REFS_DIR="$(cd "$(dirname "$0")/../references" && pwd)"

echo "=== Shutdown Log XPC Analysis ==="

# Try to read shutdown-related logs
shutdown_log=$(log show --predicate 'process == "shutdown"' --last 7d 2>/dev/null | head -200 || true)
if [ -z "$shutdown_log" ]; then
  echo "  SKIPPED: Shutdown log unavailable (requires Full Disk Access)"
fi

echo "=== Container Manager Log Analysis ==="
container_log=$(log show --predicate 'subsystem == "com.apple.containermanagerd"' --last 7d 2>/dev/null | head -200 || true)
if [ -z "$container_log" ]; then
  echo "  SKIPPED: Container manager log unavailable"
fi

echo "=== XPC Service IOC Matching ==="
combined_logs="${shutdown_log}${container_log}"
if [ -z "$combined_logs" ]; then
  echo "  No logs available to analyze"
  exit 0
fi

match_found=0
for pattern in "ioc_pegasus_" "ioc_candiru_"; do
  ioc_file=$(ls "$REFS_DIR"/${pattern}*.txt 2>/dev/null | sort | tail -1 || true)
  [ -z "$ioc_file" ] && continue

  while read -r line; do
    xpc_name=$(echo "$line" | cut -d'|' -f2)
    desc=$(echo "$line" | cut -d'|' -f3)
    [ -z "$xpc_name" ] && continue

    if echo "$combined_logs" | grep -qF "$xpc_name"; then
      echo "  [CRITICAL] IOC XPC service found in logs: $xpc_name ($desc)"
      echo "$combined_logs" | grep -F "$xpc_name" | head -3 | sed 's/^/    /'
      match_found=1
    fi
  done < <(grep "^xpc_service|" "$ioc_file" 2>/dev/null || true)
done

if [ "$match_found" -eq 0 ]; then
  echo "  No IOC XPC services found in logs (good)"
fi
