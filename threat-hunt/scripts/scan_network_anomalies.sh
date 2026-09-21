#!/bin/bash
# scan_network_anomalies.sh — Detect suspicious network connections
# Probe script: try each check, print what works, never abort on a failed sub-check.
source "$(dirname "$0")/_lib.sh"

established=$(lsof -i -P -n 2>/dev/null | grep ESTABLISHED)

echo "=== Established Connections ==="
if [ -n "$established" ]; then
  echo "  Total: $(echo "$established" | wc -l | tr -d ' ')"
  echo "$established" | awk '{print "  " $1, $2, $9}' | head -40
else
  echo "  No established connections"
fi

echo "=== Non-Standard Port Connections ==="
# Both filters look at the REMOTE endpoint only. The previous version grepped the whole
# "name pid local->remote" string, so the local 192.168.x.x address matched the RFC1918
# exclusion and every IPv4 connection was dropped - "None found" on every run. The port
# regex is anchored on end-of-line for the same reason (a trailing-space pattern never
# matched). Loopback, RFC1918 and link-local IPv6 peers are local chatter, not exfil.
if [ -n "$established" ]; then
  non_standard=$(echo "$established" | awk '{
      r = $9; sub(/.*->/, "", r)
      if (r ~ /:(80|443|993|587|465|143|53|22|5228|5223)$/) next
      if (r ~ /^(127\.0\.0\.1|\[::1\]|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|\[fe80:)/) next
      print $1, $2, $9 }' | sort -u)
  if [ -n "$non_standard" ]; then
    echo "$non_standard" | sed 's/^/  [MEDIUM] /'
  else
    echo "  None found"
  fi
else
  echo "  None found"
fi

echo "=== Connection Count by Remote IP ==="
# A single remote endpoint holding many connections is the shape of a beacon. The owner
# column comes from references/known_good_networks.txt and is an annotation for triage only:
# a known CDN never suppresses a finding, since C2 on AWS or Cloudflare is routine.
if [ -n "$established" ]; then
  echo "$established" | awk '{print $9}' | sed 's/.*->//' \
    | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | sort | uniq -c | sort -rn | head -15 \
    | while read -r count ip; do
        printf '  %4s  %-16s %s\n' "$count" "$ip" "$(ip_owner "$ip")"
      done
else
  echo "  No connections"
fi

echo "=== Proxy Configuration ==="
proxy_info=$(scutil --proxy 2>/dev/null || echo "unavailable")
proxy_keys=$(echo "$proxy_info" | grep -E "HTTPEnable|HTTPSEnable|SOCKSEnable|HTTPProxy|HTTPSProxy|SOCKSProxy")
if [ -n "$proxy_keys" ]; then
  echo "$proxy_keys" | sed 's/^/  /'
else
  echo "  No proxy configured"
fi
if echo "$proxy_info" | grep -qE "(HTTPEnable|HTTPSEnable|SOCKSEnable)[[:space:]]*:[[:space:]]*1"; then
  echo "  [HIGH] A proxy is enabled — confirm this is intentional (traffic is interceptable)"
fi

exit 0
