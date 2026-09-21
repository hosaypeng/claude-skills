#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

# scan_crypto_wallets.sh — Detect crypto wallet files and exposed key material
# SAFETY: Never prints key material

hits_tmp=$(mktemp "${TMPDIR:-/tmp}/th_wallet.XXXXXX")
trap 'rm -f "$hits_tmp"' EXIT

echo "=== Known Wallet Application Data ==="
app_found=0
wallet_dirs=(
  "$HOME/Library/Application Support/Exodus"
  "$HOME/Library/Application Support/Electrum"
  "$HOME/Library/Application Support/Ledger Live"
  "$HOME/Library/Application Support/com.metamask"
  "$HOME/Library/Application Support/Phantom"
  "$HOME/Library/Application Support/Bitcoin"
  "$HOME/Library/Application Support/Ethereum"
)
for wdir in "${wallet_dirs[@]}"; do
  if [ -d "$wdir" ]; then
    size=$(du -sh "$wdir" 2>/dev/null | awk '{print $1}')
    echo "  Found: $wdir (${size:-?})"
    app_found=1
  fi
done
[ "$app_found" -eq 0 ] && echo "  None"

echo "=== Wallet Files in Common Locations ==="
for search_dir in "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 3 -type f \( -name "wallet.dat" -o -name "*.keystore" -o -name "keystore.json" -o -name "UTC--*" \) 2>/dev/null | while read -r wfile; do
    echo "  [CRITICAL] Wallet file in exposed location: $wfile"
  done
done > "$hits_tmp"
if [ -s "$hits_tmp" ]; then cat "$hits_tmp"; else echo "  None found"; fi

echo "=== Wallet Browser Extensions ==="
# Extension wallets keep encrypted vaults under the profile's Local Extension Settings; the
# stealer target is that directory plus the clipboard when the vault is unlocked.
AS="$HOME/Library/Application Support"
WALLET_EXT_IDS="nkbihfbeogaeaoehlefnkodbefgpgknn:MetaMask bfnaelmomeimhlpmgjnjophhpkkoljpa:Phantom acmacodkjbdgmoleebolmdjonilkdbch:Rabby dmkamcknogkgcdfhhbddcghachkejeap:Keplr fcfcfllfndlomdhbehjjcoimbgofdncg:Leap hnfanknocfeofbddgcijnmhnfnkdnaad:Coinbase-Wallet fhbohimaelbohpjbbldcngcnapndodjp:Binance-Wallet"
wallet_ext_found=0
for dir in "$AS/Google/Chrome" "$AS/BraveSoftware/Brave-Browser" "$AS/net.imput.helium" "$AS/Arc/User Data" "$AS/Microsoft Edge"; do
  [ -d "$dir" ] || continue
  for entry in $WALLET_EXT_IDS; do
    ext_id="${entry%%:*}"; ext_name="${entry#*:}"
    profiles=$(find "$dir" -maxdepth 3 -type d -path "*/Local Extension Settings/$ext_id" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$profiles" -gt 0 ]; then
      echo "  $(basename "$dir"): $ext_name in $profiles profile(s)"
      wallet_ext_found=1
    fi
  done
done
[ "$wallet_ext_found" -eq 0 ] && echo "  None"

echo "=== Seed Phrase Detection ==="
W='[a-z]{3,8}'
SEED_PATTERN="^($W ){11}$W\$|^($W ){14}$W\$|^($W ){17}$W\$|^($W ){20}$W\$|^($W ){23}$W\$"
# Check common text files for potential BIP39 mnemonic patterns (12+ lowercase words on one line)
for search_dir in "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents" "$HOME/Notes"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 3 -type f \( -name "*.txt" -o -name "*.md" -o -name "*.note" \) 2>/dev/null | while read -r textfile; do
    # BIP39 shape: exactly 12/15/18/21/24 lowercase words of 3-8 letters, nothing else on
    # the line. "12 or more words" matched ordinary prose in vault notes.
    if grep -qE "$SEED_PATTERN" "$textfile" 2>/dev/null; then
      echo "  [CRITICAL] Potential seed phrase in: $textfile"
    fi
  done
done > "$hits_tmp"
if [ -s "$hits_tmp" ]; then cat "$hits_tmp"; else echo "  None found"; fi

echo "=== Private Key Hex Patterns ==="
for search_dir in "$HOME/Desktop" "$HOME/Downloads"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 2 -type f \( -name "*.txt" -o -name "*.json" -o -name "*.csv" \) 2>/dev/null | while read -r f; do
    if grep -qE '0x[a-fA-F0-9]{64}' "$f" 2>/dev/null; then
      echo "  [CRITICAL] Potential private key hex in: $f"
    fi
  done
done > "$hits_tmp"
if [ -s "$hits_tmp" ]; then cat "$hits_tmp"; else echo "  None found"; fi

exit 0
