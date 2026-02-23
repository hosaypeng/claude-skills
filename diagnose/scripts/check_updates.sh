#!/bin/bash
set -e

echo "=== Software Updates & Patches ==="

echo "=== Pending Security Updates ==="
softwareupdate -l 2>&1 | grep -E "recommended|Security Update|critical" || echo "No critical updates found"

echo "=== Last Update Check ==="
defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist LastSuccessfulDate 2>/dev/null || echo "Unknown"

echo "=== Automatic Updates Settings ==="
echo -n "AutomaticCheckEnabled: "
defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo "0"
echo -n "AutomaticDownload: "
defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload 2>/dev/null || echo "0"
echo -n "AutoUpdate: "
defaults read /Library/Preferences/com.apple.commerce AutoUpdate 2>/dev/null || echo "0"

echo "=== Gatekeeper Status ==="
spctl --status 2>/dev/null || true
