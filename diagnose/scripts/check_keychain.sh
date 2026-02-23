#!/bin/bash
set -e

echo "=== Infostealer Detection: Keychain Access Audit ==="

echo "=== Keychain Files ==="
echo "Keychain files: $(ls ~/Library/Keychains/ 2>/dev/null | wc -l | tr -d ' ')"
echo "Keychain directory size: $(du -sh ~/Library/Keychains/ 2>/dev/null | cut -f1)"

echo "=== Recent Keychain Access Logs ==="
log show --predicate 'subsystem == "com.apple.securityd"' --last 1h 2>/dev/null | grep -i "keychain" | tail -20 || echo "No recent keychain access logs"
