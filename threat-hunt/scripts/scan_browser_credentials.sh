#!/bin/bash
set -e

# scan_browser_credentials.sh — Browser credential store analysis

echo "=== Chrome Credential Stores ==="
chrome_dir="/Users/$USER/Library/Application Support/Google/Chrome"
if [ -d "$chrome_dir" ]; then
  find "$chrome_dir" -name "Login Data" -maxdepth 3 2>/dev/null | while read -r db; do
    mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$db" 2>/dev/null || echo "unknown")
    echo "  $db (modified: $mod)"
    # Check if non-Chrome process has it open
    open_by=$(lsof "$db" 2>/dev/null | grep -v "Google Chrome" | grep -v "COMMAND" || true)
    if [ -n "$open_by" ]; then
      echo "    [HIGH] Accessed by non-Chrome process:"
      echo "$open_by" | sed 's/^/      /'
    fi
  done
else
  echo "  Chrome not installed"
fi

echo "=== Firefox Credential Stores ==="
ff_dir="/Users/$USER/Library/Application Support/Firefox/Profiles"
if [ -d "$ff_dir" ]; then
  find "$ff_dir" -name "logins.json" -maxdepth 2 2>/dev/null | while read -r db; do
    mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$db" 2>/dev/null || echo "unknown")
    echo "  $db (modified: $mod)"
  done
else
  echo "  Firefox not installed"
fi

echo "=== Safari Credential Stores ==="
safari_dir="/Users/$USER/Library/Safari"
if [ -d "$safari_dir" ]; then
  for f in "History.db" "Downloads.plist" "Bookmarks.plist"; do
    [ -f "$safari_dir/$f" ] || continue
    mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$safari_dir/$f" 2>/dev/null || echo "unknown")
    echo "  $f (modified: $mod)"
  done
fi

echo "=== Password Manager Detection ==="
pm_found=0
# Check for common password manager processes
for pm in "1Password" "Bitwarden" "KeePassXC" "LastPass" "Dashlane"; do
  if pgrep -x "$pm" >/dev/null 2>&1 || pgrep -f "$pm" >/dev/null 2>&1; then
    echo "  Detected: $pm (running)"
    pm_found=1
  fi
done
# Check for browser extensions
if [ -d "$chrome_dir" ]; then
  for pm_ext in "aeblfdkhhhdcdjpifhhbdiojplfjncoa" "nngceckbapebfimnlniiiahkandclblb" "oboonakemofpalcgghocfoadofidjkkk" "hdokiejnpimakedhajhdlcegeplioahd"; do
    if find "$chrome_dir" -path "*/$pm_ext/*" -maxdepth 5 2>/dev/null | grep -q .; then
      echo "  Detected: password manager extension in Chrome"
      pm_found=1
      break
    fi
  done
fi
if [ "$pm_found" -eq 0 ]; then
  echo "  [MEDIUM] No password manager detected — consider using 1Password, Bitwarden, or KeePassXC"
fi
