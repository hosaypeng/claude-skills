#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Infostealer Detection: Network Exfiltration Indicators ==="

established=$(lsof -i -P -n 2>/dev/null | grep ESTABLISHED)

echo "=== Established Connections ==="
if [ -n "$established" ]; then
  echo "$established" | wc -l | tr -d ' ' | sed 's/^/  Total: /'
  echo "$established" | head -30 | sed 's/^/  /'
else
  echo "  None"
fi

echo "=== Connections on Non-Standard Ports ==="
# The previous filter matched process names against "Google|Apple|Cloudflare", which any
# malware can defeat by naming itself. Filtering by well-known port plus RFC1918 range
# describes the traffic instead of trusting the label on it.
if [ -n "$established" ]; then
  non_standard=$(echo "$established" | awk '{print $1, $2, $9}' \
    | grep -vE ':(80|443|993|587|465|143|53|22|5228|5223)$' \
    | grep -vE '127\.0\.0\.1|::1|10\.[0-9]|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.' \
    | grep -vE '\[fe80:' \
    | sort -u)
  if [ -n "$non_standard" ]; then
    echo "$non_standard" | sed 's/^/  [MEDIUM] /'
  else
    echo "  None"
  fi
else
  echo "  None"
fi

echo "=== Connection Count by Remote IP ==="
# A single remote endpoint holding many connections is the shape of a beacon.
if [ -n "$established" ]; then
  echo "$established" | awk '{print $9}' | sed 's/.*->//' \
    | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | sort | uniq -c | sort -rn | head -15 | sed 's/^/  /'
else
  echo "  No connections"
fi

echo "=== Proxy Configuration ==="
proxy_info=$(scutil --proxy 2>/dev/null || echo "unavailable")
proxy_keys=$(echo "$proxy_info" | grep -E "HTTPEnable|HTTPSEnable|SOCKSEnable|HTTPProxy|HTTPSProxy")
if [ -n "$proxy_keys" ]; then
  echo "$proxy_keys" | sed 's/^/  /'
else
  echo "  No proxy configured"
fi
if echo "$proxy_info" | grep -qE "(HTTPEnable|HTTPSEnable|SOCKSEnable)[[:space:]]*:[[:space:]]*1"; then
  echo "  [HIGH] A proxy is enabled - confirm this is intentional (traffic is interceptable)"
fi

echo "=== DNS Servers in Use ==="
dns=$(scutil --dns 2>/dev/null | grep "nameserver\[0\]" | sort -u | head -5)
[ -n "$dns" ] && echo "$dns" | sed 's/^/  /' || echo "  DNS config unavailable"

# Loopback DNS only means "hardened" if something is actually resolving there. With no local
# resolver running it is a hijack shape instead, so state which case this is rather than
# leaving the reader to guess.
if echo "$dns" | grep -qE "127\.0\.0\.1|::1"; then
  # Deliberately excludes mDNSResponder and csnameddatad: both run on every Mac, so counting
  # them as "a local resolver" would mean the hijack branch below could never fire.
  resolver=$(pgrep -l "dnscrypt-proxy|stubby|unbound|^named$|knot-resolver|pihole-FTL|coredns|AdGuard" 2>/dev/null | head -3)
  if [ -n "$resolver" ]; then
    echo "  Loopback DNS backed by a local resolver (expected, not a finding):"
    echo "$resolver" | sed 's/^/    /'
  else
    echo "  [HIGH] Loopback DNS with NO local resolver process running - possible DNS hijack"
  fi
fi

exit 0
