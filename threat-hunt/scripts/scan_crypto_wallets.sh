#!/bin/bash
set -e

# scan_crypto_wallets.sh — Detect crypto wallet files and exposed key material
# SAFETY: Never prints key material

echo "=== Known Wallet Application Data ==="
wallet_dirs=(
  "/Users/$USER/Library/Application Support/Exodus"
  "/Users/$USER/Library/Application Support/Electrum"
  "/Users/$USER/Library/Application Support/Ledger Live"
  "/Users/$USER/Library/Application Support/com.metamask"
  "/Users/$USER/Library/Application Support/Phantom"
  "/Users/$USER/Library/Application Support/Bitcoin"
  "/Users/$USER/Library/Application Support/Ethereum"
)
for wdir in "${wallet_dirs[@]}"; do
  if [ -d "$wdir" ]; then
    size=$(du -sh "$wdir" 2>/dev/null | awk '{print $1}' || echo "?")
    echo "  Found: $wdir ($size)"
  fi
done

echo "=== Wallet Files in Common Locations ==="
for search_dir in "/Users/$USER/Desktop" "/Users/$USER/Downloads" "/Users/$USER/Documents"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 3 -type f \( -name "wallet.dat" -o -name "*.keystore" -o -name "keystore.json" -o -name "UTC--*" \) 2>/dev/null | while read -r wfile; do
    echo "  [CRITICAL] Wallet file in exposed location: $wfile"
  done
done

echo "=== Seed Phrase Detection ==="
# Check common text files for potential BIP39 mnemonic patterns (12+ lowercase words on one line)
for search_dir in "/Users/$USER/Desktop" "/Users/$USER/Downloads" "/Users/$USER/Documents" "/Users/$USER/Notes"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 3 -type f \( -name "*.txt" -o -name "*.md" -o -name "*.note" \) 2>/dev/null | while read -r textfile; do
    # Look for lines with 12+ lowercase words (potential seed phrase)
    if grep -qE '^([a-z]+ ){11,}[a-z]+$' "$textfile" 2>/dev/null; then
      echo "  [CRITICAL] Potential seed phrase in: $textfile"
    fi
  done
done

echo "=== Private Key Hex Patterns ==="
for search_dir in "/Users/$USER/Desktop" "/Users/$USER/Downloads"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 2 -type f \( -name "*.txt" -o -name "*.json" -o -name "*.csv" \) 2>/dev/null | while read -r f; do
    if grep -qE '0x[a-fA-F0-9]{64}' "$f" 2>/dev/null; then
      echo "  [CRITICAL] Potential private key hex in: $f"
    fi
  done
done
