#!/bin/bash
# match_ioc_domains.sh — Resolve IOC domains and compare against active connection IPs
# Probe script: try each check, print what works, never abort on a failed sub-check.
source "$(dirname "$0")/_lib.sh"

# OPSEC note: this probe sends DNS queries for known-bad domains from this machine. On a
# monitored network that looks like a compromise indicator, and it tells anyone watching the
# resolver that these domains are being checked. Run `ioc` mode only where that is acceptable.

echo "=== Active Connection IPs ==="
active_ips=$(lsof -i -P -n 2>/dev/null | grep ESTABLISHED | awk '{print $9}' \
  | sed 's/.*->//' | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u)
if [ -n "$active_ips" ]; then
  ip_count=$(echo "$active_ips" | wc -l | tr -d ' ')
  echo "  $ip_count unique remote IPs in active connections"
else
  ip_count=0
  echo "  No active connections"
fi

echo "=== IOC Domain Resolution ==="
ioc_file=$(latest_ioc ioc_domains_c2_)
if [ -z "$ioc_file" ]; then
  echo "  SKIPPED: No ioc_domains_c2_* file found"
  exit 0
fi
ioc_staleness "$ioc_file"
if [ "$ip_count" -eq 0 ]; then
  echo "  No active connections to check against"
  exit 0
fi

# Sample only: resolving every listed domain is slow (dead domains time out) and noisy.
domains=$(grep -v "^#" "$ioc_file" | cut -d'|' -f1 | grep -v "^$" | head -25)
checked=0
hits=0
while read -r domain; do
  [ -z "$domain" ] && continue
  checked=$((checked + 1))
  resolved=$(host -W 2 "$domain" 2>/dev/null | grep "has address" | awk '{print $NF}')
  [ -z "$resolved" ] && continue
  while read -r ip; do
    if echo "$active_ips" | grep -qFx "$ip"; then
      echo "  [CRITICAL] Active connection to IOC domain: $domain ($ip)"
      hits=$((hits + 1))
    fi
  done <<< "$resolved"
done <<< "$domains"
echo "  $checked domains queried, $hits matched active connections"

exit 0
