#!/bin/bash
set -e

echo "=== Authentication & Access Control ==="

echo "--- Sudo Configuration ---"
sudo -n true 2>/dev/null && echo "Passwordless sudo enabled" || echo "Sudo requires password"

echo "--- SSH Configuration ---"
cat ~/.ssh/config 2>/dev/null | grep -E "Host|HostName|User" | head -10 || echo "No SSH config"

echo "--- SSH Public Keys ---"
ls -la ~/.ssh/*.pub 2>/dev/null || echo "No public keys found"

echo "--- Unencrypted Private Keys ---"
grep -L "ENCRYPTED" ~/.ssh/id_* 2>/dev/null | grep -v ".pub" || echo "All keys encrypted or none found"

echo "--- Root Account Status ---"
dscl . -read /Users/root AuthenticationAuthority 2>/dev/null | grep -q "DisabledUser" && echo "Root disabled" || echo "Root enabled"

echo "--- Auto-login Status ---"
defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo "Auto-login disabled"
