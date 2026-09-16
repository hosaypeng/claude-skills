#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Infostealer Detection: Keychain Access Audit ==="

echo "=== Keychain Inventory ==="
security list-keychains 2>/dev/null | sed 's/^/  /' || echo "  Could not list keychains"
echo "  Keychain files: $(ls "$HOME/Library/Keychains/" 2>/dev/null | wc -l | tr -d ' ')"

echo "=== Login Keychain Lock Settings ==="
keychain_db="$HOME/Library/Keychains/login.keychain-db"
if [ -f "$keychain_db" ]; then
  info=$(security show-keychain-info "$keychain_db" 2>&1 || echo "Could not read keychain info")
  echo "  $info"
  echo "$info" | grep -q "no-timeout" && echo "  [LOW] Keychain has no lock timeout configured"
else
  echo "  Login keychain not found at expected path"
fi

echo "=== Recent Keychain Item Access (last hour) ==="
# The unfiltered securityd subsystem emits thousands of benign TLS trust evaluations per
# hour from iCloud/dataaccessd. Without this filter the check is pure noise.
item_access=$(log show --predicate 'subsystem == "com.apple.securityd" AND NOT eventMessage CONTAINS "Trust" AND NOT eventMessage CONTAINS "trust" AND NOT eventMessage CONTAINS "MDSStaticDatabase" AND NOT eventMessage CONTAINS "LegacyAPICounts" AND (eventMessage CONTAINS "item" OR eventMessage CONTAINS "unlock" OR eventMessage CONTAINS "authori" OR eventMessage CONTAINS "ACL" OR eventMessage CONTAINS "keychain")' --last 1h --style compact 2>/dev/null)

if [ -n "$item_access" ]; then
  echo "$item_access" | tail -15 | sed 's/^/  /'
  access_count=$(echo "$item_access" | wc -l | tr -d ' ')
else
  echo "  No keychain item access events in the last hour"
  access_count=0
fi

[[ "$access_count" =~ ^[0-9]+$ ]] || access_count=0
echo "=== Access Frequency ==="
echo "  Keychain item access events in last hour: $access_count"
if [ "$access_count" -gt 200 ]; then
  echo "  [HIGH] Unusually high keychain access frequency"
fi

echo "=== Top Keychain Consumers ==="
if [ "$access_count" -gt 0 ]; then
  echo "$item_access" | awk '{print $5}' | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
else
  echo "  None"
fi

exit 0
