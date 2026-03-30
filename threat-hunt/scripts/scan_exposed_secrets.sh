#!/bin/bash
set -e

# scan_exposed_secrets.sh — Find plaintext secrets on disk
# SAFETY: Never prints actual secret values

echo "=== .env Files ==="
for search_dir in "/Users/$USER" "/Users/$USER/Code" "/Users/$USER/Desktop" "/Users/$USER/Downloads"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 4 -name ".env*" -type f 2>/dev/null | grep -vE "(node_modules|\.git|\.venv|__pycache__)" | while read -r envfile; do
    perms=$(stat -f "%Lp" "$envfile" 2>/dev/null || echo "???")
    has_secrets=$(grep -cE '(sk-|sk_live_|AKIA[A-Z0-9]{16}|ghp_|gho_|xox[bpsar]-|Bearer |PRIVATE.KEY|password\s*=|secret\s*=|token\s*=)' "$envfile" 2>/dev/null | tr -d '[:space:]' || echo "0")
    has_secrets="${has_secrets:-0}"
    if [ "$has_secrets" -gt 0 ] 2>/dev/null; then
      echo "  $envfile (perms: $perms, secret patterns: $has_secrets)"
      if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
        echo "    [CRITICAL] World/group-readable file with secrets"
      else
        echo "    [MEDIUM] Secrets in .env file (restricted permissions)"
      fi
    fi
  done
done

echo "=== Cloud Credential Files ==="
for credfile in "/Users/$USER/.aws/credentials" "/Users/$USER/.config/gcloud/application_default_credentials.json" "/Users/$USER/.kube/config"; do
  if [ -f "$credfile" ]; then
    perms=$(stat -f "%Lp" "$credfile" 2>/dev/null || echo "???")
    echo "  $credfile (perms: $perms)"
    if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
      echo "    [HIGH] Cloud credentials with loose permissions"
    fi
  fi
done

echo "=== Credential Helper Files ==="
for credfile in "/Users/$USER/.netrc" "/Users/$USER/.npmrc" "/Users/$USER/.pypirc" "/Users/$USER/.docker/config.json"; do
  if [ -f "$credfile" ]; then
    has_auth=$(grep -ciE '(password|_auth|token|auth_token)' "$credfile" 2>/dev/null | head -1 || echo "0")
    if [ "${has_auth:-0}" -gt 0 ] 2>/dev/null; then
      perms=$(stat -f "%Lp" "$credfile" 2>/dev/null || echo "???")
      echo "  $credfile (perms: $perms, auth entries: $has_auth)"
    fi
  fi
done

echo "=== Private Key Files in Common Locations ==="
for search_dir in "/Users/$USER/Desktop" "/Users/$USER/Downloads" "/Users/$USER/Documents"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 3 -type f \( -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "*.pfx" \) 2>/dev/null | while read -r keyfile; do
    echo "  [HIGH] Private key file: $keyfile"
  done
done
