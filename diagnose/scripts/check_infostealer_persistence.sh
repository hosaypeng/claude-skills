#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Infostealer Detection: Persistence Mechanism Audit ==="

# A plist listing alone says nothing. What matters is whether the binary it launches
# is validly signed, and by whom.
verify_plists() {
  local label="$1" dir="$2" found=0
  echo "=== $label ==="
  for plist in "$dir"/*.plist; do
    [ -f "$plist" ] || continue
    found=1
    binary=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null) \
      || binary=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null) \
      || binary="UNKNOWN"
    if [ "$binary" != "UNKNOWN" ] && [ -f "$binary" ]; then
      # Shell and script interpreters are never code-signed, so running codesign on them
      # would flag every legitimate helper script. For those the real risk is whether a
      # non-root user can rewrite the file that a LaunchAgent executes.
      if file -b "$binary" 2>/dev/null | grep -q "Mach-O"; then
        if codesign -v "$binary" >/dev/null 2>&1; then
          # Authority only appears at --verbose=2; plain -dv omits it.
          authority=$(codesign -dv --verbose=2 "$binary" 2>&1 | sed -n 's/^Authority=//p' | head -1)
          status="VALID - ${authority:-no authority (ad-hoc signature)}"
        else
          status="[HIGH] UNSIGNED/INVALID Mach-O"
        fi
      else
        kind=$(file -b "$binary" 2>/dev/null | cut -c1-40)
        # Owner-writable is normal for a user's own automation. The real risk is a target a
        # *different* account can rewrite, so score on the group/other write bits, not on -w.
        perm=$(stat -f "%OLp" "$binary" 2>/dev/null)
        gw=$(printf "%s" "$perm" | cut -c2)
        ow=$(printf "%s" "$perm" | cut -c3)
        case "$gw$ow" in
          *[2367]*) status="[HIGH] group/world-writable target, mode $perm ($kind)" ;;
          *)        status="script, owner-writable only, mode $perm ($kind)" ;;
        esac
      fi
      echo "  $(basename "$plist") -> $binary — $status"
    else
      echo "  $(basename "$plist") -> $binary [BINARY NOT FOUND]"
    fi
  done
  [ "$found" -eq 0 ] && echo "  None"
  return 0
}

verify_plists "User LaunchAgents" "$HOME/Library/LaunchAgents"
verify_plists "System LaunchAgents" /Library/LaunchAgents
verify_plists "System LaunchDaemons" /Library/LaunchDaemons

echo "=== Recently Modified Persistence (30 days) ==="
find "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons \
  -type f -mtime -30 2>/dev/null || echo "  None"

echo "=== Shell Startup Files ==="
# Stealers commonly append a remote-fetch-and-execute line, or an encoded payload,
# to a shell rc file. The allowlist keeps normal version-manager lines from firing.
SUSPECT_PATTERN='(curl |wget |python.*-c |base64 |eval |nc |ncat |/dev/tcp)'
ALLOWLIST='(brew shellenv|nvm\.sh|conda|pyenv|rbenv|sdkman|cargo env|rustup|direnv)'
for rcfile in .bashrc .zshrc .bash_profile .zprofile .profile; do
  filepath="$HOME/$rcfile"
  [ -f "$filepath" ] || continue
  mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$filepath" 2>/dev/null || echo unknown)
  suspicious=$(grep -nE "$SUSPECT_PATTERN" "$filepath" 2>/dev/null | grep -vE "$ALLOWLIST" | head -5)
  if [ -n "$suspicious" ]; then
    echo "  [HIGH] $rcfile (modified: $mod) - suspicious patterns:"
    echo "$suspicious" | sed 's/^/      /'
  else
    echo "  $rcfile (modified: $mod) - clean"
  fi
done

exit 0
