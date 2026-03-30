#!/bin/bash
set -e

# check_dylib_injection.sh — Detect DYLD_INSERT_LIBRARIES abuse

echo "=== DYLD_* in LaunchAgent/Daemon Plists ==="
found=0
for dir in "/Users/$USER/Library/LaunchAgents" "/Library/LaunchAgents" "/Library/LaunchDaemons"; do
  [ -d "$dir" ] || continue
  results=$(grep -rl "DYLD_" "$dir" 2>/dev/null || true)
  if [ -n "$results" ]; then
    echo "  [CRITICAL] DYLD variable found in:"
    echo "$results" | sed 's/^/    /'
    found=1
  fi
done
if [ "$found" -eq 0 ]; then
  echo "  None found (good)"
fi

echo "=== DYLD Environment in Running Processes ==="
found=0
ps -eww -o pid,command 2>/dev/null | grep -i "DYLD_INSERT_LIBRARIES" | grep -v "grep" | while read -r line; do
  echo "  [CRITICAL] Process with DYLD_INSERT_LIBRARIES: $line"
  found=1
done || true
if [ "$found" -eq 0 ]; then
  echo "  No processes with DYLD injection detected (good)"
fi

echo "=== SIP Protection for DYLD ==="
sip_status=$(csrutil status 2>/dev/null || echo "Unknown")
echo "  $sip_status"
if echo "$sip_status" | grep -q "disabled"; then
  echo "  [CRITICAL] SIP disabled — DYLD injection is unrestricted"
fi
