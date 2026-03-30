#!/bin/bash
set -e

# match_ioc_domains.sh — Resolve IOC domains and check against active connections

REFS_DIR="$(cd "$(dirname "$0")/../references" && pwd)"

echo "=== Active Connection IPs ==="
active_ips=$(lsof -i -P -n 2>/dev/null | grep ESTABLISHED | awk '{print $9}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u || true)
if [ -n "$active_ips" ]; then
  ip_count=$(echo "$active_ips" | wc -l | tr -d ' ')
  echo "  $ip_count unique remote IPs in active connections"
else
  ip_count=0
  echo "  No active connections"
fi

echo "=== IOC Domain Resolution ==="
ioc_file=$(ls "$REFS_DIR"/ioc_domains_c2_*.txt 2>/dev/null | sort | tail -1 || true)
if [ -z "$ioc_file" ]; then
  echo "  SKIPPED: No IOC domain file found"
  exit 0
fi

if [ "$ip_count" -eq 0 ]; then
  echo "  No active connections to check against"
  exit 0
fi

# Check a sample of domains
domains=$(grep -v "^#" "$ioc_file" | cut -d'|' -f1 | grep -v "^$" | head -25 || true)
while read -r domain; do
  [ -z "$domain" ] && continue
  resolved=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $NF}' || true)
  [ -z "$resolved" ] && continue
  while read -r ip; do
    if echo "$active_ips" | grep -qFx "$ip"; then
      echo "  [CRITICAL] Active connection to IOC domain: $domain ($ip)"
    fi
  done <<< "$resolved"
done <<< "$domains"

echo "  Domain resolution check complete"
