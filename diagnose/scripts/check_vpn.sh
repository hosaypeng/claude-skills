#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== VPN & Remote Access ==="

echo "=== VPN Connections ==="
scutil --nc list 2>/dev/null | grep -E "Connected|Disconnected" || true

echo "=== Screen Sharing ==="
launchctl list 2>/dev/null | grep screensharing || echo "Screen sharing not loaded"

echo "=== Remote Login (SSH) ==="
# systemsetup -getremotelogin prints "You need administrator access" with exit 0, so the
# fallback never fired and the error text stood in for a value. Same fix as check_auth.sh:
# a listening port 22 needs no privilege.
if lsof -iTCP:22 -sTCP:LISTEN -P -n >/dev/null 2>&1; then
  echo "[MEDIUM] Remote Login: On (sshd listening on port 22)"
else
  echo "Remote Login: Off (nothing listening on port 22)"
fi

echo "=== Remote Management ==="
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -status 2>/dev/null || echo "Check requires admin"

exit 0
