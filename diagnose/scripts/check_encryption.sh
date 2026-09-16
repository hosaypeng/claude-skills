#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Encryption & Data Protection ==="

echo "=== FileVault Status ==="
fdesetup status 2>/dev/null || true

echo "=== Firmware Password ==="
# Apple Silicon has no firmware password (Secure Boot policy replaces it), and
# firmwarepasswd prints its 30-line usage text to stdout when run without root.
if [ "$(uname -m)" = "arm64" ]; then
  echo "Not applicable on Apple Silicon (Secure Boot policy replaces the firmware password)"
elif fw=$(firmwarepasswd -check 2>/dev/null) && echo "$fw" | grep -q "Password Enabled"; then
  echo "$fw" | grep "Password Enabled"
else
  echo "Firmware password check requires admin"
fi

echo "=== Keychain Info ==="
if security show-keychain-info 2>&1 | grep -q "no-timeout"; then
  echo "Default keychain: unlocked (no timeout)"
else
  echo "Default keychain: has lock timeout configured"
fi

echo "=== Screen Lock Settings ==="
echo -n "askForPassword: "
defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "0"
echo -n "askForPasswordDelay: "
defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "unknown"

exit 0
