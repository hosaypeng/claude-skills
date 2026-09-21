#!/bin/bash
# scan_dns_c2.sh — Look for known C2 / install domains in local name-resolution traces
# Probe script: try each check, print what works, never abort on a failed sub-check.
source "$(dirname "$0")/_lib.sh"

echo "=== IOC Domain List ==="
ioc_file=$(latest_ioc ioc_domains_c2_)
if [ -z "$ioc_file" ]; then
  echo "  SKIPPED: No ioc_domains_c2_* file found in references/"
  exit 0
fi
ioc_staleness "$ioc_file"
domains=$(grep -v "^#" "$ioc_file" | cut -d'|' -f1 | grep -v "^$")
echo "  $(echo "$domains" | wc -l | tr -d ' ') domains loaded"

# Reports only whether an IOC domain appears in a source; never prints the source content.
match_domains() {
  local label="$1" haystack="$2" domain hits=0
  [ -z "$haystack" ] && return 0
  while read -r domain; do
    [ -z "$domain" ] && continue
    if echo "$haystack" | grep -qFi "$domain"; then
      echo "  [CRITICAL] IOC domain in $label: $domain"
      hits=$((hits + 1))
    fi
  done <<< "$domains"
  [ "$hits" -eq 0 ] && echo "  $label: no IOC domains (good)"
  return 0
}

echo "=== DNS Cache ==="
# `dscacheutil -cachedump` has printed "Unable to get details from the cache node" (to
# stdout, exit 0) since macOS 10.x. The old check grepped that error string for domains and
# reported "no C2 domains found" on every run. Treat it as unavailable.
dns_cache=$(dscacheutil -cachedump -entries Host 2>/dev/null | grep -v "Unable to get details")
if [ -n "$dns_cache" ]; then
  match_domains "DNS cache" "$dns_cache"
else
  echo "  SKIPPED: DNS cache dump is not available on this macOS (expected)"
fi

echo "=== /etc/hosts ==="
match_domains "/etc/hosts" "$(grep -v '^#' /etc/hosts 2>/dev/null)"

echo "=== Browser History (URL host match) ==="
# Mercenary spyware is delivered by a link; the install or impersonation domain lands in
# browser history even when nothing else persists. Chromium History DBs are plain SQLite
# owned by the user; each is copied (with its WAL) so a running browser's lock is not hit,
# and only the matched domain is ever printed. Safari's History.db is TCC-protected and is
# skipped without Full Disk Access.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/th_hist.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
hosts=""
read_ok=0
read_fail=0
for db in "$HOME/Library/Application Support"/*/*/History \
          "$HOME/Library/Application Support"/*/*/*/History; do
  [ -f "$db" ] || continue
  if ! cp "$db" "$tmp/History" 2>/dev/null; then read_fail=$((read_fail + 1)); continue; fi
  [ -f "$db-wal" ] && cp "$db-wal" "$tmp/History-wal" 2>/dev/null
  if urls=$(sqlite3 "file:$tmp/History?mode=ro" "SELECT DISTINCT url FROM urls" 2>/dev/null); then
    hosts="$hosts"$'\n'"$(echo "$urls" | sed -E 's#^[a-z]+://([^/:]+).*#\1#')"
    read_ok=$((read_ok + 1))
  else
    read_fail=$((read_fail + 1))
  fi
  rm -f "$tmp/History" "$tmp/History-wal"
done
safari="SKIPPED (History.db needs Full Disk Access)"
if [ -f "$HOME/Library/Safari/History.db" ] && cp "$HOME/Library/Safari/History.db" "$tmp/History" 2>/dev/null; then
  hosts="$hosts"$'\n'"$(sqlite3 "file:$tmp/History?mode=ro" \
    "SELECT DISTINCT url FROM history_items" 2>/dev/null | sed -E 's#^[a-z]+://([^/:]+).*#\1#')"
  safari="included"
fi
hosts=$(echo "$hosts" | sort -u | grep -v '^$')
if [ -n "$hosts" ]; then
  echo "  $(echo "$hosts" | wc -l | tr -d ' ') distinct hosts from $read_ok Chromium profile(s) read, $read_fail unreadable; Safari: $safari"
  [ "$read_fail" -gt 0 ] && echo "  [INFO] $read_fail profile(s) could not be read - their history was not checked"
  match_domains "browser history" "$hosts"
else
  echo "  SKIPPED: no readable browser history found"
fi

exit 0
