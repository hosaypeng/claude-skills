#!/bin/bash
set -e

# scan_network_processes.sh — Map network connections to processes, verify signatures

echo "=== Process-to-Connection Map ==="
lsof -i -P -n 2>/dev/null | grep ESTABLISHED | awk '{print $1, $2, $9}' | sort -u | while read -r name pid dest; do
  binary=$(ps -p "$pid" -o comm= 2>/dev/null || echo "UNKNOWN")
  echo "  PID $pid ($name): $binary -> $dest"
done | head -30 || echo "  No established connections"

echo "=== Unsigned Processes with Network Activity ==="
lsof -i -P -n 2>/dev/null | grep ESTABLISHED | awk '{print $2}' | sort -u | while read -r pid; do
  binary=$(ps -p "$pid" -o comm= 2>/dev/null || continue)
  [ -z "$binary" ] && continue
  echo "$binary" | grep -qE "(python|ruby|node|perl|bash|zsh|sh)$" && continue
  result=$(codesign -v "$binary" 2>&1 || true)
  if echo "$result" | grep -q "not signed"; then
    dest=$(lsof -i -P -n -p "$pid" 2>/dev/null | grep ESTABLISHED | awk '{print $9}' | head -1 || true)
    echo "  [HIGH] PID $pid: $binary (unsigned) -> $dest"
  fi
done 2>/dev/null | head -20

echo "=== Background Processes with Network (no terminal) ==="
ps -eo pid,tty,comm 2>/dev/null | grep "??" | awk '{print $1, $3}' | while read -r pid comm; do
  has_net=$(lsof -i -P -n -p "$pid" 2>/dev/null | grep ESTABLISHED | head -1 || true)
  if [ -n "$has_net" ]; then
    echo "  PID $pid: $comm -> $(echo "$has_net" | awk '{print $9}')"
  fi
done 2>/dev/null | head -20 || true
