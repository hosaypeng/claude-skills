#!/bin/bash
# sweep_persistence.sh — Enumerate persistence mechanisms with code signature verification
# Probe script: try each check, print what works, never abort on a failed sub-check.
source "$(dirname "$0")/_lib.sh"

# A plist listing alone says nothing. What matters is whether the target it launches is
# validly signed (Mach-O) or rewritable by another account (script) - see sig_status.
# For `/bin/bash script.sh` style agents the thing to classify is the script, not the
# Apple-signed interpreter - see resolve_plist_target in _lib.sh.
verify_plists() {
  local label="$1" dir="$2" found=0 plist argv0 target note name
  echo "=== $label ==="
  for plist in "$dir"/*.plist; do
    [ -f "$plist" ] || continue
    found=1
    name=$(basename "$plist")
    IFS='|' read -r argv0 target note <<< "$(resolve_plist_target "$plist")"
    if [ -z "$argv0" ]; then
      # Empty <dict/> tombstones (Google Keystone) and unreadable plists land here. Not a
      # confirmed orphan: an obfuscated plist would look the same.
      echo "  [MEDIUM] $name — $note"
    elif [ -n "$note" ]; then
      case "$note" in
        "python module"*) echo "  $name -> $argv0 — $note" ;;
        *)                echo "  [MEDIUM] $name -> $argv0 — $note" ;;
      esac
    elif [ -f "$target" ]; then
      [ "$target" != "$argv0" ] && target="$argv0 $target"
      echo "  $name -> $target — $(sig_status "${target##* }")"
    else
      # An agent whose target is gone is an orphan: harmless, but worth removing so a
      # future file at that path is not silently executed at login.
      echo "  [LOW] $name -> $target [TARGET NOT FOUND - orphaned agent]"
    fi
  done
  [ "$found" -eq 0 ] && echo "  None"
  return 0
}

verify_plists "User LaunchAgents" "$HOME/Library/LaunchAgents"
verify_plists "System LaunchAgents" /Library/LaunchAgents
verify_plists "System LaunchDaemons" /Library/LaunchDaemons

echo "=== Recently Modified Persistence (30 days) ==="
recent=$(find "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons \
  -type f -mtime -30 2>/dev/null)
if [ -n "$recent" ]; then
  echo "$recent" | sed 's/^/  /'
else
  echo "  None"
fi

echo "=== Authorization Plugins ==="
# A non-Apple authorization plugin runs inside the login flow and sees credentials.
if [ -d /Library/Security/SecurityAgentPlugins ]; then
  found=0
  for bundle in /Library/Security/SecurityAgentPlugins/*.bundle; do
    [ -d "$bundle" ] || continue
    found=1
    status=$(sig_status "$bundle")
    case "$status" in
      *"Apple"*) echo "  $(basename "$bundle") — $status" ;;
      *)         echo "  [CRITICAL] $(basename "$bundle") — non-Apple or unsigned: $status" ;;
    esac
  done
  [ "$found" -eq 0 ] && echo "  Directory present but empty (normal)"
else
  echo "  Directory not found (normal)"
fi

echo "=== Login Items ==="
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null \
  || echo "  Could not enumerate login items (Automation permission for System Events not granted)"

echo "=== Cron Jobs ==="
crontab -l 2>/dev/null || echo "  No user crontab"

echo "=== Periodic Scripts ==="
for period in daily weekly monthly; do
  echo "  /etc/periodic/$period/: $(ls /etc/periodic/"$period"/ 2>/dev/null | tr '\n' ' ')"
done

echo "=== Shell Startup Files ==="
# Stealers commonly append a remote-fetch-and-execute line, or an encoded payload, to a
# shell rc file. The allowlist keeps normal version-manager lines from firing.
SUSPECT_PATTERN='(curl |wget |python.*-c |base64 |eval |nc |ncat |/dev/tcp)'
ALLOWLIST='(brew shellenv|nvm\.sh|conda|pyenv|rbenv|sdkman|cargo env|rustup|direnv)'
for rcfile in .bashrc .zshrc .bash_profile .zprofile .profile; do
  filepath="$HOME/$rcfile"
  [ -f "$filepath" ] || continue
  mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$filepath" 2>/dev/null || echo "unknown")
  suspicious=$(grep -nE "$SUSPECT_PATTERN" "$filepath" 2>/dev/null | grep -vE "$ALLOWLIST" | head -5)
  if [ -n "$suspicious" ]; then
    echo "  [MEDIUM] $rcfile (modified: $mod) — suspicious patterns:"
    echo "$suspicious" | sed 's/^/      /'
  else
    echo "  $rcfile (modified: $mod) — clean"
  fi
done

exit 0
