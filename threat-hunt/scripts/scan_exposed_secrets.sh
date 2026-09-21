#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

# scan_exposed_secrets.sh — Find plaintext secrets on disk
# SAFETY: Never prints actual secret values

hits_tmp=$(mktemp "${TMPDIR:-/tmp}/th_secrets.XXXXXX")
trap 'rm -f "$hits_tmp"' EXIT
report_hits() { if [ -s "$hits_tmp" ]; then cat "$hits_tmp"; else echo "  None found"; fi; return 0; }

echo "=== .env Files ==="
# Search specific subdirectories to avoid duplicate results from overlapping paths
for search_dir in "$HOME/Code" "$HOME/Desktop" "$HOME/Downloads" "$HOME/.hermes" "$HOME/.vscode"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 4 -name ".env*" -type f 2>/dev/null \
    | grep -vE "(node_modules|\.git|\.venv|__pycache__)" \
    | grep -vE '\.(example|sample|template|test)$' \
    | while read -r envfile; do
    perms=$(stat -f "%Lp" "$envfile" 2>/dev/null || echo "???")
    has_secrets=$(grep -cE '(sk-|sk_live_|AKIA[A-Z0-9]{16}|ghp_|gho_|xox[bpsar]-|Bearer |PRIVATE.KEY|password\s*=|secret\s*=|token\s*=)' "$envfile" 2>/dev/null)
    [[ "$has_secrets" =~ ^[0-9]+$ ]] || has_secrets=0
    if [ "$has_secrets" -gt 0 ]; then
      echo "  $envfile (perms: $perms, secret patterns: $has_secrets)"
      if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
        echo "    [CRITICAL] World/group-readable file with secrets"
      else
        echo "    [MEDIUM] Secrets in .env file (restricted permissions)"
      fi
    fi
  done
done > "$hits_tmp"
report_hits

echo "=== Cloud Credential Files ==="
for credfile in "$HOME/.aws/credentials" "$HOME/.config/gcloud/application_default_credentials.json" "$HOME/.kube/config"; do
  if [ -f "$credfile" ]; then
    perms=$(stat -f "%Lp" "$credfile" 2>/dev/null || echo "???")
    echo "  $credfile (perms: $perms)"
    if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
      echo "    [HIGH] Cloud credentials with loose permissions"
    fi
  fi
done > "$hits_tmp"
report_hits

echo "=== Credential Helper Files ==="
for credfile in "$HOME/.netrc" "$HOME/.npmrc" "$HOME/.pypirc" "$HOME/.docker/config.json"; do
  if [ -f "$credfile" ]; then
    has_auth=$(grep -ciE '(password|_auth|token|auth_token)' "$credfile" 2>/dev/null)
    [[ "$has_auth" =~ ^[0-9]+$ ]] || has_auth=0
    if [ "$has_auth" -gt 0 ]; then
      perms=$(stat -f "%Lp" "$credfile" 2>/dev/null || echo "???")
      echo "  $credfile (perms: $perms, auth entries: $has_auth)"
    fi
  fi
done > "$hits_tmp"
report_hits

echo "=== Private Key Files in Common Locations ==="
# ~/Documents holds the Obsidian vault; a vault note named *.key is not a private key.
for search_dir in "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents"; do
  [ -d "$search_dir" ] || continue
  find "$search_dir" -maxdepth 3 -type f \( -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "*.pfx" \) 2>/dev/null | while read -r keyfile; do
    if grep -q "PRIVATE KEY" "$keyfile" 2>/dev/null || file -b "$keyfile" 2>/dev/null | grep -qiE "PKCS|certificate|data"; then
      echo "  [HIGH] Private key file: $keyfile"
    else
      echo "  [LOW] Key-named file with no key material: $keyfile"
    fi
  done
done > "$hits_tmp"
report_hits

exit 0
