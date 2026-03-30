#!/bin/bash
set -e

# scan_clipboard_exfil.sh — Check clipboard for secrets and clipboard manager exposure
# SAFETY: Never prints actual secret values

echo "=== Current Clipboard Analysis ==="
clipboard=$(pbpaste 2>/dev/null || true)
if [ -n "$clipboard" ]; then
  # Check for secret patterns without printing the actual value
  if echo "$clipboard" | grep -qE '(sk-[a-zA-Z0-9]{20,}|sk_live_|AKIA[A-Z0-9]{16})'; then
    echo "  [MEDIUM] Clipboard contains potential API key pattern"
  elif echo "$clipboard" | grep -q -- '-----BEGIN.*PRIVATE KEY-----'; then
    echo "  [CRITICAL] Clipboard contains a private key"
  elif echo "$clipboard" | grep -qE '^([a-z]+ ){11,}[a-z]+$'; then
    echo "  [CRITICAL] Clipboard contains potential seed phrase"
  elif echo "$clipboard" | grep -qE '0x[a-fA-F0-9]{64}'; then
    echo "  [CRITICAL] Clipboard contains potential crypto private key"
  elif echo "$clipboard" | grep -qE '(ghp_|gho_|xox[bpsar]-)'; then
    echo "  [MEDIUM] Clipboard contains potential token"
  else
    echo "  No secret patterns detected in clipboard"
  fi
else
  echo "  Clipboard is empty"
fi

echo "=== Clipboard Manager Processes ==="
clipboard_procs=$(ps aux 2>/dev/null | grep -iE "(CopyQ|Maccy|Flycut|Jumpcut|Paste\.app|ClipMenu|Clipboard Manager)" | grep -v "grep" || true)
if [ -n "$clipboard_procs" ]; then
  echo "  Running clipboard managers:"
  echo "$clipboard_procs" | awk '{print "  " $11}' | head -5
  echo "  [INFO] Clipboard managers may store sensitive data in plaintext"
else
  echo "  No clipboard manager processes detected"
fi

echo "=== Clipboard Manager Data Files ==="
for clip_dir in "/Users/$USER/Library/Application Support/CopyQ" "/Users/$USER/Library/Application Support/Maccy" "/Users/$USER/Library/Containers/com.sindresorhus.Paste/Data"; do
  if [ -d "$clip_dir" ]; then
    echo "  [INFO] Clipboard history at: $clip_dir"
    echo "    Consider periodically clearing clipboard history"
  fi
done
