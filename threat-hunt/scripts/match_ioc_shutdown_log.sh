#!/bin/bash
# match_ioc_shutdown_log.sh — Look for Pegasus XPC service names in shutdown and container logs
# Probe script: try each check, print what works, never abort on a failed sub-check.
source "$(dirname "$0")/_lib.sh"

# On iOS the artifact is /private/var/db/diagnostics/shutdown.log (what MVT reads). macOS
# has no such file; the nearest equivalents are the unified-log entries from the shutdown
# process and containermanagerd, which is what is searched here.
echo "=== Shutdown Log ==="
shutdown_log=$(log show --predicate 'process == "shutdown"' --last 7d --style compact 2>/dev/null | grep -v "^Timestamp" | head -200)
if [ -n "$shutdown_log" ]; then
  echo "  $(echo "$shutdown_log" | wc -l | tr -d ' ') entries in last 7 days"
else
  echo "  No shutdown-process entries in the last 7 days (normal if the Mac has not rebooted)"
fi

echo "=== Container Manager Log ==="
container_log=$(log show --predicate 'subsystem == "com.apple.containermanagerd"' --last 7d --style compact 2>/dev/null | grep -v "^Timestamp" | head -200)
if [ -n "$container_log" ]; then
  echo "  $(echo "$container_log" | wc -l | tr -d ' ') entries in last 7 days"
else
  echo "  No containermanagerd entries available"
fi

echo "=== XPC Service IOC Matching ==="
combined_logs="${shutdown_log}"$'\n'"${container_log}"
if [ -z "$(echo "$combined_logs" | tr -d '[:space:]')" ]; then
  echo "  SKIPPED: no log entries to analyze"
  exit 0
fi

match_found=0
for prefix in ioc_pegasus_ ioc_candiru_; do
  ioc_file=$(latest_ioc "$prefix")
  [ -z "$ioc_file" ] && continue
  ioc_staleness "$ioc_file"
  while IFS='|' read -r _ xpc_name desc; do
    [ -z "$xpc_name" ] && continue
    if echo "$combined_logs" | grep -qF "$xpc_name"; then
      echo "  [CRITICAL] IOC XPC service found in logs: $xpc_name ($desc)"
      echo "$combined_logs" | grep -F "$xpc_name" | head -3 | sed 's/^/    /'
      match_found=1
    fi
  done < <(grep "^xpc_service|" "$ioc_file" 2>/dev/null)
done
[ "$match_found" -eq 0 ] && echo "  No IOC XPC services found in logs (good)"

exit 0
