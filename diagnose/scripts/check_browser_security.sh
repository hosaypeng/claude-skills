#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Browser Security (Safari & Chrome) ==="

# Safari is sandboxed: its preferences live in the container, not in the
# com.apple.Safari defaults domain, which `defaults read` reports as missing on macOS 27.
# A key that is absent from the container plist means Safari's default, not "unknown".
SAFARI_PLIST="$HOME/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist"

read_safari_key() {
  local key="$1" default_label="$2" val
  if [ ! -f "$SAFARI_PLIST" ]; then
    echo "plist unreadable (Safari container missing or no Full Disk Access)"
    return 0
  fi
  val=$(plutil -extract "$key" raw "$SAFARI_PLIST" 2>/dev/null)
  if [ -z "$val" ]; then
    echo "default ($default_label)"
  else
    echo "$val"
  fi
  return 0
}

echo "=== Safari Privacy Settings ==="
echo -n "Fraudulent site warnings: "
fraud=$(read_safari_key WarnAboutFraudulentWebsites "on")
echo "$fraud"
[ "$fraud" = "false" ] && echo "[MEDIUM] Safari fraudulent site warnings are explicitly disabled"
echo -n "Enhanced privacy in regular browsing: "
read_safari_key EnableEnhancedPrivacyInRegularBrowsing "off"
echo -n "Do Not Track header: "
read_safari_key SendDoNotTrackHTTPHeader "off - Safari dropped DNT"
echo -n "Private click measurement: "
read_safari_key WebKitPreferences.privateClickMeasurementEnabled "on"

echo "=== Safari Extensions ==="
# ~/Library/Safari/Extensions is gone; app extensions register with pluginkit.
exts=$(pluginkit -m -p com.apple.Safari.extension 2>/dev/null | sed 's/^[[:space:]]*//')
if [ -n "$exts" ]; then
  echo "$exts" | sed 's/^/  /'
else
  echo "  None"
fi

exit 0
