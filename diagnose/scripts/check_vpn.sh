#!/bin/bash
set -e

echo "=== VPN & Remote Access ==="

echo "=== VPN Connections ==="
scutil --nc list 2>/dev/null | grep -E "Connected|Disconnected" || true

echo "=== Screen Sharing ==="
launchctl list 2>/dev/null | grep screensharing || echo "Screen sharing not loaded"

echo "=== Remote Login (SSH) ==="
systemsetup -getremotelogin 2>/dev/null || echo "Check requires admin"

echo "=== Remote Management ==="
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -status 2>/dev/null || echo "Check requires admin"
