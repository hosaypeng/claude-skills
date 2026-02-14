#!/bin/bash
set -e

echo "=== Infostealer Detection: Network Exfiltration Indicators ==="

echo "=== Suspicious Network Activity ==="
netstat -an 2>/dev/null | grep ESTABLISHED | grep -v "127.0.0.1\|::1" | head -20 || true

echo "=== Connections on Known C2 Ports ==="
lsof -i -P 2>/dev/null | grep -E ":443|:80|:8080|:4444|:5555|:6666|:7777|:8888|:9999" | grep -v "Google\|Apple\|Cloudflare" | head -20 || true

echo "=== DNS Cache ==="
dscacheutil -cachedump -entries Host 2>/dev/null | head -30 || echo "DNS cache unavailable"
