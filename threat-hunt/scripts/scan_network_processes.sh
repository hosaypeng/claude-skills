#!/bin/bash
# scan_network_processes.sh — Map network connections to processes, verify signatures
# Probe script: try each check, print what works, never abort on a failed sub-check.
source "$(dirname "$0")/_lib.sh"

INTERPRETERS='(^|/)(python[0-9.]*|ruby|node|perl|bash|zsh|sh|fish|dash)$'

# lsof once; every section below reads the same snapshot instead of re-running it per PID.
established=$(lsof -i -P -n 2>/dev/null | grep ESTABLISHED)

echo "=== Process-to-Connection Map ==="
if [ -n "$established" ]; then
  echo "$established" | awk '{print $1, $2, $9}' | sort -u | head -30 | while read -r name pid dest; do
    binary=$(ps -p "$pid" -o comm= 2>/dev/null)
    echo "  PID $pid ($name): ${binary:-UNKNOWN} -> $dest"
  done
else
  echo "  No established connections"
fi

echo "=== Unsigned Processes with Network Activity ==="
found=0
unresolved=""
while read -r pid; do
  [ -z "$pid" ] && continue
  binary=$(ps -p "$pid" -o comm= 2>/dev/null)
  # A PID that exited between lsof and ps is not a finding.
  [ -z "$binary" ] && continue
  echo "$binary" | grep -qE "$INTERPRETERS" && continue
  # A rewritten process title gives a bare name; resolve it via the txt mapping.
  if [ ! -f "$binary" ]; then
    binary=$(lsof -p "$pid" -a -d txt -Fn 2>/dev/null | sed -n '/^n\//{s/^n//p;q;}')
  fi
  dest=$(echo "$established" | awk -v p="$pid" '$2 == p {print $9; exit}')
  if [ -z "$binary" ] || [ ! -f "$binary" ]; then
    unresolved="$unresolved    PID $pid -> $dest"$'\n'
    continue
  fi
  if codesign -dv "$binary" 2>&1 | grep -q "not signed"; then
    echo "  [HIGH] PID $pid: $binary (unsigned) -> $dest"
    found=1
  fi
done < <(echo "$established" | awk '{print $2}' | sort -u)
[ "$found" -eq 0 ] && echo "  None found (good)"
if [ -n "$unresolved" ]; then
  echo "  [INFO] Network-active process(es) not resolvable to a binary (not verified):"
  printf '%s' "$unresolved"
fi

echo "=== Background Processes with Network (no terminal) ==="
# Daemons with live connections, with the remote owner annotated for triage. An unfamiliar
# name here talking to an unknown owner is the line to chase.
found=0
while read -r pid tty comm; do
  # `read` keeps the remainder in $comm, so app paths with spaces survive (awk split them).
  [ "$tty" = "??" ] || continue
  dest=$(echo "$established" | awk -v p="$pid" '$2 == p {print $9; exit}')
  [ -z "$dest" ] && continue
  ip=$(echo "$dest" | sed 's/.*->//' | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
  echo "  PID $pid: $comm -> $dest ${ip:+[$(ip_owner "$ip")]}"
  found=1
done < <(ps -eo pid=,tty=,comm= 2>/dev/null)
[ "$found" -eq 0 ] && echo "  None"

exit 0
