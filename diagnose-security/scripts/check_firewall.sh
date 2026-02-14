#!/bin/bash
set -e

echo "=== Firewall & Network Security ==="

echo "--- Firewall Status ---"
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || true
/usr/libexec/ApplicationFirewall/socketfilterfw --getblockall 2>/dev/null || true
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || true

echo "--- Open Ports & Listening Services ---"
lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR>1 {print $1, $9, $2}' | sort -u || true

echo "--- Sensitive Port Listeners ---"
lsof -iTCP:22,23,80,443,3306,3389,5432,6379,27017,8080,8443 -sTCP:LISTEN -P -n 2>/dev/null || true

echo "--- Active Connections ---"
netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || true

echo "--- DNS Settings ---"
scutil --dns 2>/dev/null | grep "nameserver\[0\]" | head -3 || true

echo "--- Proxy Settings ---"
scutil --proxy 2>/dev/null | grep -E "HTTPEnable|HTTPSEnable|HTTPProxy|HTTPSProxy" || true
