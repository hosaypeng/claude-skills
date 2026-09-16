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
# hour from iCloud/dataaccessd. Without this filter the check is pure noise. On macOS 27
# the "xpc" category and KCdb "is unlocked; decoding for makeUnlocked()" lines alone
# pushed an idle machine past the threshold, so both are excluded too. The makeUnlocked
# line is securityd's internal DB-handle chatter, not a keychain unlock event, so
# excluding it does not defeat the "unlock" inclusion term.
item_access=$(log show --predicate 'subsystem == "com.apple.securityd" AND NOT category == "xpc" AND NOT eventMessage CONTAINS "makeUnlocked" AND NOT eventMessage CONTAINS "Trust" AND NOT eventMessage CONTAINS "trust" AND NOT eventMessage CONTAINS "MDSStaticDatabase" AND NOT eventMessage CONTAINS "LegacyAPICounts" AND (eventMessage CONTAINS "item" OR eventMessage CONTAINS "unlock" OR eventMessage CONTAINS "authori" OR eventMessage CONTAINS "ACL" OR eventMessage CONTAINS "keychain")' --last 1h --style compact 2>/dev/null | grep -v "^Timestamp")

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
# Idle baseline after the xpc/makeUnlocked filter is ~30/hour on macOS 27 (was ~260
# before it, which is why the old 200 threshold fired at rest). 100 leaves ~3x headroom.
if [ "$access_count" -gt 100 ]; then
  echo "  [HIGH] Unusually high keychain access frequency"
fi

echo "=== Top Keychain Consumers ==="
if [ "$access_count" -gt 0 ]; then
  # Compact format: date time Ty Process[PID:TID] [subsystem:category] msg. Column 5 is
  # the category, which is what this table used to show; the process is column 4.
  echo "$item_access" | awk '{print $4}' | sed 's/\[.*//' | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
else
  echo "  None"
fi

exit 0
