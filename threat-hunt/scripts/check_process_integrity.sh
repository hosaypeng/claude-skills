#!/bin/bash
set -e

# check_process_integrity.sh — Find unsigned and ad-hoc signed running processes

echo "=== Unsigned Running Processes ==="
ps -eo pid,comm 2>/dev/null | tail -n +2 | while read -r pid comm; do
  # Skip kernel and system processes
  [ "$comm" = "kernel_task" ] && continue
  [ "$comm" = "launchd" ] && continue
  # Resolve full path
  binary=$(ps -p "$pid" -o comm= 2>/dev/null || true)
  [ -z "$binary" ] && continue
  # Skip scripts, interpreters, and Homebrew binaries (ad-hoc signed by design)
  echo "$binary" | grep -qE "(python|ruby|node|perl|bash|zsh|sh)$" && continue
  echo "$binary" | grep -qE "^(/opt/homebrew/|/usr/local/Cellar/)" && continue
  # Check code signature
  result=$(codesign -v "$binary" 2>&1 || true)
  if echo "$result" | grep -q "not signed"; then
    echo "  [HIGH] PID $pid: $binary — NOT SIGNED"
  fi
done 2>/dev/null | head -20

echo "=== Ad-hoc Signed Processes (excluding Homebrew) ==="
ps -eo pid,comm 2>/dev/null | tail -n +2 | while read -r pid comm; do
  [ "$comm" = "kernel_task" ] && continue
  [ "$comm" = "launchd" ] && continue
  binary=$(ps -p "$pid" -o comm= 2>/dev/null || true)
  [ -z "$binary" ] && continue
  echo "$binary" | grep -qE "(python|ruby|node|perl|bash|zsh|sh)$" && continue
  # Skip Homebrew — ad-hoc signing is expected for formula-compiled binaries
  echo "$binary" | grep -qE "^(/opt/homebrew/|/usr/local/Cellar/)" && continue
  result=$(codesign -dv "$binary" 2>&1 || true)
  if echo "$result" | grep -q "Signature=adhoc"; then
    echo "  [HIGH] PID $pid: $binary — AD-HOC SIGNED"
  fi
done 2>/dev/null | head -20
