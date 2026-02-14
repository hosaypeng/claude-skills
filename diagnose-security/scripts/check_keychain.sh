#!/bin/bash
set -e

echo "=== Infostealer Detection: Keychain Access Audit ==="

echo "=== Keychain Files ==="
ls -la ~/Library/Keychains/

echo "=== Recent Keychain Access Logs ==="
log show --predicate 'subsystem == "com.apple.securityd"' --last 1h 2>/dev/null | grep -i "keychain" | tail -20 || echo "No recent keychain access logs"
