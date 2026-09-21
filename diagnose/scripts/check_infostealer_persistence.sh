#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Infostealer Detection: Persistence Mechanism Audit ==="

# A plist listing alone says nothing. What matters is whether the target it launches is
# validly signed, and by whom. For `/bin/bash script.sh` agents the target is the script:
# verifying the interpreter's Apple signature says nothing about the payload.
INTERPRETERS='(^|/)(python[0-9.]*|ruby|node|perl|bash|zsh|sh|fish|dash|osascript)$'

# Prints "<argv0>|<target>|<note>". Empty argv0 = nothing readable in the plist.
resolve_plist_target() {
  local plist="$1" argv0 arg i target note=""
  argv0=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null) \
    || argv0=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null) \
    || { echo "||no Program or ProgramArguments readable"; return 0; }
  target="$argv0"
  if echo "$argv0" | grep -qE "$INTERPRETERS"; then
    target=""
    for i in 1 2 3 4 5; do
      arg=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:$i" "$plist" 2>/dev/null) || break
      case "$arg" in
        -c|-e) note="inline command: $(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:$((i + 1))" "$plist" 2>/dev/null | head -c 60)"; break ;;
        -m)    note="python module: $(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:$((i + 1))" "$plist" 2>/dev/null)"; break ;;
        -*) continue ;;
        *)  target="$arg"; break ;;
      esac
    done
    [ -z "$target" ] && [ -z "$note" ] && note="interpreter with no script argument"
  fi
  echo "$argv0|$target|$note"
  return 0
}

verify_plists() {
  local label="$1" dir="$2" found=0 argv0 binary note
  echo "=== $label ==="
  for plist in "$dir"/*.plist; do
    [ -f "$plist" ] || continue
    found=1
    IFS='|' read -r argv0 binary note <<< "$(resolve_plist_target "$plist")"
    if [ -z "$argv0" ]; then
      echo "  [MEDIUM] $(basename "$plist") — $note"
      continue
    fi
    if [ -n "$note" ]; then
      case "$note" in
        "python module"*) echo "  $(basename "$plist") -> $argv0 — $note" ;;
        *)                echo "  [MEDIUM] $(basename "$plist") -> $argv0 — $note" ;;
      esac
      continue
    fi
    if [ -f "$binary" ]; then
      # Shell and script interpreters are never code-signed, so running codesign on them
      # would flag every legitimate helper script. For those the real risk is whether a
      # non-root user can rewrite the file that a LaunchAgent executes.
      kind=$(file -b "$binary" 2>&1)
      if echo "$kind" | grep -q "cannot open"; then
        # Root-only helpers (mode 711) cannot be read, so they cannot be classified as
        # script or Mach-O. Say so rather than falling into the script branch.
        status="unreadable (root-only, mode $(stat -f "%OLp" "$binary" 2>/dev/null)) - cannot verify signature"
      elif echo "$kind" | grep -q "Mach-O"; then
        if codesign -v "$binary" >/dev/null 2>&1; then
          # Authority only appears at --verbose=2; plain -dv omits it.
          authority=$(codesign -dv --verbose=2 "$binary" 2>&1 | sed -n 's/^Authority=//p' | head -1)
          status="VALID - ${authority:-no authority (ad-hoc signature)}"
        else
          status="[HIGH] UNSIGNED/INVALID Mach-O"
        fi
      else
        kind=$(echo "$kind" | cut -c1-40)
        # Owner-writable is normal for a user's own automation. The real risk is a target a
        # *different* account can rewrite, so score on the group/other write bits, not on -w.
        # %OLp is not zero-padded (mode 020 prints "20"), so pad before slicing the digits.
        perm=$(printf '%03d' "$(stat -f "%OLp" "$binary" 2>/dev/null || echo 0)")
        gw=$(printf "%s" "$perm" | cut -c2)
        ow=$(printf "%s" "$perm" | cut -c3)
        case "$gw$ow" in
          *[2367]*) status="[HIGH] group/world-writable target, mode $perm ($kind)" ;;
          *)        status="script, owner-writable only, mode $perm ($kind)" ;;
        esac
      fi
      [ "$binary" != "$argv0" ] && binary="$argv0 $binary"
      echo "  $(basename "$plist") -> $binary — $status"
    else
      echo "  [LOW] $(basename "$plist") -> $binary [TARGET NOT FOUND - orphaned agent]"
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
