#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Authentication & Access Control ==="

echo "=== Sudo Configuration ==="
if sudo -n true 2>/dev/null; then
  echo "[CRITICAL] Passwordless sudo enabled"
else
  echo "Sudo requires password"
fi

echo "=== Remote Login (SSH server) ==="
# systemsetup -getremotelogin requires admin and prints an error instead of a value,
# which would read as "off" and hide real exposure. A listening port 22 needs no privilege.
if lsof -iTCP:22 -sTCP:LISTEN -P -n >/dev/null 2>&1; then
  remote_login="On"
  echo "[MEDIUM] Remote Login: On (sshd listening on port 22)"
else
  remote_login="Off"
  echo "Remote Login: Off (nothing listening on port 22)"
fi

# PasswordAuthentication is valid in both ssh_config(5) and sshd_config(5), but only the
# server setting affects this machine's exposure. macOS 13+ ships an Include line, so the
# drop-in directory has to be read too or an override there is missed.
if [ "$remote_login" = "On" ]; then
  sshd_files="/etc/ssh/sshd_config"
  for extra in /etc/ssh/sshd_config.d/*; do
    [ -f "$extra" ] && sshd_files="$sshd_files $extra"
  done
  # Last matching directive across main config + drop-ins wins for reporting purposes.
  pwauth=$(grep -hiE '^[[:space:]]*PasswordAuthentication[[:space:]]+' $sshd_files 2>/dev/null | tail -1)
  if [ -z "$pwauth" ]; then
    echo "[HIGH] Remote Login is ON and PasswordAuthentication is unset (sshd default: yes)"
  elif echo "$pwauth" | grep -qi "no"; then
    echo "Password auth disabled: Yes ($pwauth)"
  else
    echo "[HIGH] Remote Login is ON with password auth permitted ($pwauth)"
  fi
else
  echo "Password auth: not applicable (Remote Login off)"
fi

echo "=== SSH Client Config ==="
ssh_hosts=$(grep -c "^Host " ~/.ssh/config 2>/dev/null)
echo "SSH hosts configured: ${ssh_hosts:-0}"

echo "=== SSH Public Keys ==="
ls -la ~/.ssh/*.pub 2>/dev/null || echo "No public keys found"

echo "=== Unencrypted Private Keys ==="
unencrypted=0
for key in ~/.ssh/id_*; do
  [ -f "$key" ] || continue
  case "$key" in *.pub) continue ;; esac
  # OpenSSH-format keys never contain "ENCRYPTED"; only an empty-passphrase load proves it.
  if ssh-keygen -y -P '' -f "$key" >/dev/null 2>&1; then
    echo "[HIGH] Unencrypted private key: $key"
    unencrypted=$((unencrypted + 1))
  fi
done
echo "Unencrypted private keys: $unencrypted"

echo "=== Root Account Status ==="
# Root is enabled only if it has a real password hash. On a default macOS install the
# AuthenticationAuthority key is absent entirely and Password is "*", both meaning disabled.
root_pw=$(dscl . -read /Users/root Password 2>/dev/null | awk '{print $2}')
root_auth=$(dscl . -read /Users/root AuthenticationAuthority 2>/dev/null)
if [ "$root_pw" = "*" ] || ! echo "$root_auth" | grep -q "ShadowHash"; then
  echo "Root disabled"
else
  echo "[HIGH] Root enabled"
fi

echo "=== Auto-login Status ==="
autologin=$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null)
if [ -n "$autologin" ]; then
  echo "[MEDIUM] Auto-login enabled for: $autologin"
else
  echo "Auto-login disabled"
fi

echo "=== Screen Lock ==="
askpw=$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo 0)
askdelay=$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo unknown)
if [ "$askpw" = "1" ]; then
  echo "Screen lock: enabled (delay: ${askdelay}s)"
  case "$askdelay" in
    ''|*[!0-9]*) : ;;
    *) [ "$askdelay" -gt 5 ] && echo "[LOW] Lock delay > 5 sec" ;;
  esac
else
  echo "[MEDIUM] Screen lock disabled"
fi

exit 0
