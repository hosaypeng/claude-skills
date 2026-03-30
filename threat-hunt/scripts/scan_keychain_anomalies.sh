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

echo "=== Recent Keychain Item Access (last hour) ==="
# Filter to actual keychain item operations, excluding routine TLS trust evaluations
# which generate thousands of benign entries per hour from iCloud/dataaccessd
item_access=$(log show --predicate 'subsystem == "com.apple.securityd" AND NOT eventMessage CONTAINS "Trust" AND NOT eventMessage CONTAINS "trust" AND NOT eventMessage CONTAINS "MDSStaticDatabase" AND NOT eventMessage CONTAINS "LegacyAPICounts" AND (eventMessage CONTAINS "item" OR eventMessage CONTAINS "unlock" OR eventMessage CONTAINS "authori" OR eventMessage CONTAINS "ACL" OR eventMessage CONTAINS "keychain")' --last 1h --style compact 2>/dev/null || true)

if [ -n "$item_access" ]; then
  echo "$item_access" | tail -20 | sed 's/^/  /'
else
  echo "  No keychain item access events in last hour"
fi

echo "=== Keychain Access Frequency ==="
if [ -n "$item_access" ]; then
  access_count=$(echo "$item_access" | wc -l | tr -d ' ')
else
  access_count=0
fi
access_count="${access_count:-0}"
[[ "$access_count" =~ ^[0-9]+$ ]] || access_count=0
echo "  Keychain item access events in last hour: $access_count"
if [ "$access_count" -gt 200 ]; then
  echo "  [HIGH] Unusually high keychain item access frequency"
fi

echo "=== Non-Standard Keychain Consumers ==="
# Check if any unusual processes are accessing keychains
if [ -n "$item_access" ]; then
  consumers=$(echo "$item_access" | awk '{print $5}' | sort | uniq -c | sort -rn | head -10 || true)
  if [ -n "$consumers" ]; then
    echo "$consumers" | sed 's/^/  /'
  fi
fi
