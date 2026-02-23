#!/bin/bash
set -e

echo "=== Encryption & Data Protection ==="

echo "=== FileVault Status ==="
fdesetup status 2>/dev/null || true

echo "=== Firmware Password ==="
firmwarepasswd -check 2>/dev/null || echo "Firmware password check requires admin"

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
