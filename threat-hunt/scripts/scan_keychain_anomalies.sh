#!/bin/bash
# scan_keychain_anomalies.sh — Keychain access patterns and anomalies
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Keychain Inventory ==="
security list-keychains 2>/dev/null | sed 's/^/  /' || echo "  Could not list keychains"

echo "=== Login Keychain Lock Settings ==="
keychain_db="$HOME/Library/Keychains/login.keychain-db"
if [ -f "$keychain_db" ]; then
  info=$(security show-keychain-info "$keychain_db" 2>&1 || echo "Could not read keychain info")
  echo "  $info"
  echo "$info" | grep -q "no-timeout" && echo "  [LOW] Keychain has no lock timeout — consider setting one"
else
  echo "  Login keychain not found at expected path"
fi

echo "=== Recent Keychain Item Access (last hour) ==="
# The unfiltered securityd subsystem emits thousands of benign TLS trust evaluations per
# hour. On macOS 27 the "xpc" category and the "makeUnlocked" DB-handle chatter alone pushed
# an idle machine past the old 200 threshold (274 at rest), so both are excluded, and the
# threshold is re-based at 100 (~3x the ~30/hour idle baseline). Same predicate as
# diagnose/check_keychain.sh.
item_access=$(log show --predicate 'subsystem == "com.apple.securityd" AND NOT category == "xpc" AND NOT eventMessage CONTAINS "makeUnlocked" AND NOT eventMessage CONTAINS "Trust" AND NOT eventMessage CONTAINS "trust" AND NOT eventMessage CONTAINS "MDSStaticDatabase" AND NOT eventMessage CONTAINS "LegacyAPICounts" AND (eventMessage CONTAINS "item" OR eventMessage CONTAINS "unlock" OR eventMessage CONTAINS "authori" OR eventMessage CONTAINS "ACL" OR eventMessage CONTAINS "keychain")' --last 1h --style compact 2>/dev/null | grep -v "^Timestamp")

if [ -n "$item_access" ]; then
  echo "$item_access" | tail -15 | sed 's/^/  /'
  access_count=$(echo "$item_access" | wc -l | tr -d ' ')
else
  echo "  No keychain item access events in the last hour"
  access_count=0
fi
[[ "$access_count" =~ ^[0-9]+$ ]] || access_count=0

echo "=== Keychain Access Frequency ==="
echo "  Keychain item access events in last hour: $access_count"
if [ "$access_count" -gt 100 ]; then
  echo "  [HIGH] Unusually high keychain item access frequency"
fi

echo "=== Top Keychain Consumers ==="
# Compact format: date time Ty Process[PID:TID] [subsystem:category] msg. The process name
# can contain spaces ("Google Drive"), so take everything before the first [PID:TID].
if [ "$access_count" -gt 0 ]; then
  echo "$item_access" | sed -E 's/^[^ ]+ +[^ ]+ +[^ ]+ +([^[]*)\[[0-9]+:[0-9]+\].*/\1/' | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
else
  echo "  None"
fi

exit 0
