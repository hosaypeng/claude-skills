#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

# scan_clipboard_exfil.sh — Check clipboard for secrets and clipboard manager exposure
# SAFETY: Never prints actual secret values

# BIP39 shape: exactly 12/15/18/21/24 words of 3-8 lowercase letters (same as scan_crypto_wallets.sh).
W='[a-z]{3,8}'
SEED_PATTERN="^($W ){11}$W\$|^($W ){14}$W\$|^($W ){17}$W\$|^($W ){20}$W\$|^($W ){23}$W\$"

echo "=== Current Clipboard Analysis ==="
clipboard=$(pbpaste 2>/dev/null || true)
if [ -n "$clipboard" ]; then
  # Check for secret patterns without printing the actual value
  if echo "$clipboard" | grep -qE '(sk-[a-zA-Z0-9]{20,}|sk_live_|AKIA[A-Z0-9]{16})'; then
    echo "  [MEDIUM] Clipboard contains potential API key pattern"
  elif echo "$clipboard" | grep -q -- '-----BEGIN.*PRIVATE KEY-----'; then
    echo "  [CRITICAL] Clipboard contains a private key"
  elif echo "$clipboard" | grep -qE "$SEED_PATTERN"; then
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
clip_found=0
for clip_dir in "$HOME/Library/Application Support/CopyQ" "$HOME/Library/Application Support/Maccy" "$HOME/Library/Containers/com.sindresorhus.Paste/Data" "$HOME/Library/Application Support/com.raycast.macos"; do
  if [ -d "$clip_dir" ]; then
    echo "  [INFO] Clipboard history at: $clip_dir"
    echo "    Consider periodically clearing clipboard history"
    clip_found=1
  fi
done
[ "$clip_found" -eq 0 ] && echo "  None"

exit 0
