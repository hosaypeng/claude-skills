#!/bin/bash
set -e

echo "=== Authentication & Access Control ==="

echo "=== Sudo Configuration ==="
sudo -n true 2>/dev/null && echo "Passwordless sudo enabled" || echo "Sudo requires password"

echo "=== SSH Configuration ==="
echo "SSH hosts configured: $(grep -c "^Host " ~/.ssh/config 2>/dev/null || echo 0)"
echo "Password auth disabled: $(grep -ci "PasswordAuthentication no" ~/.ssh/config 2>/dev/null && echo "Yes" || echo "Check manually")

echo "=== SSH Public Keys ==="
ls -la ~/.ssh/*.pub 2>/dev/null || echo "No public keys found"

echo "=== Unencrypted Private Keys ==="
UNENCRYPTED=$(grep -rL "ENCRYPTED" ~/.ssh/id_* 2>/dev/null | grep -v ".pub" | wc -l | tr -d ' ')
echo "Unencrypted private keys: $UNENCRYPTED"

echo "=== Root Account Status ==="
dscl . -read /Users/root AuthenticationAuthority 2>/dev/null | grep -q "DisabledUser" && echo "Root disabled" || echo "Root enabled"

echo "=== Auto-login Status ==="
defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo "Auto-login disabled"
