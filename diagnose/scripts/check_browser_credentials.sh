#!/bin/bash
# Probe script: try each check, print what works, never abort on a failed sub-check.

echo "=== Infostealer Detection: Browser Credential Store Audit ==="

# The question is not "does this file exist" (it always does) but "when was it last
# touched, and is anything other than the browser itself holding it open".
report_db() {
  local db="$1" owner_pattern="$2" mod open_by
  mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$db" 2>/dev/null || echo unknown)
  echo "  $(basename "$(dirname "$db")")/$(basename "$db") (modified: $mod)"
  # Match the owner against the COMMAND column only. Every lsof line ends with the file
  # path, which contains the browser's name, so a whole-line grep -v could never fire.
  open_by=$(lsof +c 0 "$db" 2>/dev/null | awk -v p="$owner_pattern" 'NR > 1 && tolower($1) !~ p')
  if [ -n "$open_by" ]; then
    echo "    [HIGH] Held open by a process that is not the owning browser:"
    echo "$open_by" | sed 's/^/      /'
  fi
  return 0
}

scan_browser() {
  local label="$1" dir="$2" dbname="$3" owner="$4" depth="$5" found=0
  echo "=== $label ==="
  if [ ! -d "$dir" ]; then
    echo "  $label not installed"
    return 0
  fi
  while IFS= read -r db; do
    found=1
    report_db "$db" "$owner"
  done < <(find "$dir" -maxdepth "$depth" -name "$dbname" 2>/dev/null)
  [ "$found" -eq 0 ] && echo "  No credential store found"
  return 0
}

scan_browser "Chrome"  "$HOME/Library/Application Support/Google/Chrome" "Login Data" "google|chrome" 3
scan_browser "Brave"   "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" "Login Data" "brave" 3
# Helium (net.imput.helium) is the primary browser on this machine; it was missing here.
scan_browser "Helium"  "$HOME/Library/Application Support/net.imput.helium" "Login Data" "helium" 3
scan_browser "Arc"     "$HOME/Library/Application Support/Arc" "Login Data" "arc" 4
scan_browser "Firefox" "$HOME/Library/Application Support/Firefox/Profiles" "logins.json" "firefox" 2

echo "=== Safari ==="
safari_dir="$HOME/Library/Safari"
if [ -d "$safari_dir" ]; then
  for f in History.db Downloads.plist Bookmarks.plist; do
    [ -f "$safari_dir/$f" ] || continue
    echo "  $f (modified: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$safari_dir/$f" 2>/dev/null || echo unknown))"
  done
else
  echo "  Safari data not found"
fi

echo "=== Credential Stores Modified in Last 24h ==="
recent=$(find "$HOME/Library/Application Support" -maxdepth 5 \
  \( -name "Login Data" -o -name "logins.json" -o -name "key4.db" \) -mtime -1 2>/dev/null)
if [ -n "$recent" ]; then
  echo "$recent" | sed 's/^/  /'
else
  echo "  None"
fi

exit 0
