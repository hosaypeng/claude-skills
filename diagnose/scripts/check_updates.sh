#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Software Updates & Patches ==="

echo "=== Pending Security Updates ==="
softwareupdate -l 2>&1 | grep -E "recommended|Security Update|critical" || echo "No critical updates found"

echo "=== Last Update Check ==="
defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist LastSuccessfulDate 2>/dev/null || echo "Unknown"
echo -n "Last MSU scan: "
defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist LastSuccessfulMSUScanDate 2>/dev/null || echo "Unknown"

echo "=== Automatic Updates Settings ==="
# macOS 27 no longer writes AutomaticCheckEnabled unless the user has toggled it, and an
# absent key means the default (enabled). Printing "0" for a missing key scored a -4
# deduction on every clean system. Only a key that is present AND 0 is a finding.
# Only AutomaticCheckEnabled carries a deduction in output_format.md, so only it is
# tagged; the other keys are context.
read_su_key() {
  local key="$1" tag="$2" val
  val=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate "$key" 2>/dev/null)
  if [ -z "$val" ]; then
    echo "$key: not set (macOS default: enabled)"
  elif [ "$val" = "0" ]; then
    echo "${tag}$key: 0 (explicitly disabled)"
  else
    echo "$key: $val"
  fi
}
read_su_key AutomaticCheckEnabled "[MEDIUM] "
read_su_key AutomaticDownload ""
read_su_key AutomaticallyInstallMacOSUpdates ""
read_su_key CriticalUpdateInstall ""
read_su_key ConfigDataInstall ""
echo -n "App Store AutoUpdate: "
defaults read /Library/Preferences/com.apple.commerce AutoUpdate 2>/dev/null || echo "not set (default: enabled)"

echo "=== Gatekeeper Status ==="
spctl --status 2>/dev/null || true

exit 0
