#!/bin/bash
set -e

echo "=== File Permissions & Integrity ==="

echo "--- Critical System File Permissions ---"
ls -la /etc/sudoers 2>/dev/null || true
ls -la /etc/hosts 2>/dev/null || true

echo "--- World-Writable Files in Home ---"
find ~ -type f -perm -002 2>/dev/null | head -10 || echo "None found"

echo "--- Suspicious /etc/hosts Entries ---"
grep -v "^#" /etc/hosts 2>/dev/null | grep -v "localhost\|broadcasthost" || echo "Clean"
