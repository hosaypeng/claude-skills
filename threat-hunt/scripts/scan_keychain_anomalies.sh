#!/bin/bash
set -e

# scan_keychain_anomalies.sh — Keychain access patterns and anomalies

echo "=== Keychain Inventory ==="
security list-keychains 2>/dev/null | sed 's/^/  /' || echo "  Could not list keychains"

echo "=== Login Keychain Lock Settings ==="
keychain_db="/Users/$USER/Library/Keychains/login.keychain-db"
if [ -f "$keychain_db" ]; then
  info=$(security show-keychain-info "$keychain_db" 2>&1 || echo "Could not read keychain info")
  echo "  $info"
  if echo "$info" | grep -q "no-timeout"; then
    echo "  [LOW] Keychain has no lock timeout — consider setting one"
  fi
else
  echo "  Login keychain not found at expected path"
fi

echo "=== Recent Keychain Access (last hour) ==="
log show --predicate 'subsystem == "com.apple.securityd"' --last 1h --style compact 2>/dev/null | tail -20 | sed 's/^/  /' || echo "  SKIPPED: Could not read security daemon logs"

echo "=== Keychain Access Frequency ==="
access_count=$(log show --predicate 'subsystem == "com.apple.securityd"' --last 1h --style compact 2>/dev/null | wc -l | tr -d ' ' || echo "0")
access_count="${access_count:-0}"
[[ "$access_count" =~ ^[0-9]+$ ]] || access_count=0
echo "  Keychain access events in last hour: $access_count"
if [ "$access_count" -gt 100 ]; then
  echo "  [HIGH] Unusually high keychain access frequency"
fi
