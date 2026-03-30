#!/bin/bash
set -e

# sweep_xpc_services.sh — Enumerate XPC services, flag non-Apple entries

echo "=== System XPC Services (non-Apple) ==="
launchctl print system 2>/dev/null | grep -E "^\s+" | grep -v "com.apple\." | grep -v "^\s*$" | head -30 || echo "  SKIPPED: Requires elevated privileges"

echo "=== User XPC Services (non-Apple) ==="
launchctl print "gui/$(id -u)/" 2>/dev/null | grep -E "^\s+" | grep -v "com.apple\." | grep -v "^\s*$" | head -30 || echo "  SKIPPED: Could not enumerate user XPC services"

echo "=== Non-Apple Services via launchctl list ==="
launchctl list 2>/dev/null | grep -v "com.apple\." | grep -v "^PID" | head -30 || echo "  SKIPPED: Could not list services"
