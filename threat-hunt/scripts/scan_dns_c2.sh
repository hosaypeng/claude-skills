#!/bin/bash
set -e

# scan_dns_c2.sh — Check DNS cache against known C2 domains

REFS_DIR="$(cd "$(dirname "$0")/../references" && pwd)"

echo "=== DNS Cache ==="
dns_cache=$(dscacheutil -cachedump -entries Host 2>/dev/null || true)
if [ -z "$dns_cache" ]; then
  echo "  DNS cache empty or unavailable (normal if recently flushed)"
fi

echo "=== IOC Domain Matching ==="
ioc_file=$(ls "$REFS_DIR"/ioc_domains_c2_*.txt 2>/dev/null | sort | tail -1 || true)
if [ -z "$ioc_file" ]; then
  echo "  SKIPPED: No IOC domain file found in references/"
  exit 0
fi

# Staleness check
ioc_date=$(basename "$ioc_file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "unknown")
if [ "$ioc_date" != "unknown" ]; then
  days_old=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$ioc_date" +%s 2>/dev/null || echo "0")) / 86400 ))
  echo "  IOC Domain List: $ioc_date ($days_old days ago)"
  if [ "$days_old" -ge 90 ]; then
    echo "  [CRITICAL] IOC domain list is severely outdated"
  elif [ "$days_old" -ge 30 ]; then
    echo "  [MEDIUM] IOC domain list is stale — update recommended"
  fi
fi

# Extract domains and check against DNS cache
if [ -n "$dns_cache" ]; then
  domains=$(grep -v "^#" "$ioc_file" | cut -d'|' -f1 | grep -v "^$" || true)
  match_count=0
  while read -r domain; do
    [ -z "$domain" ] && continue
    if echo "$dns_cache" | grep -qFi "$domain"; then
      echo "  [CRITICAL] C2 domain found in DNS cache: $domain"
      match_count=$((match_count + 1))
    fi
  done <<< "$domains"
  if [ "$match_count" -eq 0 ]; then
    echo "  No C2 domains found in DNS cache (good)"
  fi
else
  echo "  Skipping domain match — DNS cache unavailable"
fi
