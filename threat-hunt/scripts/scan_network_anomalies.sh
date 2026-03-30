#!/bin/bash
set -e

# scan_network_anomalies.sh — Detect suspicious network connections

echo "=== Established Connections ==="
established=$(lsof -i -P -n 2>/dev/null | grep ESTABLISHED || true)
if [ -n "$established" ]; then
  echo "$established" | head -50
else
  echo "  No established connections"
fi

echo "=== Non-Standard Port Connections ==="
if [ -n "$established" ]; then
  non_standard=$(echo "$established" | awk '{print $1, $2, $9}' \
    | grep -vE ':(80|443|993|587|465|143|53|22|5228) ' \
    | grep -vE '127\.0\.0\.1|10\.[0-9]|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.' \
    | sort -u || true)
  if [ -n "$non_standard" ]; then
    echo "$non_standard"
  else
    echo "  None found"
  fi
else
  echo "  None found"
fi

echo "=== Connection Count by Remote IP ==="
if [ -n "$established" ]; then
  echo "$established" | awk '{print $9}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq -c | sort -rn | head -15 || true
else
  echo "  No connections"
fi

echo "=== Proxy Configuration ==="
proxy_info=$(scutil --proxy 2>/dev/null || echo "unavailable")
echo "$proxy_info"
if echo "$proxy_info" | grep -qE "HTTPEnable\s*:\s*1|SOCKSEnable\s*:\s*1"; then
  echo "  [HIGH] Proxy enabled — verify this is intentional"
fi
