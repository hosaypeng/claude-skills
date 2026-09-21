#!/bin/bash
# match_ioc_processes.sh — Check running processes against known spyware process names
# Probe script: try each check, print what works, never abort on a failed sub-check.
source "$(dirname "$0")/_lib.sh"

echo "=== Known Spyware Process Scan ==="
running_procs=$(ps -eo comm= 2>/dev/null | sed 's#.*/##' | sort -u)
running_args=$(ps -eo pid=,args= 2>/dev/null)

match_found=0
for prefix in ioc_pegasus_ ioc_candiru_; do
  ioc_file=$(latest_ioc "$prefix")
  [ -z "$ioc_file" ] && continue
  ioc_staleness "$ioc_file"

  while IFS='|' read -r _ proc_name desc; do
    [ -z "$proc_name" ] && continue
    # Exact basename match against the process table.
    if echo "$running_procs" | grep -qFx "$proc_name"; then
      echo "  [CRITICAL] Spyware process detected: $proc_name ($desc)"
      echo "    PIDs: $(ps -eo pid=,comm= 2>/dev/null | grep -F "/$proc_name" | awk '{print $1}' | tr '\n' ' ')"
      match_found=1
    fi
    # Substring match against full command lines catches the name passed as an argument.
    if echo "$running_args" | grep -qF "$proc_name"; then
      echo "  [HIGH] Process argument match for '$proc_name':"
      echo "$running_args" | grep -F "$proc_name" | head -3 | sed 's/^/    /'
      match_found=1
    fi
  done < <(grep "^process|" "$ioc_file" 2>/dev/null)
done

if [ "$match_found" -eq 0 ]; then
  echo "  No known spyware processes detected (good)"
fi

exit 0
