#!/bin/bash
# scan_browser_credentials.sh — Browser credential store analysis
# Probe script: try each check, print what works, never abort on a failed sub-check.

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
  local label="$1" dir="$2" dbname="$3" owner="$4" depth="$5" found=0 db
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

AS="$HOME/Library/Application Support"
scan_browser "Chrome"  "$AS/Google/Chrome"                    "Login Data"  "google|chrome" 3
scan_browser "Brave"   "$AS/BraveSoftware/Brave-Browser"      "Login Data"  "brave"         3
scan_browser "Helium"  "$AS/net.imput.helium"                 "Login Data"  "helium"        3
scan_browser "Arc"     "$AS/Arc"                              "Login Data"  "arc"           4
scan_browser "Edge"    "$AS/Microsoft Edge"                   "Login Data"  "edge"          3
scan_browser "Firefox" "$AS/Firefox/Profiles"                 "logins.json" "firefox"       2

echo "=== Safari Data Files ==="
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
recent=$(find "$AS" -maxdepth 5 \( -name "Login Data" -o -name "logins.json" -o -name "key4.db" \) -mtime -1 2>/dev/null)
if [ -n "$recent" ]; then
  echo "$recent" | sed 's/^/  /'
else
  echo "  None"
fi

echo "=== Password Manager Detection ==="
# Installed app bundles and registered Safari extensions count, not only running processes:
# a manager that is installed but closed is still the user's manager.
pm_found=0
for pm in "1Password" "1Password 7" "Bitwarden" "KeePassXC" "LastPass" "Dashlane" "Proton Pass" "Strongbox" "Enpass"; do
  if [ -d "/Applications/$pm.app" ]; then
    if pgrep -f "$pm" >/dev/null 2>&1; then
      echo "  Detected: $pm.app (running)"
    else
      echo "  Detected: $pm.app (installed, not running)"
    fi
    pm_found=1
  fi
done
safari_pm=$(pluginkit -m 2>/dev/null | grep -iE 'bitwarden|1password|agilebits|keepass|lastpass|dashlane|proton\.pass|strongbox' | head -3)
if [ -n "$safari_pm" ]; then
  echo "  Detected: Safari extension(s):"
  echo "$safari_pm" | sed 's/^[[:space:]]*/    /'
  pm_found=1
fi
# Web Store ids: 1Password, Bitwarden, LastPass, Dashlane, Proton Pass, KeePassXC-Browser.
PM_EXT_IDS="aeblfdkhhhdcdjpifhhbdiojplfjncoa nngceckbapebfimnlniiiahkandclblb hdokiejnpimakedhajhdlcegeplioahd fdjamakpfbbddfjaooikfcpapjohcfmg ghmbeldphafepmbegfdlkpapadhbakde oboonakemofpalcgghocfoadofidjkkk"
for dir in "$AS/Google/Chrome" "$AS/BraveSoftware/Brave-Browser" "$AS/net.imput.helium" "$AS/Arc/User Data" "$AS/Microsoft Edge"; do
  [ -d "$dir" ] || continue
  for pm_ext in $PM_EXT_IDS; do
    if find "$dir" -maxdepth 5 -path "*/Extensions/$pm_ext/*" 2>/dev/null | grep -q .; then
      echo "  Detected: password manager extension in $(basename "$dir")"
      pm_found=1
      break
    fi
  done
done
if [ "$pm_found" -eq 0 ]; then
  echo "  [MEDIUM] No password manager detected (Apple Passwords / iCloud Keychain counts but is not detectable here) — if none, consider 1Password, Bitwarden, or KeePassXC"
fi

exit 0
