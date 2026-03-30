#!/bin/bash
set -e

# sweep_persistence.sh — Enumerate all persistence mechanisms with code signature verification

echo "=== User LaunchAgents (Signature Verification) ==="
for plist in /Users/"$USER"/Library/LaunchAgents/*.plist; do
  [ -f "$plist" ] || continue
  binary=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null) || binary=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null) || binary="UNKNOWN"
  if [ "$binary" != "UNKNOWN" ] && [ -f "$binary" ]; then
    sig=$(codesign -v "$binary" 2>&1 && echo "VALID" || echo "UNSIGNED/INVALID")
    authority=$(codesign -dv "$binary" 2>&1 | grep "Authority=" | head -1 || true)
    echo "  $(basename "$plist") -> $binary [$sig] $authority"
  else
    echo "  $(basename "$plist") -> $binary [BINARY NOT FOUND]"
  fi
done

echo "=== System LaunchAgents (Signature Verification) ==="
for plist in /Library/LaunchAgents/*.plist; do
  [ -f "$plist" ] || continue
  binary=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null) || binary=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null) || binary="UNKNOWN"
  if [ "$binary" != "UNKNOWN" ] && [ -f "$binary" ]; then
    sig=$(codesign -v "$binary" 2>&1 && echo "VALID" || echo "UNSIGNED/INVALID")
    authority=$(codesign -dv "$binary" 2>&1 | grep "Authority=" | head -1 || true)
    echo "  $(basename "$plist") -> $binary [$sig] $authority"
  else
    echo "  $(basename "$plist") -> $binary [BINARY NOT FOUND]"
  fi
done

echo "=== System LaunchDaemons (Signature Verification) ==="
for plist in /Library/LaunchDaemons/*.plist; do
  [ -f "$plist" ] || continue
  binary=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null) || binary=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null) || binary="UNKNOWN"
  if [ "$binary" != "UNKNOWN" ] && [ -f "$binary" ]; then
    sig=$(codesign -v "$binary" 2>&1 && echo "VALID" || echo "UNSIGNED/INVALID")
    authority=$(codesign -dv "$binary" 2>&1 | grep "Authority=" | head -1 || true)
    echo "  $(basename "$plist") -> $binary [$sig] $authority"
  else
    echo "  $(basename "$plist") -> $binary [BINARY NOT FOUND]"
  fi
done

echo "=== Authorization Plugins ==="
if [ -d /Library/Security/SecurityAgentPlugins ]; then
  for bundle in /Library/Security/SecurityAgentPlugins/*.bundle; do
    [ -d "$bundle" ] || continue
    sig=$(codesign -v "$bundle" 2>&1 && echo "VALID" || echo "UNSIGNED/INVALID")
    authority=$(codesign -dv "$bundle" 2>&1 | grep "Authority=" | head -1 || true)
    echo "  $(basename "$bundle") [$sig] $authority"
  done
else
  echo "  Directory not found (normal)"
fi

echo "=== Login Items ==="
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || echo "  Could not enumerate login items"

echo "=== Cron Jobs ==="
crontab -l 2>/dev/null || echo "  No user crontab"

echo "=== Periodic Scripts ==="
for period in daily weekly monthly; do
  echo "  /etc/periodic/$period/:"
  ls /etc/periodic/"$period"/ 2>/dev/null | while read -r f; do
    echo "    $f"
  done
done

echo "=== Shell Startup Files ==="
for rcfile in .bashrc .zshrc .bash_profile .zprofile .profile; do
  filepath="/Users/$USER/$rcfile"
  [ -f "$filepath" ] || continue
  mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$filepath" 2>/dev/null || echo "unknown")
  suspicious=$(grep -nE '(curl |wget |python.*-c |base64 |eval |nc |ncat |/dev/tcp)' "$filepath" 2>/dev/null | grep -vE '(brew shellenv|nvm\.sh|conda|pyenv|rbenv|sdkman|cargo env|rustup)' | head -5 || true)
  if [ -n "$suspicious" ]; then
    echo "  $rcfile (modified: $mod) — SUSPICIOUS PATTERNS:"
    echo "$suspicious" | sed 's/^/    /'
  else
    echo "  $rcfile (modified: $mod) — clean"
  fi
done
