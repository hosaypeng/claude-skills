#!/bin/bash
set -e

# scan_ssh_gpg_keys.sh — SSH/GPG key hygiene and tampering detection

echo "=== SSH Key Inventory ==="
ssh_dir="/Users/$USER/.ssh"
if [ -d "$ssh_dir" ]; then
  for keyfile in "$ssh_dir"/id_*; do
    [ -f "$keyfile" ] || continue
    # Skip public keys
    echo "$keyfile" | grep -q "\.pub$" && continue
    encrypted=$(grep -c "ENCRYPTED" "$keyfile" 2>/dev/null || echo "0")
    perms=$(stat -f "%Lp" "$keyfile" 2>/dev/null || echo "???")
    if [ "$encrypted" -eq 0 ]; then
      echo "  [HIGH] Unencrypted private key: $(basename "$keyfile") (perms: $perms)"
    else
      echo "  $(basename "$keyfile"): encrypted (perms: $perms)"
    fi
  done
else
  echo "  No ~/.ssh directory"
fi

echo "=== authorized_keys Check ==="
auth_keys="$ssh_dir/authorized_keys"
if [ -f "$auth_keys" ]; then
  mod_time=$(stat -f "%Sm" -t "%Y-%m-%d" "$auth_keys" 2>/dev/null || echo "unknown")
  key_count=$(wc -l < "$auth_keys" 2>/dev/null | tr -d ' ' || echo "0")
  days_since=$(( ($(date +%s) - $(stat -f "%m" "$auth_keys" 2>/dev/null || echo "0")) / 86400 ))
  echo "  $key_count keys, last modified: $mod_time ($days_since days ago)"
  if [ "$days_since" -lt 7 ]; then
    echo "  [LOW] authorized_keys modified recently — verify this was intentional"
  fi
else
  echo "  No authorized_keys file"
fi

echo "=== SSH Config Risks ==="
ssh_config="$ssh_dir/config"
if [ -f "$ssh_config" ]; then
  if grep -qi "ForwardAgent yes" "$ssh_config" 2>/dev/null; then
    echo "  [MEDIUM] ForwardAgent yes found — agent forwarding to untrusted hosts is risky"
    grep -n "ForwardAgent" "$ssh_config" 2>/dev/null | sed 's/^/    /'
  else
    echo "  No risky ForwardAgent settings"
  fi
else
  echo "  No SSH config file"
fi

echo "=== GPG Key Inventory ==="
if command -v gpg >/dev/null 2>&1; then
  gpg --list-secret-keys --keyid-format long 2>/dev/null | head -20 || echo "  No GPG secret keys"
  gnupg_perms=$(stat -f "%Lp" "/Users/$USER/.gnupg" 2>/dev/null || echo "N/A")
  if [ "$gnupg_perms" != "700" ] && [ "$gnupg_perms" != "N/A" ]; then
    echo "  [MEDIUM] ~/.gnupg permissions: $gnupg_perms (should be 700)"
  fi
else
  echo "  GPG not installed"
fi
