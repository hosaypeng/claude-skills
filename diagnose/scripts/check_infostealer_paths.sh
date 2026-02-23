#!/bin/bash
set -e

echo "=== Infostealer Detection: Known Paths & Patterns ==="

echo "=== Checking common infostealer paths ==="
ls -la /tmp/.* 2>/dev/null | head -20 || true
ls -la /var/tmp/.* 2>/dev/null | head -20 || true
ls -la ~/.* 2>/dev/null | grep -v "^\." | head -20 || true

echo "=== Hidden Application Support entries ==="
ls -la ~/Library/Application\ Support/.* 2>/dev/null || echo "None"

echo "=== Suspicious temp files ==="
find /tmp /var/tmp -type f \( -name "*.py" -o -name "*.sh" -o -name "*.dylib" -o -name "*.so" \) 2>/dev/null | head -20 || echo "None"

echo "=== Executables in /tmp ==="
find /tmp -type f -perm +111 2>/dev/null | head -10 || echo "None"
